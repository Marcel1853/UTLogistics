--- Summen je Netz für die Netz-Kombinatoren: Angebot, Bedarf und Lagerbestand aller Stationen
--- eines Netzes, getrennt nach Ort (Oberfläche + Team).
---
--- Inkrementell (Regel 5): Ändert sich Angebot oder Bedarf einer Station, zieht `sync` ihren alten
--- Beitrag ab und zählt den neuen dazu – ausgelöst vom Dispatcher-Index (dort landen alle
--- geänderten Stationen), bei Netzwechsel und beim Abriss. Geführt wird das nur, solange es
--- mindestens einen Netz-Kombinator gibt; ohne Kombinator kostet es nichts.
---
--- storage.readout_agg = {
---   active  = true/false,
---   nets    = { ["<ort>|<netz>"] = { provide = {[key]=n}, request = {[key]=n}, stock = {[key]=n} } },
---   counted = { [station] = { net, provide, request, stock } },  -- zuletzt gezählter Beitrag
--- }
local Networks = require("scripts.stations.networks")

local Aggregate = {}

local function data()
  local agg = storage.readout_agg
  if not agg then
    agg = { active = false, nets = {}, counted = {} }
    storage.readout_agg = agg
  end
  return agg
end

local EMPTY_MAP = {}

local function add_into(target, source, sign)
  for key, value in pairs(source) do
    local n = (target[key] or 0) + sign * value
    target[key] = n ~= 0 and n or nil
  end
end

--- Schlüssel „<ort>|<netz>“ einer Station, nil ohne Haltestelle.
local function net_key(station)
  local stop = station.stop
  if not (stop and stop.valid) then return nil end
  return Networks.place_of(stop) .. "|" .. (station.config.network or "default")
end

--- Beitrag einer Station neu zählen (`station` = nil: Station ist weg).
function Aggregate.sync(unit, station)
  local agg = data()
  if not agg.active then return end
  local old = agg.counted[unit]
  if old then
    local net = agg.nets[old.net]
    if net then
      add_into(net.provide, old.provide, -1)
      add_into(net.request, old.request, -1)
      add_into(net.stock, old.stock, -1)
    end
    agg.counted[unit] = nil
  end
  local key = station and net_key(station)
  if not key then return end
  -- Verweise statt Kopien: UTL ersetzt provide/request/stock bei jeder Änderung durch neue Tabellen
  -- (reader.lua, storage-reader.lua) und ändert sie nie an Ort und Stelle – der alte Beitrag bleibt
  -- also bis zum Abziehen unverändert.
  local entry = { net = key, provide = station.provide or EMPTY_MAP, request = station.request or EMPTY_MAP,
    stock = station.stock or EMPTY_MAP }
  local net = agg.nets[key]
  if not net then
    net = { provide = {}, request = {}, stock = {} }
    agg.nets[key] = net
  end
  add_into(net.provide, entry.provide, 1)
  add_into(net.request, entry.request, 1)
  add_into(net.stock, entry.stock, 1)
  agg.counted[unit] = entry
end

--- Erster Netz-Kombinator gebaut (oder Spielstand geladen): alle Stationen einmal zählen.
function Aggregate.activate()
  local agg = data()
  if agg.active then return end
  agg.active, agg.nets, agg.counted = true, {}, {}
  for unit, station in pairs(storage.stations.by_unit) do Aggregate.sync(unit, station) end
end

--- Letzter Netz-Kombinator weg: Summen verwerfen.
function Aggregate.deactivate()
  local agg = data()
  agg.active, agg.nets, agg.counted = false, {}, {}
end

--- Neu aufbauen (Sicherheitsnetz nach Mod-Updates).
function Aggregate.rebuild()
  local agg = data()
  if not agg.active then return end
  agg.active = false
  Aggregate.activate()
end

local EMPTY = { provide = {}, request = {}, stock = {} }

--- Summen eines Netzes (nie nil).
function Aggregate.net(place, name)
  return data().nets[place .. "|" .. name] or EMPTY
end

return Aggregate
