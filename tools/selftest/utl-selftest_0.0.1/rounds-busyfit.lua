-- Selbsttest R46 (11.10.2026): Warnung „freie Züge passen nicht“ nur bei echtem Einstellungsfehler.
-- Gefunden in Marcels Spiel: Erzzüge standen frei, die Flüssigkeitszüge waren unterwegs – die Warnung
-- „Zuglänge oder Laderaum prüfen“ kam dauernd, obwohl ein passender Zug existiert.
-- Aufbau: kurzer Zug (3 Wagen) bekommt eine Lieferung und bleibt beim Anbieter stehen (niemand lädt),
-- langer Zug (4) steht frei im Depot. Abnehmer A und B nehmen höchstens 3 Wagen: der eine wird
-- beliefert, der andere wartet → nur Sammelwarnung. Abnehmer C nimmt höchstens 2 → kein Zug passt
-- überhaupt → Einzelwarnung bleibt.
local BusyFit = {}

local W = defines.wire_connector_id
local LINE = 1

local function stop(s, force, name, x, y, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, y }, direction = east and 4 or 12,
    force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

--- Zug aus Lok, `wagons` Güterwagen und Lok auf Gleis `y`, Fahrplan nur das Depot.
local function train(s, force, x, y, wagons)
  local front = s.create_entity({ name = "locomotive", position = { x, y }, direction = 4, force = force }) --[[@as LuaEntity]]
  x = x - 7
  for _ = 1, wagons do
    s.create_entity({ name = "cargo-wagon", position = { x, y }, direction = 4, force = force })
    x = x - 7
  end
  local back = s.create_entity({ name = "locomotive", position = { x, y }, direction = 12, force = force }) --[[@as LuaEntity]]
  front.insert({ name = "coal", count = 150 })
  back.insert({ name = "coal", count = 150 })
  local schedule = front.train.get_schedule()
  schedule.add_record({ station = "R46-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  front.train.manual_mode = false
  return front.train
end

function BusyFit.build()
  local s = game.create_surface("utl-selftest-r46")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  -- zwei parallele Strecken mit je einem Depot, damit beide Züge parken können
  for _, y in ipairs({ LINE, LINE + 20 }) do
    for x = -120, 120, 2 do s.create_entity({ name = "straight-rail", position = { x, y }, direction = 4, force = force }) end
  end
  local depots = { stop(s, force, "R46-Depot", 10, LINE + 2, true), stop(s, force, "R46-Depot", 10, LINE + 22, true) }
  local prov = stop(s, force, "R46-Anbieter", 80, LINE + 2, true)
  local reqs = { stop(s, force, "R46-Abnehmer-A", -80, LINE - 2, false),
    stop(s, force, "R46-Abnehmer-B", -80, LINE + 18, false), stop(s, force, "R46-Abnehmer-C", -100, LINE + 18, false) }
  local c = s.create_entity({ name = "constant-combinator", position = { 83.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 20000 })
  c.get_wire_connector(W.circuit_green, true).connect_to(prov.get_wire_connector(W.circuit_green, true))
  local function cfg(e, changes) changes.network = "R46"; remote.call("utl", "configure_station", e.unit_number, changes) end
  for _, depot in ipairs(depots) do cfg(depot, { mode = "depot" }) end
  cfg(prov, { mode = "station", provide = true, request = false })
  for i, e in ipairs(reqs) do
    cfg(e, { mode = "station", provide = false, request = true, request_threshold = 100, max_train_length = i == 3 and 2 or 3 })
    remote.call("utl", "set_request", e.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  end
  local short = train(s, force, 4, LINE, 1)  -- 3 Fahrzeuge
  train(s, force, 4, LINE + 20, 2)            -- 4 Fahrzeuge: passt bei keinem Abnehmer
  return { start = game.tick, short = short.id, a = reqs[1].unit_number, b = reqs[2].unit_number,
    c = reqs[3].unit_number }
end

--- Liefert true, wenn R46 fertig ist.
function BusyFit.watch(r, check)
  if not r or r.done then return true end
  if not r.busy then
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if d.train_id == r.short then
        r.busy = game.tick
        r.served = d.requester
        -- erst jetzt sofort warnen lassen: vorher fuhren beide Züge noch ins Depot, und solange UTL
        -- den kurzen nicht kennt, wäre „passt nicht“ richtig
        remote.call("utl", "set_map_config", "utl-alert-no-train-minutes", 0)
      end
    end
  end
  -- 40 s nach Lieferbeginn: Warnungen auswerten
  if r.busy and game.tick - r.busy > 2400 then
    r.done = true
    local waiting = r.served == r.a and r.b or r.a
    local single_waiting, single_c, collective = false, false, false
    for _, alert in ipairs(remote.call("utl", "get_alerts")) do
      local fresh = alert.tick > r.busy
      if fresh and alert.key:find("^no%-train:" .. waiting .. ":") then single_waiting = true end
      if fresh and alert.key:find("^no%-train:" .. r.c .. ":") then single_c = true end
      if fresh and alert.key:find("^no%-train%-net:.*|R46$") then collective = true end
    end
    remote.call("utl", "set_map_config", "utl-alert-no-train-minutes", 5)
    check("R46 passender zug unterwegs: keine einzelwarnung „passt nicht“", not single_waiting)
    check("R46 passender zug unterwegs: sammelwarnung je netz", collective)
    check("R46 kein zug passt überhaupt: einzelwarnung bleibt", single_c)
  elseif not r.busy and game.tick - r.start > 30000 then
    r.done = true
    remote.call("utl", "set_map_config", "utl-alert-no-train-minutes", 5)
    check("R46 warnung „passt nicht“ nur bei echtem einstellungsfehler", false, "kurzer zug bekam keine lieferung")
  end
  return r.done
end

return BusyFit
