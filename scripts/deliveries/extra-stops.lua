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

-- Gleistypen für Wegpunkte per Position
local RAIL_TYPES = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "legacy-straight-rail",
  "legacy-curved-rail", "elevated-straight-rail", "elevated-curved-rail-a", "elevated-curved-rail-b",
  "elevated-half-diagonal-rail" }

-- Höchstens so viele Schritte je Pfadsuche (wie bei UTLs Lieferungen, dispatcher/reach.lua)
local PATH_STEPS = 20000

--- Fahrtrichtung auf `rail`, in der `train` das Gleis erreicht: EINE Pfadsuche mit beiden Richtungen als
--- Ziel (liefert Richtung und Erreichbarkeit zugleich). Rückgabe: Richtung, erreichbar (true/false/nil).
local function direction_for(train, rail)
  if not (train and train.valid) then return defines.rail_direction.front, nil end
  local front, back = defines.rail_direction.front, defines.rail_direction.back
  local result = game.train_manager.request_train_path({ train = train, steps_limit = PATH_STEPS,
    goals = { { rail = rail, direction = front }, { rail = rail, direction = back } } })
  if not result.found_path then return front, false end
  return result.goal_index == 2 and back or front, true
end

--- Ziel aus der Anfrage: `stop` = Haltestelle (LuaEntity oder unit_number) bzw. `station` = UTL-
--- Station (unit), `rail` (+ `rail_direction`) oder `position` = { x, y } (+ `surface`, Standard: die des
--- Zugs) – UTL sucht dann das Gleis dort. Ohne `rail_direction` nimmt UTL die Richtung, in der `train`
--- das Gleis erreicht. Alles optional: Haltestellen bekommen ihren Wegpunkt davor von UTL selbst.
function ExtraStops.target_of(spec, train)
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
  local rail = spec.rail
  if not rail and spec.position then
    local front = train and train.valid and train.front_stock
    local surface = spec.surface and game.get_surface(spec.surface) or (front and front.surface)
    local p = spec.position
    local x, y = p.x or p[1], p.y or p[2]
    if surface and x and y then
      local found = surface.find_entities_filtered({ type = RAIL_TYPES, position = { x, y }, radius = 2 })
      table.sort(found, function(a, b)
        local da = (a.position.x - x) ^ 2 + (a.position.y - y) ^ 2
        local db = (b.position.x - x) ^ 2 + (b.position.y - y) ^ 2
        return da < db
      end)
      rail = found[1]
    end
  end
  if rail and rail.valid then
    if spec.rail_direction then return { rail = rail, rail_direction = spec.rail_direction } end
    local dir, reached = direction_for(train, rail)
    -- `reached`: Ergebnis der Pfadsuche vom Zug aus – ExtraStops.reachable braucht dann keine zweite
    return { rail = rail, rail_direction = dir, reached = reached }
  end
  return nil
end

--- Ziel als Pfad-Ziel bzw. Start (Haltestelle oder Gleis + Richtung).
local function goal_of(target)
  if target.object_name == "LuaEntity" then return { train_stop = target } end
  return { rail = target.rail, direction = target.rail_direction }
end

--- Erreicht `train` das Ziel `target`? Ohne `from`: vom Zug aus; mit `from` (vorheriges Ziel): von dort, in
--- beide Richtungen (der Zug darf an einem Halt wenden) – so fallen getrennte Gleisnetze sicher auf, ohne
--- dass gültige Fahrten mit Wenden abgelehnt werden.
function ExtraStops.reachable(train, from, target)
  if not (train and train.valid) then return false end
  -- Gleis-Ziel (Tabelle, keine Haltestelle): schon beim Bestimmen der Richtung gesucht
  if not from and target.object_name ~= "LuaEntity" and target.reached ~= nil then return target.reached end
  local request = { train = train, goals = { goal_of(target) }, steps_limit = PATH_STEPS }
  if from then
    local rail = from.object_name == "LuaEntity" and from.connected_rail or from.rail
    if not (rail and rail.valid) then return true end -- ohne Gleis keine Aussage: nicht ablehnen
    request.starts = {
      { rail = rail, direction = defines.rail_direction.front, is_front = true },
      { rail = rail, direction = defines.rail_direction.back, is_front = true },
    }
  end
  return game.train_manager.request_train_path(request).found_path == true
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
  local train = delivery.train
  local target = ExtraStops.target_of(spec, train)
  if not target then return false, "bad-target" end
  if not spec.skip_path_check and not ExtraStops.reachable(train, nil, target) then return false, "unreachable" end
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
