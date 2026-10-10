--- Welche temporären Fahrplan-Einträge hat UTL selbst geschrieben? Factorio kann an einem Eintrag nicht
--- vermerken, von wem er stammt. Ohne diese Liste löschte Schedule.clear auch temporäre Einträge, die ein
--- anderer Mod (Add-on) selbst gesetzt hat. storage.trains.own_records[train_id] = { [Schlüssel] = Anzahl }.
--- Schlüssel: Stationsname bzw. „rail|x,y|Richtung“.
local OwnRecords = {}

local function key_of(record)
  if record.station then return "station|" .. record.station end
  local rail = record.rail
  if rail and rail.valid then
    return "rail|" .. rail.position.x .. "," .. rail.position.y .. "|" .. tostring(record.rail_direction)
  end
  return nil
end

local function list()
  local trains = storage.trains
  trains.own_records = trains.own_records or {}
  return trains.own_records
end

--- Temporären Eintrag schreiben und als UTL-Eintrag merken. `record` wie bei LuaSchedule.add_record.
function OwnRecords.add(schedule, record)
  local owner = schedule.owner
  if owner and owner.valid and owner.object_name == "LuaTrain" then OwnRecords.prune(owner) end
  schedule.add_record(record)
  local key = key_of(record)
  if not (owner and owner.valid and owner.object_name == "LuaTrain" and key) then return end
  local own = list()[owner.id] or {}
  own[key] = (own[key] or 0) + 1
  list()[owner.id] = own
end

--- Ist dieser Eintrag (noch) einer von UTL? Zählt ihn dabei ab.
local function take(own, record)
  local key = key_of(record)
  if not key then return false end
  local n = own[key]
  if not n or n <= 0 then return false end
  own[key] = n > 1 and n - 1 or nil
  return true
end

--- Alle temporären UTL-Einträge entfernen; Einträge anderer Mods und von Unterbrechungen bleiben.
--- Züge ohne Liste (Lieferung aus einem Spielstand vor 0.0.16) räumen wie früher alle temporären ab.
function OwnRecords.clear(train)
  if not train.valid then return end
  local schedule = train.get_schedule()
  local records = schedule and schedule.get_records()
  if not records then return end
  local own = list()[train.id]
  -- ohne Liste: nur bei einer Lieferung/Dienstfahrt aus einem älteren Spielstand alles abräumen –
  -- einen Zug, auf dem UTL nie etwas eingetragen hat, rührt es nicht an
  if own == nil and not (storage.deliveries.by_train[train.id] or storage.trains.service[train.id]) then own = {} end
  for i = #records, 1, -1 do
    local record = records[i]
    if record.temporary and not record.created_by_interrupt and (own == nil or take(own, record)) then
      schedule.remove_record({ schedule_index = i })
    end
  end
  list()[train.id] = {} -- leer statt nil: ab jetzt nur noch eigene Einträge löschen
end

--- Liste auf die Einträge kürzen, die noch im Fahrplan stehen (abgefahrene verschwinden von selbst).
function OwnRecords.prune(train)
  local own = train.valid and list()[train.id]
  if not own then return end
  local present = {}
  for _, record in pairs(train.get_schedule().get_records() or {}) do
    local key = record.temporary and key_of(record)
    if key then present[key] = (present[key] or 0) + 1 end
  end
  for key, n in pairs(own) do
    local p = present[key] or 0
    own[key] = p > 0 and math.min(n, p) or nil
  end
end

return OwnRecords
