-- Gemeinsame Bausteine der Tipps-&-Tricks-Szenen (Init-Code als Text, läuft in der Simulation mit
-- UTL aktiv; tools/tipstest führt denselben Text in einer normalen Welt aus).
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

-- Anzeigefeld mit Erklärtext darüber. Ein Anzeigefeld kennt nur festen Text, und die Sprache des
-- Spielers steht beim Aufbau noch nicht fest – den Text zeichnet deshalb rendering.draw_text aus
-- der Sprachdatei (utl-sign.<key>), so erscheint er in jeder Sprache richtig.
local function sign(x, y, key, icon, param)
  if not s.can_place_entity({ name = "display-panel", position = { x, y }, force = force }) then return nil end
  local panel = s.create_entity({ name = "display-panel", position = { x, y }, force = force })
  if not panel then return nil end
  if icon then panel.display_panel_icon = icon end
  rendering.draw_text({ text = { "utl-sign." .. key, param }, surface = s, target = { x, y - 0.6 },
    color = { 1, 1, 1 }, scale = 1, scale_with_zoom = true, font = "default-bold", alignment = "center",
    vertical_alignment = "bottom", use_rich_text = true })
  return panel
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

-- Cleanup mit „Inhalt wieder anbieten“: seine Kiste hat Kupfer, der Abnehmer will Kupfer – das hat
-- sonst niemand, also holt der Zug es am Cleanup ab.
local CLEANUP_RETURN = [[
-- Die Auftrags-Ausgabe braucht „UTL: Ladesteuerung“; in der Tipps-Welt ist nichts erforscht.
force.technologies["utl-loading-control"].researched = true
local cleanup = stop("Cleanup", 13, true, false)
c_unit = cleanup.unit_number
remote.call("utl", "configure_station", c_unit, { mode = "cleanup", cleanup = { offer = "first" } })
equip({ 3.5 }, 2.5, true, "copper-plate", cleanup.get_wire_connector(W.circuit_green, true))
-- Gemischte Restladung: Eisen und Kupfer in derselben Kiste. Der Abnehmer will nur Kupfer.
local chest = s.find_entities_filtered({ name = "infinity-chest", position = { 3.5, 3.5 }, radius = 0.5 })[1]
chest.infinity_container_filters = {
  { index = 1, name = "iron-plate", count = 1000, mode = "at-least" },  -- über der Anbieter-Schwelle
  { index = 2, name = "copper-plate", count = 1000, mode = "at-least" },
}
remote.call("utl", "set_request", r_unit, 1, { type = "item", name = "copper-plate" }, 200)
-- Ein Wende-Greifarm statt des Bulk-Greifarms: er filtert per Schaltung („Filter setzen“ aus der
-- Auftrags-Ausgabe des Cleanups) und legt nach der Abfahrt zurück, was er noch in der Hand hat –
-- ein normaler Greifarm behielte es und blockierte beim nächsten Auftrag mit anderer Ware.
-- Die Ausgabe legt UTL einen Moment nach dem Einstellen an.
force.technologies["utl-storage"].researched = true
local old = s.find_entities_filtered({ name = "bulk-inserter", position = { 3.5, 2.5 }, radius = 0.5 })[1]
local inserter = s.create_entity({ name = "utl-reversible-inserter", position = { 3.5, 2.5 }, direction = old.direction,
  force = force, raise_built = true })
old.destroy()
local cb = inserter.get_or_create_control_behavior()
cb.circuit_set_filters = true
local wired = false
script.on_nth_tick(41, function()
  if not wired then
    local output = s.find_entities_filtered({ name = "utl-station-output", position = cleanup.position, radius = 5 })[1]
    if not output then return end
    output.get_wire_connector(defines.wire_connector_id.circuit_red, true)
      .connect_to(inserter.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    wired = true
    if game.simulation then script.on_nth_tick(41, nil) end
  elseif not game.simulation then
    -- nur für tools/tipstest: fährt der Zug vom Cleanup, darf nur Kupfer im Wagen sein
    for _, t in pairs(game.train_manager.get_trains({ surface = s })) do
      if t.state == defines.train_state.on_the_path and t.get_item_count() > 0 and not logged_cleanup then
        logged_cleanup = game.tick
        log("[TIPS] cleanup_return erstes abfahrt ladung " .. serpent.line(t.get_contents()))
      end
    end
    -- 5 s nach der Abfahrt: hat der Greifarm die Hand geleert?
    if logged_cleanup and not logged_hand and game.tick > logged_cleanup + 300 then
      logged_hand = true
      local held = inserter.held_stack
      log("[TIPS] cleanup_return erstes hand nach abfahrt " .. (held.valid_for_read and (held.name .. " x" .. held.count) or "leer"))
    end
  end
end)
]]

-- Wende-Greifarme am Abnehmer: statt der Entlade-Greifarme stehen dort Wende-Greifarme in
-- Laderichtung, verdrahtet mit der Auftrags-Ausgabe der Station. Kommt ein Zug zum Entladen, meldet
-- die Ausgabe utl-unloading = 1 – die Greifarme drehen sich um und entladen.
local REVERSIBLE = [[
-- Die Auftrags-Ausgabe braucht „UTL: Ladesteuerung“; in der Tipps-Welt ist nichts erforscht.
-- Danach den Abnehmer neu einstellen – dabei legt UTL seine Ausgabe an.
force.technologies["utl-loading-control"].researched = true
force.technologies["utl-storage"].researched = true
remote.call("utl", "configure_station", r_unit, { mode = "station" })
-- Keine Inaktivitäts-Wartezeit in dieser Szene: der Zug fährt, sobald er voll bzw. leer ist
remote.call("utl", "set_map_config", "utl-load-timeout", 0)
remote.call("utl", "set_map_config", "utl-unload-timeout", 0)
local revs = {}
for _, x in ipairs({ -18.5, -20.5 }) do
  for _, e in pairs(s.find_entities_filtered({ name = "bulk-inserter", position = { x, -0.5 }, radius = 0.4 })) do e.destroy() end
  revs[#revs + 1] = s.create_entity({ name = "utl-reversible-inserter", position = { x, -0.5 }, direction = 0,
    force = force, raise_built = true })
end
-- Die Auftrags-Ausgabe legt UTL erst einen Moment nach dem Aufbau an: verdrahten, sobald sie da
-- ist (eigener Takt 37 – im Test läuft die Szene in einem Mod, der 30 schon belegt).
local R = defines.wire_connector_id.circuit_red
local built, wired, logged = revs[1].direction, false, false
script.on_nth_tick(37, function(e)
  if not wired then
    local output = s.find_entities_filtered({ name = "utl-station-output", position = requester.position, radius = 5 })[1]
    if not output then return end
    local relay_at = s.find_non_colliding_position("medium-electric-pole", { -24.5, -2.5 }, 4, 0.5)
    local relay = relay_at and s.create_entity({ name = "medium-electric-pole", position = relay_at, force = force })
    local previous = output.get_wire_connector(R, true)
    if relay then
      previous.connect_to(relay.get_wire_connector(R, true))
      previous = relay.get_wire_connector(R, true)
    end
    for _, rev in ipairs(revs) do
      previous.connect_to(rev.get_wire_connector(R, true))
      previous = rev.get_wire_connector(R, true)
    end
    wired = true
    if game.simulation then script.on_nth_tick(37, nil) end
  elseif not logged and revs[1].valid and revs[1].direction ~= built then
    -- nur für tools/tipstest: wann drehen sich die Greifarme zum ersten Mal?
    log(("[TIPS] reversible erstes umdrehen nach %d s"):format(math.floor(e.tick / 60)))
    logged = true
    script.on_nth_tick(37, nil)
  end
end)
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

-- Schilder an Depot, Anbieter und Abnehmer der Grundstrecke
local ROLE_SIGNS = [[
local STOP = { type = "item", name = "utl-train-stop" }
sign(-3, 6, "depot", STOP)
sign(22, 8, "provider", { type = "item", name = "iron-plate" })
sign(-16.5, -4.5, "requester", { type = "item", name = "iron-plate" })
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


return {
  SIMPLE = SIMPLE, FUEL = FUEL, CLEANUP = CLEANUP, CLEANUP_RETURN = CLEANUP_RETURN, REVERSIBLE = REVERSIBLE, ROLES = ROLES, REQUESTS = REQUESTS,
  DEPOTS = DEPOTS, COPY = COPY, ROLE_SIGNS = ROLE_SIGNS, scene = scene, window = window,
}
