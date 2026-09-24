--- Vorgemerkte Fahrten zu Haltestellen: storage.trains.pending[train_id] = { [Haltestelle] = Tick }.
--- UTL schickt Züge per Schienen-Wegpunkt direkt vor die gemeinte Haltestelle (sonst hielten sie
--- bei gleichnamigen woanders). Für das Spiel fährt ein solcher Zug „zu einem Gleis“, deshalb
--- zählt ihn das Zuglimit der Haltestelle nicht mit – UTL zählt ihn hier selbst.
local Pending = {}

local function map()
  local trains = storage.trains
  trains.pending = trains.pending or {}
  return trains.pending
end

--- Wie viele Züge sind zu welcher Haltestelle unterwegs? { [unit] = Anzahl }
function Pending.counts()
  local counts = {}
  for _, units in pairs(map()) do
    for unit in pairs(units) do counts[unit] = (counts[unit] or 0) + 1 end
  end
  return counts
end

--- Fahrt(en) vormerken. `stops` darf Lücken enthalten (`pairs`, nicht `ipairs`).
function Pending.reserve(train_id, stops)
  local units = map()[train_id] or {}
  for _, stop in pairs(stops) do
    if stop and stop.valid then units[stop.unit_number] = game.tick end
  end
  map()[train_id] = next(units) and units or nil
end

--- Vormerkung lösen: eine Haltestelle (angekommen) oder alle (Depot, Abbruch, Handbetrieb).
function Pending.release(train_id, unit)
  local units = map()[train_id]
  if not units then return end
  if unit then
    units[unit] = nil
    if next(units) == nil then map()[train_id] = nil end
  else
    map()[train_id] = nil
  end
end

--- Sicherheitsnetz: Vormerkungen wegräumen, deren Zug es nicht mehr gibt oder die nie ankamen
--- (Ziel abgerissen, Weg weg, Zug hält woanders). Ohne das bliebe eine Haltestelle für immer
--- belegt. Läuft selten als Heartbeat-Aufgabe.
function Pending.sweep(max_age)
  local now = game.tick
  for train_id, units in pairs(map()) do
    local train = game.train_manager.get_train_by_id(train_id)
    if not (train and train.valid) then
      map()[train_id] = nil
    else
      for unit, tick in pairs(units) do
        if now - tick > max_age then units[unit] = nil end
      end
      if next(units) == nil then map()[train_id] = nil end
    end
  end
end

return Pending
