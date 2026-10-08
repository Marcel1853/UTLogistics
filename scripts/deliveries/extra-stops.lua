--- Zusätzliche Halte in einer laufenden Lieferung (Schnittstelle add_delivery_stop), z. B. ein
--- Umbau-Bahnhof vor dem Anbieter. Sie sind temporär wie alle UTL-Halte und verschwinden bei einem
--- Abbruch mit der Lieferung (Schedule.clear). Für den Ablauf der Lieferung zählen sie nicht:
--- on_arrive erkennt nur Anbieter und Abnehmer.
local Registry = require("scripts.stations.registry")
local Reservations = require("scripts.deliveries.reservations")
local Schedule = require("scripts.trains.schedule")

local ExtraStops = {}

-- Wo darf eingefügt werden, je nach Stand der Lieferung?
local ALLOWED = {
  before_provider = { to_provider = true },
  after_provider = { to_provider = true, loading = true },
  after_requester = { to_provider = true, loading = true, to_requester = true, unloading = true },
}

local function stop_name(unit)
  local station = unit and Registry.get(unit)
  local stop = station and station.stop
  return stop and stop.valid and stop.backer_name or nil
end

--- Ziel aus der Anfrage: `stop` = Haltestelle (LuaEntity oder unit_number) bzw. `station` = UTL-
--- Station (unit), sonst `rail` + `rail_direction`.
local function target_of(spec)
  if spec.station then
    local station = Registry.get(spec.station)
    local stop = station and station.stop
    return stop and stop.valid and stop or nil
  end
  local stop = spec.stop
  if type(stop) == "number" then stop = game.get_entity_by_unit_number(stop) end
  if stop then
    return stop.valid and stop.type == "train-stop" and stop or nil
  end
  if spec.rail and spec.rail.valid then
    return { rail = spec.rail, rail_direction = spec.rail_direction or defines.rail_direction.front }
  end
  return nil
end

--- Index des temporären Halts mit Namen `name` ab `from` (nil = nicht gefunden).
local function find(records, from, name)
  for i = from, #records do
    local record = records[i]
    if record.temporary and record.station == name then return i end
  end
  return nil
end

--- Halt einfügen. Liefert true oder false und einen Grund („unknown-delivery“, „bad-target“,
--- „bad-position“, „no-schedule“, „stop-not-found“).
function ExtraStops.add(delivery, spec)
  if not (delivery and delivery.train and delivery.train.valid) then return false, "unknown-delivery" end
  spec = spec or {}
  local where = spec.where or "after_provider"
  local allowed = ALLOWED[where]
  if not (allowed and allowed[delivery.state]) then return false, "bad-position" end
  local target = target_of(spec)
  if not target then return false, "bad-target" end
  local train = delivery.train
  local schedule = train.get_schedule()
  local records = schedule and schedule.get_records()
  if not records then return false, "no-schedule" end
  local current = math.max(schedule.current or 1, 1)

  local index
  if where == "after_requester" then
    local found = find(records, current, stop_name(delivery.requester))
    index = found and found + 1
  else
    local found = find(records, current, stop_name(Reservations.pickup_unit(delivery)))
    if found and where == "before_provider" then
      -- Schienen-Wegpunkt direkt vor dem Anbieter gehört zu ihm: davor einfügen
      local before = records[found - 1]
      if found - 1 >= current and before and before.temporary and before.rail then found = found - 1 end
      index = found
    else
      index = found and found + 1
    end
  end
  if not index then return false, "stop-not-found" end

  local heading = schedule.current == index
  Schedule.insert(schedule, index, target, spec.wait)
  if heading then schedule.go_to_station(index) end -- fuhr schon zum Anbieter: erst zum neuen Halt
  delivery.extra_stops = (delivery.extra_stops or 0) + 1
  return true
end

return ExtraStops
