--- Liest die Eingangssignale der Stationen reihum, mit festem Budget pro Heartbeat.
--- Netto-Menge je Ware = Eingang − Anforderungen aus dem Fenster.
--- Positiv über Angebots-Schwelle → Angebot, negativ über Bedarfs-Schwelle → Bedarf.
--- Im Normalfall (nichts hat sich geändert) werden keine neuen Tabellen angelegt.
local Util = require("scripts.lib.util")
local Input = require("scripts.stations.input")
local Registry = require("scripts.stations.registry")

local Reader = {}

local signal_key = Util.signal_key
local stack_size = Util.stack_size

-- Wiederverwendete Arbeitstabelle [key] = Netto-Menge (nur Lua-Zustand, kein storage).
local net = {}

local function collect(signals, cfg)
  for key in pairs(net) do net[key] = nil end
  if signals then
    for i = 1, #signals do
      local s = signals[i]
      local key = signal_key(s.signal)
      if key then net[key] = (net[key] or 0) + s.count end
    end
  end
  local requests = cfg.request_map
  if requests then
    for key, count in pairs(requests) do net[key] = (net[key] or 0) - count end
  end
end

--- Schwelle einer Ware; eine Stack-Schwelle > 0 gilt, wenn sie höher ist.
local function threshold(base, stacks, key)
  if stacks > 0 then
    local size = stack_size(key)
    if size and stacks * size > base then return stacks * size end
  end
  return base
end
Reader.threshold = threshold

--- Liefert true, wenn `net` exakt dem bisherigen Angebot/Bedarf entspricht.
local function unchanged(station, cfg)
  local roles = cfg.roles
  local provide, request = station.provide, station.request
  local matched = 0
  for key, n in pairs(net) do
    if n > 0 then
      if roles.provider and n >= threshold(cfg.provide_threshold, cfg.provide_stack_threshold, key) then
        if provide[key] ~= n then return false end
        matched = matched + 1
      end
    elseif n < 0 then
      if roles.requester and -n >= threshold(cfg.request_threshold, cfg.request_stack_threshold, key) then
        if request[key] ~= -n then return false end
        matched = matched + 1
      end
    end
  end
  return matched == station.provide_count + station.request_count
end

local function rebuild(station, cfg)
  local roles = cfg.roles
  local provide, request = {}, {}
  local p_count, r_count = 0, 0
  for key, n in pairs(net) do
    if n > 0 then
      if roles.provider and n >= threshold(cfg.provide_threshold, cfg.provide_stack_threshold, key) then
        provide[key] = n
        p_count = p_count + 1
      end
    elseif n < 0 then
      if roles.requester and -n >= threshold(cfg.request_threshold, cfg.request_stack_threshold, key) then
        request[key] = -n
        r_count = r_count + 1
      end
    end
  end
  station.provide, station.provide_count = provide, p_count
  station.request, station.request_count = request, r_count
  station.version = station.version + 1
  storage.stations.dirty[station.unit] = true
end

--- Liest eine Station sofort (z. B. nach einer Änderung im Fenster).
function Reader.read(station)
  if not station.entity.valid then return end
  local cfg = station.config
  collect(Input.read(station), cfg)
  if not unchanged(station, cfg) then rebuild(station, cfg) end
  station.last_read = game.tick
end

--- Heartbeat-Aufgabe: bis zu `station_batch_size` Stationen lesen.
function Reader.step()
  local stations = storage.stations
  local by_unit = stations.by_unit
  local unit = stations.cursor
  if unit and not by_unit[unit] then unit = nil end
  local station
  for _ = 1, storage.cfg.station_batch_size do
    unit, station = next(by_unit, unit)
    if not unit then break end -- Runde fertig, nächster Heartbeat beginnt von vorn
    if station.kind == "combinator" then Registry.relink(station) end -- Kabel zur Haltestelle geändert?
    Reader.read(station)
  end
  stations.cursor = unit
end

return Reader
