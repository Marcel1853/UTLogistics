--- Fahrplan-Helfer. Lieferungen werden als *temporäre* Halte in den vorhandenen Fahrplan
--- eingefügt: Der eigene Fahrplan des Zugs (Depot, Gruppe, Interrupts) bleibt erhalten, und
--- die Halte verschwinden nach dem Abfahren von selbst. Temporäre Halte gelten nur für diesen
--- Zug, auch wenn er in einer Zuggruppe ist (headless geprüft).
---
--- Pro Halt zwei Einträge: ein Schienen-Wegpunkt direkt vor der Haltestelle (ohne Warten), damit
--- der Zug bei gleichnamigen Haltestellen genau diese anfährt, danach die Station selbst.
local Util = require("scripts.lib.util")

local Schedule = {}

-- Tankstelle: bis alle Loks voll sind, höchstens 30 s (leere Kiste soll den Zug nicht festhalten).
local FUEL_WAIT = {
  { type = "fuel_full" },
  { type = "time", ticks = 30 * 60, compare_type = "or" },
}

-- Cleanup: bis die Waren, die diese Station annimmt, weg sind (je Ware „= 0“, alle mit UND),
-- höchstens 30 s ohne Bewegung in der Ladung (volle Kiste). Wie bei LTN Cleanup nicht „leer“:
-- auf einer Route über mehrere Cleanups bleibt der Rest für die nächste Station im Zug.
local function cleanup_conditions(wares)
  local conditions = {}
  for _, ware in ipairs(wares) do
    local fluid = ware.kind == "fluid"
    conditions[#conditions + 1] = {
      type = fluid and "fluid_count" or "item_count",
      condition = {
        first_signal = fluid and { type = "fluid", name = ware.name } or { type = "item", name = ware.name, quality = ware.quality },
        comparator = "=",
        constant = 0,
      },
    }
  end
  conditions[#conditions + 1] = { type = "inactivity", ticks = 30 * 60, compare_type = "or" }
  return conditions
end

local function add_stop(schedule, index, stop, wait_conditions)
  local rail = stop.connected_rail
  if rail then
    schedule.add_record({
      rail = rail,
      rail_direction = stop.connected_rail_direction,
      temporary = true,
      wait_conditions = {},
      index = { schedule_index = index },
    })
    index = index + 1
  end
  schedule.add_record({
    station = stop.backer_name,
    temporary = true,
    wait_conditions = wait_conditions,
    index = { schedule_index = index },
  })
  return index + 1
end

--- Inaktivitäts-Bedingung anhängen (Sekunden ohne Änderung an der Ladung; 0/nil = keine).
--- `mode` „or“ = Fracht ODER Inaktivität, sonst „and“ = Fracht UND Inaktivität. Inaktivität statt
--- reiner Zeit (Wunsch Marcel): solange Greifarme/Pumpen noch arbeiten, läuft die Zeit nicht.
local function with_timeout(conditions, seconds, mode)
  if seconds and seconds > 0 then
    conditions[#conditions + 1] = { type = "inactivity", ticks = seconds * 60, compare_type = mode == "or" and "or" or "and" }
  end
  return conditions
end

--- Wartebedingungen beim Anbieter: jede Ware der Ladeliste mindestens in bestellter Menge
--- (Items: item_count, Flüssigkeiten: fluid_count), alle mit UND verknüpft.
local function loading_conditions(manifest)
  local conditions = {}
  for key, amount in pairs(manifest) do
    local kind, name, quality = Util.split_key(key)
    local signal = kind == "fluid" and { type = "fluid", name = name } or { type = "item", name = name, quality = quality }
    conditions[#conditions + 1] = {
      type = kind == "fluid" and "fluid_count" or "item_count",
      condition = { first_signal = signal, comparator = "≥", constant = amount },
    }
  end
  return conditions
end

--- (Optional Tankstelle →) Anbieter → Abnehmer hinter dem aktuellen Halt einfügen und
--- losschicken. `timeouts` = { load = s, unload = s, mode = "and" | "or" } (0 = keine Zeit).
--- Liefert true bei Erfolg.
function Schedule.send(train, provider_stop, requester_stop, manifest, fuel_stop, timeouts)
  local schedule = train.get_schedule()
  if not schedule then return false end
  local first = (schedule.current or 0) + 1
  local index = first
  if fuel_stop then index = add_stop(schedule, index, fuel_stop, FUEL_WAIT) end
  timeouts = timeouts or {}
  index = add_stop(schedule, index, provider_stop, with_timeout(loading_conditions(manifest), timeouts.load, timeouts.mode))
  add_stop(schedule, index, requester_stop, with_timeout({ { type = "empty" } }, timeouts.unload, timeouts.mode))
  schedule.go_to_station(first)
  return true
end

--- Dienstfahrt: (Tankstelle →) (Cleanup-Route →) danach weiter mit dem eigenen Fahrplan
--- (in der Regel zurück ins Depot). `cleanup_route` = Liste { stop, wares } aus cleanup-route.lua.
--- Liefert true bei Erfolg.
function Schedule.send_service(train, fuel_stop, cleanup_route)
  local schedule = train.get_schedule()
  if not schedule or not (fuel_stop or cleanup_route) then return false end
  local first = (schedule.current or 0) + 1
  local index = first
  if fuel_stop then index = add_stop(schedule, index, fuel_stop, FUEL_WAIT) end
  for _, leg in ipairs(cleanup_route or {}) do index = add_stop(schedule, index, leg.stop, cleanup_conditions(leg.wares)) end
  schedule.go_to_station(first)
  return true
end

--- Nur einen Schienen-Wegpunkt vor `stop` setzen; danach fährt der Zug mit seinem Fahrplan
--- weiter – bei gleichem Stationsnamen also genau zu dieser Haltestelle.
function Schedule.send_waypoint(train, stop)
  local schedule = train.get_schedule()
  local rail = stop.connected_rail
  if not (schedule and rail) then return false end
  local index = (schedule.current or 0) + 1
  schedule.add_record({
    rail = rail,
    rail_direction = stop.connected_rail_direction,
    temporary = true,
    wait_conditions = {},
    index = { schedule_index = index },
  })
  schedule.go_to_station(index)
  return true
end

--- Alle von UTL angelegten (temporären, nicht von Interrupts stammenden) Halte entfernen.
function Schedule.clear(train)
  if not train.valid then return end
  local schedule = train.get_schedule()
  if not schedule then return end
  local records = schedule.get_records()
  if not records then return end
  for i = #records, 1, -1 do
    local record = records[i]
    if record.temporary and not record.created_by_interrupt then
      schedule.remove_record({ schedule_index = i })
    end
  end
end

return Schedule
