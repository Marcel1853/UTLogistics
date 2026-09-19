--- Verwaltet Stationen. Zwei Bauarten, gleiche Logik dahinter:
---   kind = "stop":       UTL-Haltestelle, liest ihr eigenes Schaltnetz.
---   kind = "combinator": UTL-Combinator, per Kabel (Ausgang) mit einer normalen Haltestelle verbunden.
--- Schlüssel ist die unit_number der Signalquelle (`entity`).
--- Abriss wird einheitlich über on_object_destroyed erkannt (Spieler, Roboter,
--- Script, Oberfläche gelöscht …).
local C = require("scripts.core.constants")
local Heartbeat = require("scripts.core.heartbeat")
local Util = require("scripts.lib.util")
local Log = require("scripts.lib.log")
local Roles = require("scripts.stations.roles")
local Fields = require("scripts.stations.fields")
local State = require("scripts.core.state")

local Registry = {}

-- Andere Bereiche (Lieferungen, Depots) hängen sich hier ein, ohne dass die Registry sie kennt.
local lost_listeners = {}    -- fn(station): Station entfernt oder ohne Haltestelle
local changed_listeners = {} -- fn(station): Einstellungen im Fenster/per API geändert

function Registry.on_lost(fn) lost_listeners[#lost_listeners + 1] = fn end
function Registry.on_config_changed(fn) changed_listeners[#changed_listeners + 1] = fn end

local function notify(listeners, station)
  for i = 1, #listeners do listeners[i](station) end
end

function Registry.config_changed(station)
  notify(changed_listeners, station)
end

local function new_config()
  local cfg = {
    mode = "station",
    provide = true,
    request = true,
    network = "default",
  }
  Fields.fill(cfg)
  Roles.derive(cfg)
  return cfg
end

local function link(station, stop)
  station.stop = stop
  station.stop_unit = stop.unit_number
  storage.stations.by_stop[stop.unit_number] = station.unit
  script.register_on_object_destroyed(stop)
end

local function insert(entity, kind)
  local stations = storage.stations
  local unit = entity.unit_number
  local station = {
    unit = unit,
    kind = kind,
    entity = entity, -- Signalquelle
    stop = nil,
    stop_unit = nil,
    config = new_config(),
    provide = {}, provide_count = 0, -- [key] = Menge über Schwelle
    request = {}, request_count = 0, -- [key] = Bedarf über Schwelle
    version = 0,
    last_read = 0,
  }
  stations.by_unit[unit] = station
  stations.count = stations.count + 1
  script.register_on_object_destroyed(entity)
  Log.debug("Station angelegt: " .. kind .. " " .. unit)
  return station
end

-- Der Combinator gehört zu der normalen Haltestelle, die per Kabel (rot oder grün) an seinem
-- AUSGANG hängt. Der Ausgang, damit Signale der Haltestelle nicht in den Bestand (Eingang) geraten.
local OUTPUTS = { defines.wire_connector_id.combinator_output_red, defines.wire_connector_id.combinator_output_green }

--- Normale Haltestelle am Ausgang des Combinators (erste gefundene) oder nil.
local function wired_stop(combinator)
  for _, id in ipairs(OUTPUTS) do
    local connector = combinator.get_wire_connector(id, false)
    if connector then
      for _, connection in pairs(connector.connections) do
        local owner = connection.target.owner
        if owner and owner.valid and owner.type == "train-stop" and owner.name ~= C.train_stop then return owner end
      end
    end
  end
  return nil
end

function Registry.get(unit)
  return storage.stations.by_unit[unit]
end

--- Station zu einer angeklickten Entity (Combinator oder UTL-Haltestelle).
function Registry.get_or_add(entity)
  return Registry.get(entity.unit_number) or Registry.on_built(entity)
end

function Registry.add_utl_stop(stop)
  local existing = Registry.get(stop.unit_number)
  if existing then return existing end
  local station = insert(stop, "stop")
  link(station, stop)
  Heartbeat.update_registration()
  return station
end

function Registry.add_combinator(entity)
  local existing = Registry.get(entity.unit_number)
  if existing then return existing end
  local station = insert(entity, "combinator")
  Registry.relink(station)
  Heartbeat.update_registration()
  return station
end

--- Zuordnung Combinator ↔ Haltestelle nach dem Kabel am Ausgang aktualisieren (beim Bau und beim
--- regelmäßigen Lesen – Kabel lösen kein Event aus). Eine Haltestelle gehört höchstens einer Station.
function Registry.relink(station)
  if station.kind ~= "combinator" or not station.entity.valid then return end
  local stop = wired_stop(station.entity)
  local by_stop = storage.stations.by_stop
  if stop then
    if stop.unit_number == station.stop_unit then return end
    local owner = by_stop[stop.unit_number]
    if owner and owner ~= station.unit and storage.stations.by_unit[owner] then stop = nil end -- schon vergeben
  end
  if not stop and not station.stop_unit then return end
  if station.stop_unit then
    notify(lost_listeners, station)
    by_stop[station.stop_unit] = nil
    station.stop, station.stop_unit = nil, nil
  end
  if stop then
    link(station, stop)
    notify(changed_listeners, station) -- z. B. Depot: dort wartende Züge erfassen
  end
end

--- Liefert die neue Station (falls eine entstanden ist).
function Registry.on_built(entity)
  State.ensure() -- Bau-Events können vor UTLs on_init kommen (Szenario-Script)
  if not (entity and entity.valid) then return nil end
  local name = entity.name
  if name == C.train_stop then
    return Registry.add_utl_stop(entity)
  elseif name == C.station_combinator then
    return Registry.add_combinator(entity)
  end
  return nil
end

--- Ein registriertes Objekt ist weg. `unit` ist die unit_number (useful_id).
function Registry.on_destroyed(unit)
  local stations = storage.stations
  local station = stations.by_unit[unit]
  if station then
    notify(lost_listeners, station)
    if station.stop_unit then stations.by_stop[station.stop_unit] = nil end
    stations.by_unit[unit] = nil
    stations.dirty[unit] = nil
    if stations.cursor == unit then stations.cursor = nil end
    stations.count = stations.count - 1
    Log.debug("Station entfernt: " .. unit)
    Heartbeat.update_registration()
    return
  end

  -- Normale Haltestelle eines Combinators ist weg.
  local owner_unit = stations.by_stop[unit]
  if owner_unit then
    stations.by_stop[unit] = nil
    local owner = stations.by_unit[owner_unit]
    if owner then
      notify(lost_listeners, owner)
      owner.stop, owner.stop_unit = nil, nil
      Registry.relink(owner) -- vielleicht hängt noch eine andere Haltestelle am Kabel
    end
  end
end

return Registry
