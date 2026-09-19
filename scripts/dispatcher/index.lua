--- Anbieter-Index pro Ware und Menge der Abnehmer – inkrementell gepflegt.
--- Nur Stationen, deren Angebot/Bedarf sich geändert hat (stations.dirty), werden neu
--- eingetragen. LTN baut so etwas jeden Zyklus komplett neu; das sparen wir uns.
--- Entfernte Stationen fallen beim nächsten Zugriff heraus (lazy).
local Index = {}

local function unindex(dispatch, unit)
  local keys = dispatch.provider_keys[unit]
  if not keys then return end
  local providers = dispatch.providers
  for key in pairs(keys) do
    local set = providers[key]
    if set then
      set[unit] = nil
      if next(set) == nil then providers[key] = nil end
    end
  end
  dispatch.provider_keys[unit] = nil
end

local function reindex(dispatch, station)
  local unit = station.unit
  unindex(dispatch, unit)
  if station.provide_count > 0 then
    local keys = {}
    local providers = dispatch.providers
    for key in pairs(station.provide) do
      keys[key] = true
      local set = providers[key]
      if not set then
        set = {}
        providers[key] = set
      end
      set[unit] = true
    end
    dispatch.provider_keys[unit] = keys
  end
  dispatch.requesters[unit] = station.request_count > 0 or nil
  -- Wartezeiten für Waren, die nicht mehr gebraucht werden, verwerfen (Warnung „kein Zug“).
  local waiting = dispatch.waiting[unit]
  if waiting then
    for key in pairs(waiting) do
      if not station.request[key] then waiting[key] = nil end
    end
    if next(waiting) == nil then dispatch.waiting[unit] = nil end
  end
end

--- Geänderte Stationen übernehmen.
function Index.update()
  local stations = storage.stations
  local dirty = stations.dirty
  if next(dirty) == nil then return end
  local dispatch = storage.dispatch
  local by_unit = stations.by_unit
  for unit in pairs(dirty) do
    local station = by_unit[unit]
    if station then
      reindex(dispatch, station)
    else
      unindex(dispatch, unit)
      dispatch.requesters[unit] = nil
      dispatch.waiting[unit] = nil
    end
    dirty[unit] = nil
  end
end

--- Station ist weg: sofort austragen.
function Index.remove(unit)
  local dispatch = storage.dispatch
  unindex(dispatch, unit)
  dispatch.requesters[unit] = nil
  dispatch.waiting[unit] = nil
  if dispatch.cursor == unit then dispatch.cursor = nil end
end

return Index
