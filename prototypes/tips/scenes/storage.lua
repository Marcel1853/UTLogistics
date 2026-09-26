local P = require("__UTLogistics__/prototypes/tips/scenes/common")
local Layout = require("__UTLogistics__/prototypes/tips/scenes/ring-layout")

-- Lager-Szene auf dem Rundkurs, ein Netz, zwei Züge:
--   oben:  Abnehmer 2 ········ Anbieter (Eisen)
--   unten: Abnehmer 1 ·· Lager (Mindest 200, Höchst 600, Entlade- und Lade-Greifarme, kleine Fabrik)
-- Das Lager liegt näher an Abnehmer 1 und beliefert ihn; Abnehmer 2 bekommt vom näheren Anbieter.
-- Die Fabrik verbraucht Eisen aus dem Lager – fällt es unter Mindest, holt ein Zug Nachschub.
local STORAGE = [[
force.technologies["utl-loading-control"].researched = true
force.technologies["utl-storage"].researched = true
-- keine Inaktivitäts-Wartezeit: der Zug fährt, sobald er voll bzw. leer ist
remote.call("utl", "set_map_config", "utl-load-timeout", 0)
remote.call("utl", "set_map_config", "utl-unload-timeout", 0)
local IRON = { type = "item", name = "iron-plate" }

local top_utl, top_vanilla, bottom_utl, bottom_vanilla
for _, st in pairs(found[4]) do
  if st.name == "train-stop" then top_vanilla = st else top_utl = st end
end
for _, st in pairs(found[12]) do
  if st.name == "train-stop" then bottom_vanilla = st else bottom_utl = st end
end

local function setup(stop, name, cfg)
  stop.backer_name = (stop.name == "train-stop" and "[item=utl-station-combinator] " or "") .. name
  local unit = station_unit(stop)
  remote.call("utl", "configure_station", unit, cfg)
  return unit
end

-- Fahrtrichtung Osten: Gleis 2 Felder über der Haltestelle, Wagen etwa 10 Felder davor (westlich);
-- Fahrtrichtung Westen: Gleis 2 Felder darunter, Wagen etwa 10 Felder dahinter (östlich)
local function wagon_side(stop)
  local east = stop.direction == 4
  local rail = stop.position.y + (east and -2 or 2)
  return east, rail, stop.position.x + (east and -10 or 10), rail + (east and 1.5 or -1.5)
end

-- Verbraucher: je Kiste ein langsamer Greifarm in eine Kiste, die alles vernichtet (alle Kisten,
-- sonst bliebe in den übrigen ein Rest und der Bedarf entstünde nie). Den Stromblock aus equip
-- dafür ein Feld weiter weg.
local function drain(xs, chest_y, down)
  local d = down and 1 or -1
  local eei = s.find_entities_filtered({ name = "electric-energy-interface", position = { xs[1] - 1, chest_y + 3 * d }, radius = 0.6 })[1]
  if eei then eei.teleport({ xs[1] - 1, chest_y + 4 * d }) end
  for _, x in ipairs(xs) do
    s.create_entity({ name = "inserter", position = { x, chest_y + d }, direction = down and 0 or 8, force = force })
    local void = s.create_entity({ name = "infinity-chest", position = { x, chest_y + 2 * d }, force = force })
    void.remove_unfiltered_items = true
  end
end

for _, depot in pairs({ found[0][1], found[8][1] }) do setup(depot, "Depot", { mode = "depot" }) end

-- Anbieter: drei Greifarme laden Eisen
local _, rail, wx, iy = wagon_side(top_utl)
setup(top_utl, "Anbieter", { mode = "station", provide = true, request = false, provide_threshold = 100 })
equip({ wx - 1.5, wx - 0.5, wx + 0.5 }, iy, true, "iron-plate", station_target(top_utl), false, rail)

-- Abnehmer: Stahlkisten, aus denen die Fabrik nach und nach verbraucht
local function requester(stop, name)
  local east, line, x, y = wagon_side(stop)
  local unit = setup(stop, name, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", unit, 1, IRON, 200)
  local xs = { x - 0.5, x + 0.5 }
  equip(xs, y, false, nil, station_target(stop), true, line)
  drain(xs, y + (east and 1 or -1), east)
end
requester(bottom_vanilla, "Abnehmer 1")
requester(top_vanilla, "Abnehmer 2")

-- Lager: zweimal „Entlade-Greifarm → Kiste → Umlade-Greifarm → Kiste → Lade-Greifarm“ am Wagen.
-- Die Auftrags-Ausgabe schaltet: Lade-Greifarme bei utl-loading > 0, Entlade-Greifarme bei
-- utl-loading = 0 (auch Restladung ohne Auftrag wird so entladen). Die Umlade-Greifarme laufen immer.
local _, _, lx, ly = wagon_side(bottom_utl)
l_unit = setup(bottom_utl, "Lager", { mode = "storage",
  storage = { limits = { { signal = IRON, min = 200, max = 600 } } } })
local LOADING = { type = "virtual", name = "utl-loading" }
local unloaders, loaders, chests = {}, {}, {}
local function switched(x, direction, comparator, list)
  local e = s.create_entity({ name = "bulk-inserter", position = { x, ly }, direction = direction, force = force })
  local cb = e.get_or_create_control_behavior()
  cb.circuit_enable_disable = true
  cb.circuit_condition = { first_signal = LOADING, comparator = comparator, constant = 0 }
  list[#list + 1] = e
end
for _, x in ipairs({ lx - 2.5, lx + 0.5 }) do
  switched(x, 8, "=", unloaders)                                                        -- Wagen → Kiste
  s.create_entity({ name = "fast-inserter", position = { x + 1, ly - 1 }, direction = 12, force = force }) -- Kiste → Kiste
  switched(x + 2, 0, ">", loaders)                                                      -- Kiste → Wagen
  for _, cx in ipairs({ x, x + 2 }) do
    local chest = s.create_entity({ name = "steel-chest", position = { cx, ly - 1 }, force = force })
    if #chests > 0 then chest.get_wire_connector(W.circuit_green, true).connect_to(chests[#chests].get_wire_connector(W.circuit_green, true)) end
    chests[#chests + 1] = chest
  end
end
local lxs = { lx - 0.5, lx + 2.5 } -- die Lade-Kisten
local pole = s.create_entity({ name = "medium-electric-pole", position = { lx + 0.5, ly - 2 }, force = force })
-- 2 × 2 rastet auf ganze Felder ein: links neben die Kisten, noch in Reichweite des Masts
local eei = s.create_entity({ name = "electric-energy-interface", position = { lx - 3, ly - 2.5 }, force = force })
eei.power_production = 200000
eei.electric_buffer_size = 2000000
chests[1].get_wire_connector(W.circuit_green, true).connect_to(pole.get_wire_connector(W.circuit_green, true))
local relay_at = s.find_non_colliding_position("medium-electric-pole", { (lx + bottom_utl.position.x) / 2, ly - 2 }, 4, 0.5)
local relay = s.create_entity({ name = "medium-electric-pole", position = relay_at, force = force })
pole.get_wire_connector(W.circuit_green, true).connect_to(relay.get_wire_connector(W.circuit_green, true))
relay.get_wire_connector(W.circuit_green, true).connect_to(bottom_utl.get_wire_connector(W.circuit_green, true))
-- die „Fabrik“ am Lager: verbraucht stetig Eisen aus den Lade-Kisten, damit das Lager unter Mindest fällt
for _, x in ipairs(lxs) do
  s.create_entity({ name = "inserter", position = { x, ly - 2 }, direction = 8, force = force })
  local void = s.create_entity({ name = "infinity-chest", position = { x, ly - 3 }, force = force })
  void.remove_unfiltered_items = true
end

-- Zwei Züge (Lok + Wagen), je einer in einem Depot
for _, depot in pairs({ found[0][1], found[8][1] }) do
  local north = depot.direction == 0
  local rail_x = depot.position.x + (north and -2 or 2)
  local head_y = depot.position.y + (north and 3 or -3)
  local loco = s.create_entity({ name = "locomotive", position = { rail_x, head_y }, direction = north and 0 or 8, force = force })
  s.create_entity({ name = "cargo-wagon", position = { rail_x, head_y + (north and 7 or -7) }, direction = north and 0 or 8,
    force = force })
  loco.insert({ name = "coal", count = 150 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = "Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
end

-- Schilder neben dem Lager und Abnehmer 2
local function sign_near(stop, key, icon)
  local p = stop.position
  for d = 3, 12 do
    if sign(p.x, p.y + d, key, icon) or sign(p.x, p.y - d, key, icon) then return end
  end
end
sign_near(bottom_utl, "storage", IRON)
sign_near(top_vanilla, "storage-far", IRON)

-- Die Auftrags-Ausgabe legt UTL erst einen Moment nach dem Einstellen an: dann rot an die
-- geschalteten Greifarme (eigener Takt 37 – im Test läuft die Szene in einem Mod, der 30 schon belegt)
local R = defines.wire_connector_id.circuit_red
local wired = false
script.on_nth_tick(37, function()
  local output = s.find_entities_filtered({ name = "utl-station-output", position = bottom_utl.position, radius = 5 })[1]
  if not output then return end
  local previous = output.get_wire_connector(R, true)
  previous.connect_to(relay.get_wire_connector(R, true))
  previous = relay.get_wire_connector(R, true)
  previous.connect_to(pole.get_wire_connector(R, true))
  for _, list in ipairs({ unloaders, loaders }) do
    for _, e in ipairs(list) do pole.get_wire_connector(R, true).connect_to(e.get_wire_connector(R, true)) end
  end
  wired = true
  script.on_nth_tick(37, nil)
end)

if not game.simulation then
  -- nur für tools/tipstest: wer liefert wohin, und der Lagerbestand
  local seen = {}
  script.on_nth_tick(41, function(e)
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      local route = (d.from or "?") .. " -> " .. (d.to or "?")
      if not seen[route] then
        seen[route] = true
        log(("[TIPS] storage erstes %s nach %d s"):format(route, math.floor(e.tick / 60)))
      end
    end
    if e.tick % 3600 < 41 then
      local n = 0
      for _, chest in pairs(chests) do n = n + chest.get_item_count("iron-plate") end
      log(("[TIPS] storage erstes bestand %d s: %d, verdrahtet %s"):format(math.floor(e.tick / 60), n, tostring(wired)))
    end
  end)
end

-- Kamera: Überblick, dann das Lager mit geöffnetem Fenster, dann wieder der Überblick
local overview = view(cx, cy, 0.17)
overview()
show({
  { 1, overview },
  { 10, view(lx, ly - 2, 0.6) },
  { 12, function() remote.call("utl", "open_station", player.index, l_unit, 1, true) end },
  { 8, function() remote.call("utl", "close_windows", player.index) end },
  { 10, overview },
})
]]

return P.scene({ pre = Layout.PRE, Layout.BUILD, STORAGE })
