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
for _, e in pairs(s.find_entities_filtered({ area = { { -42, -14 }, { 42, 16 } } })) do
  if e.type ~= "character" then e.destroy() end
end
s.build_checkerboard({ { -42, -14 }, { 42, 16 } })
for x = -37, 37, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end

local function stop(name, x, east, vanilla)
  local e = s.create_entity({ name = vanilla and "train-stop" or "utl-train-stop", position = { x, east and 3 or -1 },
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
local function equip(xs, y, load, item, target, store)
  local chest_y = y + (y > 1 and 1 or -1)
  local first
  for n, x in ipairs(xs) do
    s.create_entity({ name = "bulk-inserter", position = { x, y }, direction = load == (y > 1) and 8 or 0, force = force })
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
      position = { math.floor((first.position.x + tp.x) / 2) + 0.5, chest_y + (y > 1 and 1 or -1) }, force = force })
    first.get_wire_connector(W.circuit_green, true).connect_to(relay.get_wire_connector(W.circuit_green, true))
    relay.get_wire_connector(W.circuit_green, true).connect_to(target)
  end
  local pole_y = chest_y + (y > 1 and 1 or -1)
  s.create_entity({ name = "medium-electric-pole", position = { xs[1] - 1, pole_y }, force = force })
  local eei = s.create_entity({ name = "electric-energy-interface", position = { xs[1] - 1, pole_y + (y > 1 and 2 or -2) },
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

local function train(x, coal, coal_back)
  -- jedes Teil 7 Felder hinter der tatsächlichen Position des vorherigen (Factorio rückt Wagen
  -- auf waagerechten Gleisen beim Setzen zurecht) – dann koppeln sie von selbst
  local l1 = s.create_entity({ name = "locomotive", position = { x, 1 }, direction = 4, force = force })
  local wagon = s.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, 1 }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { wagon.position.x - 7, 1 }, direction = 12, force = force })
  l1.insert({ name = "coal", count = coal })
  l2.insert({ name = "coal", count = coal_back or coal })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
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

local function scene(parts) return "local VANILLA = " .. tostring(parts.vanilla or false) .. "\n" .. COMMON .. table.concat(parts, "\n") end

-- Fenster zeigen: 2 s warten, öffnen, 10 s offen lassen, schließen
local function window(open)
  return "show({ { 2, function() " .. open .. " end }, { 10, close } })\n"
end

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
