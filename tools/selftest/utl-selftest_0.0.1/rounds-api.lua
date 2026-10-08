-- Selbsttest R41 (08.10.2026): Schnittstelle für Add-ons auf eigener Oberfläche.
--   a) add_delivery_stop: Halt „R41-Umbau“ vor dem Anbieter, Ereignis on_train_arrived dort mit Lieferung
--   b) begin/end_train_change: beim Laden Wagen ab- und wieder ankuppeln, ohne den Fahrplan zu
--      sichern – UTL hängt die Lieferung um und setzt die fehlenden Halte selbst neu
--   c) hold_train/release_train: festgehaltener Zug ist nicht frei, nach der Freigabe wieder
--   d) get_trains_at_station, api_version, on_train_idle, on_train_rebuilt
local Api = {}

local W = defines.wire_connector_id
local CARGO = defines.inventory.cargo_wagon
local LINE = 1
local MOD = "utl-selftest"

--- Ereignisse mitschreiben (aus Rounds.listen, in on_init und on_load angemeldet).
function Api.record(name, event)
  local log = storage.r41_events or { arrived = {}, rebuilt = {}, idle = 0 }
  storage.r41_events = log
  if name == "on_train_arrived" and event.stop and event.stop.valid then
    log.arrived[event.stop.backer_name] = event.delivery_id or true
    if event.stop.backer_name:sub(1, 3) == "R41" then
      log.order = log.order or {}
      log.order[#log.order + 1] = event.stop.backer_name .. "@" .. game.tick .. "#" .. event.train_id
    end
  elseif name == "on_train_rebuilt" then
    for _, old in pairs(event.old_train_ids or {}) do log.rebuilt[old] = event.changing == true end
  elseif name == "on_train_idle" then
    log.idle = log.idle + 1
  end
end

local function stop(s, force, name, x, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, LINE + (east and 2 or -2) }, direction = east and 4 or 12,
    force = force, raise_built = true })
  e.backer_name = name
  return e
end

function Api.build(check)
  local s = game.create_surface("utl-selftest-r41")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  local depot = stop(s, force, "R41-Depot", 10, true)
  local extra = stop(s, force, "R41-Umbau", 30, true)
  local prov = stop(s, force, "R41-Anbieter", 60, true)
  local req = stop(s, force, "R41-Abnehmer", -60, false)
  local c = s.create_entity({ name = "constant-combinator", position = { 63.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1,
    { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  c.get_wire_connector(W.circuit_green, true).connect_to(prov.get_wire_connector(W.circuit_green, true))
  local function cfg(e, changes) changes.network = "R41"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg(depot, { mode = "depot" })
  cfg(prov, { mode = "station", provide = true, request = false })
  cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  -- Zug Lok – Wagen – Lok
  local l1 = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local wagon = s.create_entity({ name = "cargo-wagon", position = { -3, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local l2 = s.create_entity({ name = "locomotive", position = { -10, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "R41-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  check("R41 api_version", remote.call("utl", "api_version") == 1)
  return { start = game.tick, loco = l1, wagon = wagon, depot = depot.unit_number, extra = extra.unit_number,
    req = req.unit_number }
end

--- Lieferung an den Abnehmer R41: Halt einfügen, laden, umbauen, entladen.
local function delivery_step(r, d, check)
  local train = r.loco.train
  if d.state == "to_provider" and not r.added then
    r.added = d.id
    local ok, why = remote.call("utl", "add_delivery_stop", d.id,
      { where = "before_provider", station = r.extra, wait = { { type = "time", ticks = 60 } } })
    check("R41 add_delivery_stop vor dem anbieter", ok == true, tostring(why))
  elseif d.state == "loading" and not r.changed then
    local inv = r.wagon.get_inventory(CARGO)
    local old = train.id
    r.changed = { old = old }
    -- Umbau wie ein Kuppel-Add-on: melden, abkuppeln, ankuppeln, Fahrplan NICHT selbst sichern
    remote.call("utl", "begin_train_change", { old })
    r.loco.disconnect_rolling_stock(defines.rail_direction.back)
    r.loco.connect_rolling_stock(defines.rail_direction.back)
    local new = r.loco.train
    new.manual_mode = false
    remote.call("utl", "end_train_change", { old }, new)
    r.changed.new = new.id
    inv.insert({ name = "iron-plate", count = d.manifest["item|iron-plate|normal"] or 400 })
    local info = remote.call("utl", "get_delivery", d.id) --[[@as table?]]
    local found = false
    for _, record in pairs(new.get_schedule().get_records() or {}) do
      if record.temporary and record.station == "R41-Abnehmer" then found = true end
    end
    check("R41 umbau: lieferung hängt am neuen zug, halte wieder da",
      info ~= nil and info.train_id == new.id and new.id ~= old and found,
      serpent.line({ alt = old, neu = new.id, lieferung = info and info.train_id, abnehmer_halt = found }))
  elseif d.state == "unloading" and not r.unloaded then
    r.unloaded = d.id
    r.wagon.get_inventory(CARGO).clear()
    -- kein Anschlussauftrag: Die gerade Strecke hat keine Wendeschleife, der Zug soll ins Depot
    remote.call("utl", "configure_station", r.req, { request = false })
  end
end

--- Liefert true, wenn R41 fertig ist.
function Api.watch(r, check)
  if not r or r.done then return true end
  if not r.unloaded then
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if d.to == "R41-Abnehmer" then delivery_step(r, d, check) end
    end
  end
  local train = r.loco.valid and r.loco.train
  local events = storage.r41_events or { arrived = {}, rebuilt = {}, idle = 0 }
  -- nach der Lieferung frei im Depot: festhalten und wieder freigeben
  if r.unloaded and not r.hold and train and train.state == defines.train_state.wait_station
    and train.station and train.station.backer_name == "R41-Depot" then
    local function idle()
      for _, t in pairs(remote.call("utl", "get_idle_trains", { network = "R41" })) do
        if t.id == train.id then return true end
      end
      return false
    end
    if idle() then
      r.hold = true
      local at = remote.call("utl", "get_trains_at_station", r.depot) --[[@as table]]
      check("R41 get_trains_at_station", at.here[1] == train.id, serpent.line(at))
      local held = remote.call("utl", "hold_train", train.id, MOD)
      local other = remote.call("utl", "hold_train", train.id, "anderer-mod")
      check("R41 hold_train: nicht mehr frei, nur ein mod", held == true and other == false and not idle()
        and remote.call("utl", "is_held", train.id) == MOD)
      check("R41 release_train: wieder frei", remote.call("utl", "release_train", train.id) == true and idle()
        and remote.call("utl", "is_held", train.id) == nil)
      check("R41 ereignisse: ankunft am eingefügten halt, umbau, frei im depot",
        events.arrived["R41-Umbau"] == r.added and events.rebuilt[r.changed.old] == true and events.idle > 0,
        serpent.line({ ankunft = events.arrived["R41-Umbau"], lieferung = r.added, umbau = events.rebuilt[r.changed.old],
          frei = events.idle }))
      r.done = true
    end
  end
  if not r.done and game.tick - r.start > 30000 then
    r.done = true
    local open, records = {}, {}
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if d.to == "R41-Abnehmer" then open[#open + 1] = d.state end
    end
    for _, record in pairs(train and train.get_schedule().get_records() or {}) do
      records[#records + 1] = record.station or "gleis"
    end
    check("R41 schnittstelle für add-ons", false, serpent.line({ added = r.added, changed = r.changed,
      unloaded = r.unloaded, lieferung = open, fahrplan = records,
      zug = train and { state = train.state, wait = defines.train_state.wait_station, station = train.station and train.station.backer_name,
        info = remote.call("utl", "get_train", train.id), wagen = #train.carriages, vorn = #train.locomotives.front_movers,
        hinten = #train.locomotives.back_movers, x = train.front_stock.position.x, manuell = train.manual_mode,
        aktuell = train.get_schedule().current, folge = events.order, frei = remote.call("utl", "get_idle_trains", { network = "R41" }) },
      ereignisse = storage.r36 }))
  end
  return r.done
end

return Api
