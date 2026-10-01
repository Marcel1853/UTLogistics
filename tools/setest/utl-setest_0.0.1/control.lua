-- Aufzug-Test: UTL-Lieferung über einen Weltraumaufzug, ohne echtes Space Exploration.
-- Headless gibt es keinen Spieler, und SE baut Aufzüge nur für Teams mit Spielern. Dieser Mod
-- stellt deshalb die Schnittstelle „space-exploration“ nach (dieselben Aufrufe und Ereignisse wie
-- SE 0.7.62) und macht das Durchfahren wie SE: neuer Zug auf der anderen Oberfläche (neue ID),
-- Fahrplan ohne Schienen-Einträge und ohne den Aufzug-Halt, Ereignisse „started“/„finished“.
--
-- Aufbau (je Oberfläche eine gerade Strecke, alles in Fahrtrichtung Ost):
--   Planet: Depot (-60) → Anbieter (0) → Aufzug ↑ (60)
--   Orbit:  Ankunft (-90) → Abnehmer (0) → Aufzug ↓ (60)
-- Laden und Entladen übernimmt der Test per Script.
local function check(name, ok, info)
  storage.results = storage.results or {}
  local results = storage.results
  results[#results + 1] = (ok and "PASS " or "FAIL ") .. name .. (info and (" -- " .. tostring(info)) or "")
end

local STARTED = script.generate_event_name()
local FINISHED = script.generate_event_name()
local CHANGED = script.generate_event_name()

local LINE = 1
local NETWORK = "SE"

--- Nachgebildete Aufzüge: Haupt-Entity = die Aufzug-Haltestelle selbst.
local function elevator_of(unit)
  local t = storage.test
  if not t then return nil end
  if t.up.unit_number == unit then return t.up, t.down end
  if t.down.unit_number == unit then return t.down, t.up end
  return nil
end

remote.add_interface("space-exploration", {
  get_on_train_teleport_started_event = function() return STARTED end,
  get_on_train_teleport_finished_event = function() return FINISHED end,
  get_on_space_elevator_changed_state_event = function() return CHANGED end,
  get_space_elevator_info = function(data)
    local here, there = elevator_of(data.unit_number)
    if not here then return nil end
    return { main = here, train_stop = here, opposite = there, constructed = true, powered = true }
  end,
})

local function surface(name)
  local s = game.create_surface(name)
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  for x = -121, 121, 2 do
    s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = "player" })
  end
  return s
end

local function stop(s, name, x)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, LINE + 2 }, direction = 4, force = "player",
    raise_built = true })
  e.backer_name = name
  return e
end

local function plain_stop(s, name, x)
  local e = s.create_entity({ name = "train-stop", position = { x, LINE + 2 }, direction = 4, force = "player" })
  e.backer_name = name
  return e
end

--- Zug Lok – Wagen – Lok mit der vorderen Lok bei x (Fahrtrichtung Ost).
local function train(s, x)
  local l1 = s.create_entity({ name = "locomotive", position = { x, LINE }, direction = 4, force = "player" })
  local wagon = s.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, LINE }, direction = 4, force = "player" })
  local l2 = s.create_entity({ name = "locomotive", position = { wagon.position.x - 7, LINE }, direction = 12, force = "player" })
  l1.insert({ name = "coal", count = 50 })
  l2.insert({ name = "coal", count = 50 })
  return l1.train, wagon
end

local function configure(e, changes)
  changes.network = NETWORK
  remote.call("utl", "configure_station", e.unit_number, changes)
end

script.on_init(function()
  local planet, orbit = surface("se-test-planet"), surface("se-test-orbit")
  local t = {}
  storage.test = t
  t.depot = stop(planet, "SE-Depot", -60)
  t.provider = stop(planet, "SE-Anbieter", 0)
  t.requester = stop(orbit, "SE-Abnehmer", 0)
  -- Aufzug-Halte sind bei SE normale Haltestellen (keine UTL-Stationen)
  t.up = plain_stop(planet, "Aufzug ↑", 60)
  t.down = plain_stop(orbit, "Aufzug ↓", 60)
  configure(t.depot, { mode = "depot" })
  configure(t.provider, { mode = "station", provide = true, request = false })
  configure(t.requester, { mode = "station", provide = false, request = true, request_threshold = 100 })
  local c = planet.create_entity({ name = "constant-combinator", position = { 3.5, LINE + 5.5 }, force = "player" })
  ---@cast c -?
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1,
    { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  c.get_wire_connector(defines.wire_connector_id.circuit_green, true)
    .connect_to(t.provider.get_wire_connector(defines.wire_connector_id.circuit_green, true))
  remote.call("utl", "set_request", t.requester.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  -- Aufzug fertig gebaut und mit Strom: wie SE per Ereignis melden
  script.raise_event(CHANGED, { primary = t.up, constructed = true, powered = true })
  check("aufzug erkannt", #remote.call("utl", "get_elevators") == 2, #remote.call("utl", "get_elevators"))
  -- Schalter noch aus: keine Lieferung über den Aufzug (erst nach 30 s einschalten)
  local tr = train(planet, -80)
  local schedule = tr.get_schedule()
  schedule.add_record({ station = "SE-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  tr.manual_mode = false
  t.loco = tr.front_stock
  t.phase = "off"
  t.start = game.tick
  t.teleports = 0
end)

--- Fahrplan-Einträge als kurze Liste für die Prüfung: „R“ = Schienen-Wegpunkt, sonst Stationsname.
local function records(tr)
  local list = {}
  for i, r in ipairs(tr.get_schedule().get_records() or {}) do
    list[i] = r.rail and "R" or (r.station .. (r.temporary and "*" or ""))
  end
  return list
end

--- Durchfahren wie SE: neuer Zug drüben, alter weg, Fahrplan ohne Schienen-Einträge und ohne den
--- (temporären) Aufzug-Halt, weiter beim nächsten Eintrag.
local function teleport(old, target_surface, teleporter)
  local t = storage.test
  local old_id = old.id
  local schedule = old.get_schedule()
  local list = schedule.get_records() or {}
  local current = schedule.current
  local kept, new_current = {}, nil
  for i, r in ipairs(list) do
    local skip = r.rail ~= nil or (i == current and r.temporary)
    if not skip then
      kept[#kept + 1] = r
      if i > current and not new_current then new_current = #kept end
    end
  end
  new_current = new_current or 1
  local contents = old.get_contents()
  local old_wagon = old.cargo_wagons[1]
  local old_surface = old_wagon.surface_index
  local filters = {}
  local old_inv = old_wagon.get_inventory(defines.inventory.cargo_wagon)
  for i = 1, #old_inv do filters[i] = old_inv.get_filter(i) end
  -- erster Wagen drüben: SE meldet „started“
  local new, wagon = train(target_surface, -90)
  script.raise_event(STARTED, { train = new, old_train_id_1 = old_id, old_surface_index = old_surface,
    teleporter = teleporter })
  local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
  for i, f in pairs(filters) do inv.set_filter(i, f) end
  for _, stack in pairs(contents) do inv.insert({ name = stack.name, count = stack.count, quality = stack.quality }) end
  -- alter Zug Wagen für Wagen weg (jeder Rest bekommt eine neue ID, wie bei SE)
  for _, carriage in pairs(old.carriages) do if carriage.valid then carriage.destroy({ raise_destroy = true }) end end
  local new_schedule = new.get_schedule()
  new_schedule.set_records(kept)
  new_schedule.go_to_station(new_current)
  new.manual_mode = false
  t.loco = new.front_stock
  t.teleports = t.teleports + 1
  script.raise_event(FINISHED, { train = new, old_train_id_1 = old_id, old_surface_index = old_surface,
    teleporter = teleporter })
  return new
end

script.on_event(defines.events.on_train_changed_state, function(event)
  local t = storage.test
  local tr = event.train
  if not (t and tr.valid and tr.state == defines.train_state.wait_station) then return end
  local station = tr.station
  if station == t.up then
    t.before_up = records(tr)
    teleport(tr, t.down.surface, t.up)
    t.after_up = records(t.loco.train)
    -- Runde 2: Abnehmer drüben abgerissen, während der Zug im Orbit ist → Abbruch, Heimweg
    if t.round == 2 then
      t.loco.train.cargo_wagons[1].get_inventory(defines.inventory.cargo_wagon).clear()
      t.requester.destroy({ raise_destroy = true })
      t.cancel_pending = true -- UTL verbucht den Abriss erst einen Tick später
    end
    local d = remote.call("utl", "get_deliveries")[1]
    t.after_up_delivery = d and { train_id = d.train_id, state = d.state, new_id = t.loco.train.id }
  elseif station == t.down then
    teleport(tr, t.up.surface, t.down)
  end
end)

local function finish()
  local t = storage.test
  t.done = true
  for _, line in ipairs(storage.results or {}) do log("[SETEST] " .. line) end
  log("[SETEST] ENDE")
end

script.on_nth_tick(10, function()
  local t = storage.test
  if not t or t.done then return end
  local tr = t.loco.valid and t.loco.train
  local deliveries = remote.call("utl", "get_deliveries")
  local d = deliveries[1]
  if t.phase == "off" then
    if d then
      check("ohne schalter keine lieferung über den aufzug", false, d.from .. " -> " .. d.to)
      return finish()
    end
    if game.tick - t.start > 30 * 60 then
      check("ohne schalter keine lieferung über den aufzug", true)
      remote.call("utl", "set_elevator_network", "player", NETWORK, true)
      t.phase = "on"
    end
    return
  end
  if d and not t.seen then
    t.seen = true
    local list = records(tr)
    t.sent = table.concat(list, ",")
    check("lieferung planet -> orbit angelegt", d.from == "SE-Anbieter" and d.to == "SE-Abnehmer", d.from .. " -> " .. d.to)
  end
  if t.cancel_pending and not d and tr then
    t.cancel_pending = nil
    t.after_cancel = table.concat(records(tr), ",")
  end
  -- Laden und Entladen per Script
  if d and tr and d.state == "loading" and not t.loaded then
    t.loaded = true
    tr.cargo_wagons[1].get_inventory(defines.inventory.cargo_wagon).insert({ name = "iron-plate", count = d.manifest["item|iron-plate|normal"] or 400 })
  elseif d and tr and d.state == "unloading" and not t.unloaded then
    t.unloaded = true
    tr.cargo_wagons[1].get_inventory(defines.inventory.cargo_wagon).clear()
  end
  if t.unloaded and not d and not t.after_unload and tr then
    t.after_unload = table.concat(records(tr), ",")
  end
  if t.round == 2 and t.teleports >= 4 and tr and tr.state == defines.train_state.wait_station and tr.station == t.depot then
    check("abbruch drüben: aufzug ↓ eingeplant", t.after_cancel and t.after_cancel:find("Aufzug ↓%*") ~= nil, t.after_cancel)
    check("abbruch drüben: zurück im depot", tr.front_stock.surface == t.depot.surface
      and remote.call("utl", "idle_train_count") == 1 and remote.call("utl", "delivery_count") == 0,
      remote.call("utl", "idle_train_count") .. "/" .. remote.call("utl", "delivery_count"))
    return finish()
  end
  if t.round ~= 2 and t.teleports >= 2 and tr and tr.state == defines.train_state.wait_station and tr.station == t.depot then
    check("fahrplan: anbieter, aufzug, abnehmer nur als station",
      t.sent and t.sent:find("R,SE%-Anbieter%*,Aufzug ↑%*,SE%-Abnehmer%*") ~= nil, t.sent)
    check("vor dem aufzug: aufzug ist der aktuelle halt", t.before_up ~= nil, table.concat(t.before_up or {}, ","))
    local a = t.after_up_delivery
    check("nach dem aufzug: lieferung auf neuer zug-id", a and a.train_id == a.new_id and a.state == "to_requester",
      a and (a.train_id .. "/" .. a.new_id .. " " .. a.state))
    check("nach dem aufzug: wegpunkt vor dem abnehmer", table.concat(t.after_up or {}, ","):find("R,SE%-Abnehmer%*") ~= nil,
      table.concat(t.after_up or {}, ","))
    check("entladen im orbit", t.unloaded == true)
    check("heimweg: aufzug ↓ vor dem depot", t.after_unload and t.after_unload:find("Aufzug ↓%*") ~= nil, t.after_unload)
    check("zurück im depot auf dem planet", tr.front_stock.surface == t.depot.surface and remote.call("utl", "idle_train_count") == 1,
      remote.call("utl", "idle_train_count"))
    check("statistik: eine lieferung fertig", remote.call("utl", "delivery_count") == 0)
    -- Runde 2: der Abnehmer bestellt wieder, der nächste Zug fährt los
    t.round = 2
    t.seen, t.loaded, t.unloaded = nil, nil, nil
    return
  end
  if game.tick - t.start > 20 * 60 * 60 then
    check("zeitlimit", false, "phase " .. t.phase .. ", teleports " .. t.teleports .. ", zug " ..
      (tr and (tr.state .. " " .. table.concat(records(tr), ",")) or "weg") .. " geladen " .. tostring(t.loaded)
      .. " entladen " .. tostring(t.unloaded) .. " pos " .. serpent.line(tr and tr.front_stock.position)
      .. " fläche " .. tostring(tr and tr.front_stock.surface.name) .. " id " .. tostring(tr and tr.id)
      .. " lieferungen " .. serpent.line(deliveries) .. " inhalt " .. serpent.line(tr and tr.get_contents()))
    finish()
  end
end)
