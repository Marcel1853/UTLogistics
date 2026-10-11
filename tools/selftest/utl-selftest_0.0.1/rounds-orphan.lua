-- Selbsttest R45 (11.10.2026): verwaiste Lieferung. Ein Lieferzug verliert unterwegs zum Anbieter
-- alle UTL-Halte (von Hand oder durch einen anderen Mod) und fährt mit seinem eigenen Fahrplan ins
-- Depot. Früher blieb die Lieferung für immer „unterwegs“ und blockierte den Bedarf des Abnehmers
-- (gefunden in Marcels Spiel: Zug 134 / Lieferung 516). Jetzt: nach einer Minute ohne Zustands-
-- wechsel abbrechen („Fahrplan verloren“), Zug wieder frei, der Abnehmer bekommt eine neue Lieferung.
local Orphan = {}

local W = defines.wire_connector_id
local LINE = 1

local function stop(s, force, name, x, y, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, y }, direction = east and 4 or 12,
    force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

function Orphan.build()
  local s = game.create_surface("utl-selftest-r45")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  local depot = stop(s, force, "R45-Depot", 10, LINE + 2, true)
  local prov = stop(s, force, "R45-Anbieter", 60, LINE + 2, true)
  local req = stop(s, force, "R45-Abnehmer", -60, LINE - 2, false)
  local c = s.create_entity({ name = "constant-combinator", position = { 63.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  c.get_wire_connector(W.circuit_green, true).connect_to(prov.get_wire_connector(W.circuit_green, true))
  local function cfg(e, changes) changes.network = "R45"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg(depot, { mode = "depot" })
  cfg(prov, { mode = "station", provide = true, request = false })
  cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  local l1 = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  s.create_entity({ name = "cargo-wagon", position = { -3, LINE }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { -10, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "R45-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return { start = game.tick, loco = l1 }
end

--- UTL-Halte entfernen wie ein Spieler, der den Fahrplan von Hand leert.
local function strip(train)
  local schedule = train.get_schedule()
  local records = schedule.get_records() or {}
  for i = #records, 1, -1 do
    if records[i].temporary then schedule.remove_record({ schedule_index = i }) end
  end
  schedule.go_to_station(1)
end

--- Liefert true, wenn R45 fertig ist.
function Orphan.watch(r, check)
  if not r or r.done then return true end
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if d.to == "R45-Abnehmer" then
      if not r.stripped and d.state == "to_provider" and r.loco.valid then
        r.stripped = game.tick
        r.first = d.id
        strip(r.loco.train)
      elseif r.first and d.id ~= r.first and not r.second then
        r.second = d.id -- neue Lieferung: der Abnehmer ist nicht mehr blockiert
      end
    end
  end
  if r.stripped and not r.canceled then
    for _, alert in ipairs(remote.call("utl", "get_alerts")) do
      if alert.key == "canceled:" .. r.first then r.canceled = game.tick end
    end
  end
  if r.second then
    r.done = true
    check("R45 verwaiste lieferung abgebrochen", r.canceled ~= nil and r.canceled - r.stripped >= 3600,
      "abbruch nach " .. tostring(r.canceled and (r.canceled - r.stripped)) .. " ticks")
    check("R45 abnehmer danach wieder beliefert", true)
  elseif game.tick - r.start > 36000 then
    r.done = true
    check("R45 verwaiste lieferung abgebrochen, abnehmer wieder beliefert", false,
      serpent.line({ geleert = r.stripped, abgebrochen = r.canceled, erste = r.first }))
  end
  return r.done
end

return Orphan
