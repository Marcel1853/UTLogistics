-- Init-Code der Tipps-&-Tricks-Szenen (laufen als Konsolenbefehl in der Simulation, mit UTL
-- aktiv). Als Texte, damit der Selbsttest sie genauso ausführen kann (tools/selftest).
-- Aufbau: waagerechtes Gleis, Depot in der Mitte, Anbieter rechts (Kiste → Greifarm → Wagen),
-- Abnehmer links (Wagen → Greifarm → Kiste, die alles vernichtet). Zug: Lok – Wagen – Lok.

local COMMON = [[
local s = game.surfaces[1]
local force = game.forces.player
local W = defines.wire_connector_id
force.bulk_inserter_capacity_bonus = 11 -- zügiges Be-/Entladen, damit die Szene kurz bleibt
if game.simulation then
  game.simulation.camera_position = { 0, 1 }
  game.simulation.camera_zoom = 0.75
end
-- AREA und LINES können vor COMMON gesetzt werden (mehrere Gleislinien, größerer Ausschnitt)
AREA = AREA or { { -42, -14 }, { 42, 16 } }
LINES = LINES or { 1 }
for _, e in pairs(s.find_entities_filtered({ area = AREA })) do
  if e.type ~= "character" then e.destroy() end
end
s.build_checkerboard(AREA)
for _, line in ipairs(LINES) do
  for x = -37, 37, 2 do s.create_entity({ name = "straight-rail", position = { x, line }, direction = 4, force = force }) end
end

local function stop(name, x, east, vanilla, line)
  line = line or 1
  local e = s.create_entity({ name = vanilla and "train-stop" or "utl-train-stop", position = { x, line + (east and 2 or -2) },
    direction = east and 4 or 12, force = force, raise_built = true })
  e.backer_name = name
  return e
end

-- Combinator zu einer normalen Haltestelle: Ausgang per Kabel an die Haltestelle
local function combinator(st, dx)
  local c = s.create_entity({ name = "utl-station-combinator", position = { st.position.x + dx, st.position.y }, direction = 4,
    force = force, raise_built = true })
  c.get_wire_connector(W.combinator_output_green, true).connect_to(st.get_wire_connector(W.circuit_green, true))
  return c
end

-- Greifarme an der Wagenposition; `load` = Kiste → Wagen, sonst Wagen → Kiste (vernichtet alles,
-- mit `store` eine Stahlkiste, die sich füllt). `item` ist ein Name oder eine Liste von Namen.
-- Kisten per Kabel an `target` (Haltestelle oder Combinator-Eingang).
local function equip(xs, y, load, item, target, store, line)
  line = line or 1
  local chest_y = y + (y > line and 1 or -1)
  local first
  for n, x in ipairs(xs) do
    s.create_entity({ name = "bulk-inserter", position = { x, y }, direction = load == (y > line) and 8 or 0, force = force })
    local chest = s.create_entity({ name = store and "steel-chest" or "infinity-chest", position = { x, chest_y }, force = force })
    if load then
      -- mehrere Waren: je Kiste eine (aus einer gemischten Kiste nähme ein Greifarm nur eine Sorte)
      local names = type(item) == "table" and item or { item }
      chest.infinity_container_filters = { { index = 1, name = names[(n - 1) % #names + 1], count = 1000, mode = "at-least" } }
    elseif not store then
      chest.remove_unfiltered_items = true
    end
    if first then
      first.get_wire_connector(W.circuit_green, true).connect_to(chest.get_wire_connector(W.circuit_green, true))
    else
      first = chest
    end
  end
  if target then
    -- Kabelreichweite ist begrenzt: ein Mast in der Mitte leitet das Signal weiter
    local tp = target.owner.position
    local relay = s.create_entity({ name = "medium-electric-pole",
      position = { math.floor((first.position.x + tp.x) / 2) + 0.5, chest_y + (y > line and 1 or -1) }, force = force })
    first.get_wire_connector(W.circuit_green, true).connect_to(relay.get_wire_connector(W.circuit_green, true))
    relay.get_wire_connector(W.circuit_green, true).connect_to(target)
  end
  local pole_y = chest_y + (y > line and 1 or -1)
  s.create_entity({ name = "medium-electric-pole", position = { xs[1] - 1, pole_y }, force = force })
  local eei = s.create_entity({ name = "electric-energy-interface", position = { xs[1] - 1, pole_y + (y > line and 2 or -2) },
    force = force })
  eei.power_production = 100000
  eei.electric_buffer_size = 1000000
end

-- Testspieler mit Kamera; `steps` = { { Sekunden, Funktion }, … } läuft als Schleife (story-Bibliothek
-- aus dem Spiel, wie in den Vanilla-Tipps); mit `once` nur einmal.
local function show(steps, once)
  if not game.simulation then return end
  require("__core__/lualib/story")
  player = game.simulation.create_test_player({ name = "UTL" })
  player.teleport({ 0, 6 })
  game.simulation.camera_player = player
  game.simulation.camera_position = { 0, 1 }
  game.simulation.camera_alt_info = true
  game.simulation.camera_player_cursor_position = player.position
  if not steps then return end
  local story = { { name = "start", condition = story_elapsed_check(1) } }
  for _, step in ipairs(steps) do
    story[#story + 1] = { condition = step[3] or story_elapsed_check(step[1]), action = step[2] }
  end
  if not once then
    story[#story + 1] = { condition = story_elapsed_check(1), action = function() story_jump_to(storage.story, "start") end }
  end
  tip_story_init({ story })
end

local function close() remote.call("utl", "close_windows", player.index) end

local function train(x, coal, coal_back, line)
  line = line or 1
  -- jedes Teil 7 Felder hinter der tatsächlichen Position des vorherigen (Factorio rückt Wagen
  -- auf waagerechten Gleisen beim Setzen zurecht) – dann koppeln sie von selbst
  local l1 = s.create_entity({ name = "locomotive", position = { x, line }, direction = 4, force = force })
  local wagon = s.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, line }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { wagon.position.x - 7, line }, direction = 12, force = force })
  l1.insert({ name = "coal", count = coal })
  l2.insert({ name = "coal", count = coal_back or coal })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = DEPOT_NAME or "Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  return l1.train
end
]]

local SIMPLE = [[
local depot = stop("Depot", -3, true, VANILLA)
local provider = stop("Anbieter", 29, true, VANILLA)
local requester = stop("Abnehmer", -29, false, VANILLA)
d_unit, p_unit, r_unit = depot.unit_number, provider.unit_number, requester.unit_number
local p_target = provider.get_wire_connector(W.circuit_green, true)
local r_target = requester.get_wire_connector(W.circuit_green, true)
if VANILLA then
  local dc, pc, rc = combinator(depot, -3), combinator(provider, -3), combinator(requester, 3)
  d_unit, p_unit, r_unit = dc.unit_number, pc.unit_number, rc.unit_number
  p_target = pc.get_wire_connector(W.combinator_input_green, true)
  r_target = rc.get_wire_connector(W.combinator_input_green, true)
end
equip({ 18.5, 20.5 }, 2.5, true, "iron-plate", p_target)
equip({ -18.5, -20.5 }, -0.5, false, nil, r_target)
remote.call("utl", "configure_station", d_unit, { mode = "depot" })
remote.call("utl", "configure_station", p_unit, { mode = "station", provide = true, request = false, provide_threshold = 100 })
remote.call("utl", "configure_station", r_unit, { mode = "station", provide = false, request = true, request_threshold = 100 })
remote.call("utl", "set_request", r_unit, 1, { type = "item", name = "iron-plate" }, 200)
]]

local FUEL = [[
local fuel = stop("Tankstelle", 13, true, false)
remote.call("utl", "configure_station", fuel.unit_number, { mode = "fuel" })
s.create_entity({ name = "bulk-inserter", position = { 10.5, 2.5 }, direction = 8, force = force })
local coal = s.create_entity({ name = "infinity-chest", position = { 10.5, 3.5 }, force = force })
coal.infinity_container_filters = { { index = 1, name = "coal", count = 50, mode = "at-least" } }
s.create_entity({ name = "medium-electric-pole", position = { 9.5, 4.5 }, force = force })
local eei = s.create_entity({ name = "electric-energy-interface", position = { 9.5, 6.5 }, force = force })
eei.power_production = 100000
eei.electric_buffer_size = 1000000
-- hintere Lok: steht an der Tankstelle bei x ≈ -4; der Greifarm bei -1,5 erreicht sie nur dort
-- (am Start und im Depot steht keine Lok daneben)
s.create_entity({ name = "bulk-inserter", position = { -1.5, 2.5 }, direction = 8, force = force })
local coal_back = s.create_entity({ name = "infinity-chest", position = { -1.5, 3.5 }, force = force })
coal_back.infinity_container_filters = { { index = 1, name = "coal", count = 50, mode = "at-least" } }
s.create_entity({ name = "medium-electric-pole", position = { -0.5, 4.5 }, force = force })
local eei_back = s.create_entity({ name = "electric-energy-interface", position = { 1, 6 }, force = force })
eei_back.power_production = 100000
eei_back.electric_buffer_size = 1000000
]]

local CLEANUP = [[
local cleanup = stop("Cleanup", 13, true, false)
c_unit = cleanup.unit_number
remote.call("utl", "configure_station", c_unit, { mode = "cleanup" })
equip({ 3.5 }, 2.5, false, nil, nil)
]]

-- Alle Rollen nebeneinander (Namen per Alt-Ansicht sichtbar); Cleanup steht nur zum Zeigen da.
local ROLES = [[
local cleanup = stop("Cleanup", 5, false, false)
remote.call("utl", "configure_station", cleanup.unit_number, { mode = "cleanup" })
]]

-- Zwei Waren, Abnehmer mit Stahlkisten: Zielbestand 400 je Ware, danach fährt kein Zug mehr.
local REQUESTS = [[
local depot = stop("Depot", -3, true, false)
local provider = stop("Anbieter", 29, true, false)
local requester = stop("Abnehmer", -29, false, false)
r_unit = requester.unit_number
equip({ 18.5, 20.5 }, 2.5, true, { "iron-plate", "copper-plate" }, provider.get_wire_connector(W.circuit_green, true))
equip({ -18.5, -20.5 }, -0.5, false, nil, requester.get_wire_connector(W.circuit_green, true), true)
remote.call("utl", "configure_station", depot.unit_number, { mode = "depot" })
remote.call("utl", "configure_station", provider.unit_number, { mode = "station", provide = true, request = false, provide_threshold = 100 })
remote.call("utl", "configure_station", r_unit, { mode = "station", provide = false, request = true, request_threshold = 100 })
remote.call("utl", "set_request", r_unit, 1, { type = "item", name = "iron-plate" }, 400)
remote.call("utl", "set_request", r_unit, 2, { type = "item", name = "copper-plate" }, 400)
]]

-- Normale Haltestelle „Depot“ ohne Rolle: der Zug zieht von selbst ins echte Depot um.
local DEPOTS = [[
stop("Depot", -15, true, true)
]]

-- Zweiter Abnehmer ohne Einstellungen; Umschalt + Rechtsklick / Linksklick überträgt sie.
local COPY = [[
local second = stop("Abnehmer 2", -9, false, false)
second_unit = second.unit_number
equip({ 0.5, 2.5 }, -0.5, false, nil, second.get_wire_connector(W.circuit_green, true))
]]

-- `parts.pre` läuft VOR dem gemeinsamen Teil (dort lassen sich AREA und LINES setzen).
local function scene(parts)
  return "local VANILLA = " .. tostring(parts.vanilla or false) .. "\n" .. (parts.pre or "")
    .. COMMON .. table.concat(parts, "\n")
end

-- Fenster zeigen: 2 s warten, öffnen, 10 s offen lassen, schließen
local function window(open)
  return "show({ { 2, function() " .. open .. " end }, { 10, close } })\n"
end

-- Netzwerk-Szene: Rundkurs aus Marcels Blaupause (Gleise, Signale, sechs Bahnhöfe auf
-- Ausbuchtungen, zwei davon normale Haltestelle + UTL-Combinator, Kabel schon gesetzt).
-- Diese Szene stellt die Stationen ein, baut Kisten und Greifarme und setzt die Züge.
-- Zwei Netzwerke auf denselben Gleisen: „Erze“ und „Platten“.
local RING_BP = "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"

local NETWORKS_PRE = "AREA = { { -140, -100 }, { 140, 100 } }\nLINES = {}\nRING_BP = \"" .. RING_BP .. "\"\n"


local NETWORKS = [[
-- Blaupause setzen: surface.create_entities_from_blueprint_string gibt es nur in Simulationen,
-- deshalb über einen Blaupausen-Gegenstand bauen und die Geister sofort beleben (klappt überall,
-- also auch im Headless-Test).
local inv = game.create_inventory(1)
inv[1].set_stack({ name = "blueprint" })
inv[1].import_stack(RING_BP)
local ghosts = inv[1].build_blueprint({ surface = s, force = force, position = { 0, 0 },
  skip_fog_of_war = true, raise_built = true })
for _, ghost in pairs(ghosts or {}) do
  if ghost.valid then ghost.revive({ raise_revive = true }) end
end
inv.destroy()

-- Bahnhöfe der Blaupause einsammeln und nach Fahrtrichtung einordnen
-- (oben Osten = Anbieter, unten Westen = Abnehmer, links Norden und rechts Süden = Depots)
local found = { [4] = {}, [12] = {}, [0] = {}, [8] = {} }
for _, st in pairs(s.find_entities_filtered({ type = "train-stop" })) do
  table.insert(found[st.direction], st)
end
table.sort(found[4], function(x, y) return x.position.x < y.position.x end)
table.sort(found[12], function(x, y) return x.position.x < y.position.x end)

-- Combinator einer normalen Haltestelle (Kabel steckt schon in der Blaupause)
local function station_unit(stop)
  if stop.name ~= "train-stop" then return stop.unit_number end
  local c = s.find_entities_filtered({ name = "utl-station-combinator", position = stop.position, radius = 5 })[1]
  return c and c.unit_number
end
local function station_target(stop)
  if stop.name ~= "train-stop" then return stop.get_wire_connector(W.circuit_green, true) end
  local c = s.find_entities_filtered({ name = "utl-station-combinator", position = stop.position, radius = 5 })[1]
  return c and c.get_wire_connector(W.combinator_input_green, true)
end

local function setup(stop, name, network, mode)
  stop.backer_name = (stop.name == "train-stop" and "[item=utl-station-combinator] " or "") .. name
  local unit = station_unit(stop)
  remote.call("utl", "configure_station", unit, mode)
  remote.call("utl", "configure_station", unit, { network = network })
  return unit
end

-- Netz „Erze“ bekommt die Combinator-Bauart, „Platten“ die UTL-Haltestellen
local nets = {}
for _, st in pairs(found[4]) do
  nets[st.name == "train-stop" and "Erze" or "Platten"] = { provider = st }
end
for _, st in pairs(found[12]) do
  nets[st.name == "train-stop" and "Erze" or "Platten"].requester = st
end
nets.Erze.depot, nets.Platten.depot = found[0][1], found[8][1]
nets.Erze.item, nets.Platten.item = "iron-ore", "copper-plate"

for name, net in pairs(nets) do
  setup(net.depot, "Depot " .. name, name, { mode = "depot" })
  local p_unit = setup(net.provider, "Anbieter " .. name, name,
    { mode = "station", provide = true, request = false, provide_threshold = 100 })
  local r_unit = setup(net.requester, "Abnehmer " .. name, name,
    { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", r_unit, 1, { type = "item", name = net.item }, 200)
  if name == "Erze" then ERZ_STOP = p_unit end

  -- Anbieter: Fahrtrichtung Osten → Gleis 2 Felder über der Haltestelle, Kisten darunter
  local pl = net.provider.position.y - 2
  equip({ net.provider.position.x - 10 }, pl + 1.5, true, net.item, station_target(net.provider), false, pl)
  -- Abnehmer: Fahrtrichtung Westen → Gleis 2 Felder unter der Haltestelle, Kisten darüber.
  -- Stahlkiste mit langsamem Abfluss, damit der Bedarf nach und nach entsteht und der Zug
  -- zwischendurch sichtbar ins Depot zurückfährt.
  local rl = net.requester.position.y + 2
  local rx = net.requester.position.x + 10
  equip({ rx }, rl - 1.5, false, nil, station_target(net.requester), true, rl)
  s.create_entity({ name = "inserter", position = { rx, rl - 3.5 }, direction = 8, force = force })
  local void = s.create_entity({ name = "infinity-chest", position = { rx, rl - 4.5 }, force = force })
  void.remove_unfiltered_items = true

  -- Zug (Lok + Wagen) im Depot: links fährt er nach Norden, rechts nach Süden
  local north = net.depot.direction == 0
  local rail_x = net.depot.position.x + (north and -2 or 2)
  local head_y = net.depot.position.y + (north and 3 or -3)
  local loco = s.create_entity({ name = "locomotive", position = { rail_x, head_y },
    direction = north and 0 or 8, force = force })
  s.create_entity({ name = "cargo-wagon", position = { rail_x, head_y + (north and 7 or -7) },
    direction = north and 0 or 8, force = force })
  loco.insert({ name = "coal", count = 150 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = "Depot " .. name, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
end

-- Kamera: ganzer Rundkurs, dann die Ausbuchtungen mit geöffnetem Stationsfenster
local minx, maxx, miny, maxy
for _, rail in pairs(s.find_entities_filtered({ type = { "straight-rail", "curved-rail-a", "curved-rail-b" } })) do
  local q = rail.position
  minx = math.min(minx or q.x, q.x); maxx = math.max(maxx or q.x, q.x)
  miny = math.min(miny or q.y, q.y); maxy = math.max(maxy or q.y, q.y)
end
local cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
local function view(x, y, zoom)
  return function()
    if not game.simulation then return end
    game.simulation.camera_position = { x, y }
    game.simulation.camera_zoom = zoom
  end
end
local overview = view(cx, cy, 0.17)
overview()
local perz = nets.Erze.provider.position
show({
  { 1, overview },
  { 8, view(perz.x - 6, perz.y + 4, 0.55) },
  { 2, function() remote.call("utl", "open_station", player.index, ERZ_STOP, nil, true) end },
  { 8, function() remote.call("utl", "close_windows", player.index) end },
  { 8, view(nets.Erze.depot.position.x + 6, nets.Erze.depot.position.y, 0.5) },
  { 8, overview },
})
]]


return {
  -- UTL-Haltestellen, echter Lieferbetrieb (und direkt der nächste Auftrag)
  basic = scene({ SIMPLE, "train(-8, 150)", "show()" }),
  -- dazu das UTL-Panel am Abnehmer (Anforderung, Live-Waren, Unterwegs)
  stop_window = scene({ SIMPLE, "train(-8, 150)", window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- normale Haltestellen mit UTL-Stations-Combinator (Ausgang → Haltestelle, Kisten → Eingang)
  combinator = scene({ vanilla = true, SIMPLE, "train(-8, 150)",
    window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- alle Rollen: Depot, Anbieter, Abnehmer, Tankstelle, Cleanup
  roles = scene({ SIMPLE, FUEL, ROLES, "train(-8, 8)", "show()" }),
  -- Zielbestand und zwei Waren in einem Zug
  requests = scene({ REQUESTS, "train(-8, 150)", window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- Reiter „Werte“ am Anbieter
  values = scene({ SIMPLE, "train(-8, 150)", window('remote.call("utl", "open_station", player.index, p_unit, 2, true)') }),
  -- Zug an einer gleichnamigen Haltestelle ohne Depot-Rolle
  depots = scene({ SIMPLE, DEPOTS, "train(-18, 150)", "show()" }),
  -- Zug mit wenig Treibstoff fährt zuerst zur Tankstelle (beide Loks werden betankt)
  fuel = scene({ SIMPLE, FUEL, "train(-8, 8)", "show()" }),
  -- Zug mit Restladung wird zuerst an der Cleanup-Station geleert
  cleanup = scene({ SIMPLE, CLEANUP, "train(-8, 150).cargo_wagons[1].insert({ name = 'copper-plate', count = 100 })",
    window('remote.call("utl", "open_station", player.index, c_unit, 2, true)') }),
  -- Einstellungen vom Abnehmer auf „Abnehmer 2“ kopieren (einmal, ohne Zug), danach dessen Fenster
  copy = scene({ SIMPLE, COPY, [[
show({
  { 0, nil, function() return game.simulation.move_cursor({ position = { -29, -1 } }) end },
  { 1, function() game.simulation.control_down({ control = "copy-entity-settings", notify = true }) end },
  { 0.5, function() game.simulation.control_up({ control = "copy-entity-settings" }) end },
  { 0, nil, function() return game.simulation.move_cursor({ position = { -9, -1 } }) end },
  { 0.5, function() game.simulation.control_down({ control = "paste-entity-settings", notify = true }) end },
  { 0.5, function() game.simulation.control_up({ control = "paste-entity-settings" }) end },
  { 0, nil, function() return game.simulation.move_cursor({ position = player.position }) end },
  { 1, function() remote.call("utl", "open_station", player.index, second_unit, nil, true) end },
}, true)
]] }),
  -- Zwei getrennte Netze nebeneinander, mit Kamerafahrt
  networks = scene({ pre = NETWORKS_PRE, NETWORKS }),
  -- Manager: Reiter nacheinander
  manager = scene({ SIMPLE, "train(-8, 150)", [[
show({
  { 3, function() remote.call("utl", "open_manager", player.index, "depots") end },
  { 5, function() remote.call("utl", "open_manager", player.index, "stations") end },
  { 5, function() remote.call("utl", "open_manager", player.index, "inventory") end },
  { 5, function() remote.call("utl", "open_manager", player.index, "history") end },
  { 5, close },
})
]] }),
}
