--- Szenario „UTL-Aufzug“ (nur mit Space Exploration, ohne Space Age): ein Weltraumaufzug zwischen
--- Nauvis und Nauvis Orbit, auf jeder Seite eine Einbahn-Schleife mit UTL-Stationen im selben Netz
--- „Aufzug“. Der Planet liefert Eisen in den Orbit, der Orbit Kupfer auf den Planeten.
--- Gebaut wird, sobald ein Spieler da ist (SE lässt Aufzüge nur für Teams mit Spielern zu).
--- Das Skript hält den Aufzug fertig gebaut und mit Strom; Greifarme setzt es bei der ersten Ankunft
--- eines Zugs an die Wagen.
local World = require("__utl-testtools__/scenarios/UTL-Aufzug/world")

local SE = "space-exploration"
local CENTER = { x = 400, y = 0 }
local AREA = { { CENTER.x - 220, CENTER.y - 110 }, { CENTER.x + 90, CENTER.y + 40 } }
local NETWORK = "Aufzug"

local function report(text) log("[AUF] " .. text) end

--- Fläche frei machen und mit festem Boden auslegen (Planet: Landfill, Orbit: Plattform-Gerüst).
local function prepare(surface, tile)
  surface.request_to_generate_chunks(CENTER, 9)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities_filtered({ area = AREA })) do
    if entity.valid and entity.type ~= "character" then entity.destroy() end
  end
  local tiles = {}
  for x = AREA[1][1], AREA[2][1] do
    for y = AREA[1][2], AREA[2][2] do tiles[#tiles + 1] = { name = tile, position = { x, y } } end
  end
  surface.set_tiles(tiles)
end

local function configure(stop, changes)
  changes.network = NETWORK
  remote.call("utl", "configure_station", stop.unit_number, changes)
end

--- Anbieter: Konstant-Kombinator (grün) meldet 10 000 Stück Vorrat.
local function provide(stop, item)
  configure(stop, { mode = "station", provide = true, request = false })
  local c = stop.surface.create_entity({ name = "constant-combinator", force = stop.force,
    position = { stop.position.x - 1.5, stop.position.y + 1.5 } })
  if not c then return end
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1, { value = { type = "item", name = item, quality = "normal", comparator = "=" }, min = 10000 })
  c.get_wire_connector(defines.wire_connector_id.circuit_green, true)
    .connect_to(stop.get_wire_connector(defines.wire_connector_id.circuit_green, true))
end

local function request(stop, item)
  configure(stop, { mode = "station", provide = false, request = true, request_threshold = 400 })
  remote.call("utl", "set_request", stop.unit_number, 1, { type = "item", name = item }, 2000)
end

--- Eine Seite: Schleife, Stationen, Züge. `roles` ordnet jeder Station eine Aufgabe zu.
local function side(surface, planner, layout, roles, trains)
  local result = World.loop(surface, game.forces["player"], CENTER, planner, layout)
  report(surface.name .. ": Schleife " .. (result.ok and "fertig" or "FEHLER") .. " – " .. result.info)
  local placed = 0
  for _, entry in ipairs(result.stops) do
    local role = roles[entry.name]
    if entry.stop and role then
      if role.depot then
        configure(entry.stop, { mode = "depot" })
        if placed < trains and World.train(entry.stop, "nuclear-fuel") then placed = placed + 1 end
      elseif role.provide then
        storage.stops = storage.stops or {}
        storage.stops[entry.name] = entry.stop -- für die Wiki-Bilder
        provide(entry.stop, role.provide)
        storage.docks[entry.stop.unit_number] = { load = true, item = role.provide }
      elseif role.request then
        request(entry.stop, role.request)
        storage.docks[entry.stop.unit_number] = { load = false }
      end
    end
  end
  return result.ok, placed
end

local function build(player)
  if not (script.active_mods[SE] and remote.interfaces[SE]) then
    game.print({ "utl-aufzug.need-se" })
    return false
  end
  local force = game.forces["player"]
  force.research_all_technologies()
  -- zwei Satelliten: erst dann erlaubt SE Aufzüge (Fahrten zwischen Oberflächen)
  remote.call(SE, "launch_satellite", { force_name = force.name, surface = game.surfaces["nauvis"], count = 2 })
  local planet = game.surfaces["nauvis"]
  local zone = remote.call(SE, "get_zone_from_name", { zone_name = "Nauvis Orbit" }) --[[@as table?]]
  local orbit = zone and remote.call(SE, "zone_get_make_surface", { zone_index = zone.index })
  if not orbit then
    report("FEHLER: Nauvis Orbit nicht gefunden")
    return false
  end
  prepare(planet, "landfill")
  prepare(orbit, "se-space-platform-scaffold")
  local elevator = planet.create_entity({ name = "se-space-elevator", position = CENTER, force = force,
    direction = defines.direction.east, raise_built = true })
  local info = elevator and elevator.valid and remote.call(SE, "get_space_elevator_info", { unit_number = elevator.unit_number })
  if not info then
    report("FEHLER: Aufzug nicht gebaut")
    game.print({ "utl-aufzug.build-failed" })
    return false
  end
  storage.elevator = elevator
  storage.docks = {}
  -- genug Bauteile für den ganzen Aufzug (SE zählt fertige „Produkte“ der Planeten-Seite)
  elevator.products_finished = elevator.products_finished + 100000
  local ok1, t1 = side(planet, "rail", { top = { "Planet-Depot", "Planet-Depot" }, bottom = { "Planet-Abnehmer Kupfer", "Planet-Anbieter Eisen" } },
    { ["Planet-Depot"] = { depot = true }, ["Planet-Anbieter Eisen"] = { provide = "iron-plate" },
      ["Planet-Abnehmer Kupfer"] = { request = "copper-plate" } }, 2)
  local ok2, t2 = side(orbit, "se-space-rail", { top = { "Orbit-Depot" }, bottom = { "Orbit-Abnehmer Eisen", "Orbit-Anbieter Kupfer" } },
    { ["Orbit-Depot"] = { depot = true }, ["Orbit-Anbieter Kupfer"] = { provide = "copper-plate" },
      ["Orbit-Abnehmer Eisen"] = { request = "iron-plate" } }, 1)
  remote.call("utl", "set_elevator_network", force.name, NETWORK, true)
  for _, surface in pairs({ planet, orbit }) do
    force.chart(surface, AREA)
    force.add_chart_tag(surface, { position = CENTER, text = "Weltraumaufzug", icon = { type = "item", name = "se-space-elevator" } })
  end
  report(("gebaut: Planet %s (%d Züge), Orbit %s (%d Zug)"):format(tostring(ok1), t1, tostring(ok2), t2))
  player.teleport(planet.find_non_colliding_position("character", { CENTER.x - 30, CENTER.y + 14 }, 20, 1) or CENTER, planet)
  player.cheat_mode = true
  player.print({ "utl-aufzug.welcome" })
  return true
end

--- Aufzug fertig und mit Strom halten (beide Seiten), und Fortschritt melden.
local function maintain()
  local elevator = storage.elevator
  if not (elevator and elevator.valid) then return end
  elevator.products_finished = elevator.products_finished + 1
  local info = remote.call(SE, "get_space_elevator_info", { unit_number = elevator.unit_number }) --[[@as table?]]
  for _, main in pairs({ elevator, info and info.opposite }) do
    if main and main.valid then
      for _, interface in pairs(main.surface.find_entities_filtered({ name = "se-space-elevator-energy-interface",
        position = main.position, radius = 2 })) do
        interface.energy = interface.electric_buffer_size
      end
    end
  end
  if info and info.constructed and info.powered and not storage.ready then
    storage.ready = game.tick
    report("Aufzug fertig und mit Strom")
  end
end

-- Greifarme bei der ersten Ankunft eines Zugs an Anbieter oder Abnehmer
script.on_event(defines.events.on_train_changed_state, function(event)
  local train = event.train
  if not (storage.docks and train.valid and train.state == defines.train_state.wait_station and train.station) then return end
  local dock = storage.docks[train.station.unit_number]
  if dock and not dock.done then
    dock.done = World.dock(train.station, train, dock.load, dock.item)
    report(train.station.backer_name .. ": " .. dock.done .. " Greifarme gesetzt")
  end
end)

-- Wiki-Bilder: nur wenn tools/aufzug.sh im Bildermodus die Datei „shots.lua“ in den kopierten
-- Werkzeug-Mod legt (wer selbst spielt, bekommt keine Fenster geöffnet)
local ok_shots, shots_wanted = pcall(require, "__utl-testtools__/scenarios/UTL-Aufzug/shots")
local SHOTS = ok_shots and shots_wanted == true

local function shot(name, opts)
  game.take_screenshot({ player = game.get_player(1), surface = opts.surface, position = opts.position,
    zoom = opts.zoom, path = "utl-aufzug/" .. name .. ".png", show_gui = opts.gui == true,
    resolution = { 1920, 1080 }, daytime = 0 })
end

--- Bilderfolge ab 4 Minuten nach „Aufzug fertig“ (dann laufen Lieferungen), ein Schritt alle 2 s.
local function shots_step()
  local step = storage.shot_step or 1
  local planet = game.surfaces["nauvis"]
  local zone = remote.call(SE, "get_zone_from_name", { zone_name = "Nauvis Orbit" }) --[[@as table?]]
  local orbit = zone and remote.call(SE, "zone_get_make_surface", { zone_index = zone.index }) --[[@as LuaSurface?]]
  local overview = { x = CENTER.x - 65, y = CENTER.y - 30 }
  local provider = storage.stops and storage.stops["Planet-Anbieter Eisen"]
  local steps = {
    function() shot("aufzug-planet", { surface = planet, position = overview, zoom = 0.28 }) end,
    function() if orbit then shot("aufzug-orbit", { surface = orbit, position = overview, zoom = 0.28 }) end end,
    function() shot("aufzug-nah", { surface = planet, position = { CENTER.x - 4, CENTER.y - 2 }, zoom = 0.9 }) end,
    function() if provider and provider.valid then remote.call("utl", "open_station", 1, provider.unit_number, 1) end end,
    function() shot("aufzug-stationsfenster", { gui = true }) end,
    function()
      remote.call("utl", "close_windows", 1)
      remote.call("utl", "open_manager", 1, "networks", { network = planet.index .. "|" .. NETWORK })
    end,
    function() shot("aufzug-manager-netzwerke", { gui = true }) end,
    function() remote.call("utl", "close_windows", 1) end,
  }
  if steps[step] then
    local ok, err = pcall(steps[step])
    if not ok then report("Bild-Schritt " .. step .. ": " .. tostring(err)) end
    storage.shot_step = step + 1
  elseif not storage.shots_done then
    storage.shots_done = true
    report("Bilder fertig")
  end
end

script.on_nth_tick(60, function()
  if not storage.built then
    local player = game.connected_players[1]
    if player and game.tick >= 120 then storage.built = build(player) and game.tick or -1 end
    return
  end
  if storage.built == -1 then return end
  maintain()
  if SHOTS and storage.ready and game.tick - storage.ready > 4 * 3600 and game.tick % 120 == 0 then shots_step() end
  -- alle 60 s: Lieferungen und Aufzug-Fahrten fürs Log (für den Test)
  if game.tick % 3600 == 0 then
    local stats = remote.call("utl", "get_statistics") --[[@as table]]
    local goods = {}
    for key, sum in pairs(stats.goods) do goods[key] = sum.ten end
    report(("Stand nach %d s: fertige Lieferungen %d, laufend %d, frei im Depot %d, Waren (10 min) %s"):format(
      math.floor((game.tick - storage.built) / 60), stats.deliveries, remote.call("utl", "delivery_count"),
      remote.call("utl", "idle_train_count"), serpent.line(goods)))
  end
end)
