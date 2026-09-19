--- Einstellungen kopieren wie in Vanilla: Shift + Rechtsklick auf eine UTL-Station,
--- Shift + Linksklick auf eine andere. Übernimmt Rolle, Netzwerk, alle Werte und die
--- Anforderungs-Slots. Funktioniert zwischen UTL-Haltestellen und zwischen Combinators.
local Events = require("scripts.core.events")
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Roles = require("scripts.stations.roles")
local Fields = require("scripts.stations.fields")
local util = require("util")

local Paste = {}

--- Einstellungen (Kopie von `config`) auf `station` anwenden – für Shift-Klick und Blaupausen.
function Paste.apply(station, config)
  local cfg = util.table.deepcopy(config)
  Fields.fill(cfg)
  Roles.derive(cfg)
  station.config = cfg
  Reader.read(station)
  Registry.config_changed(station)
end

--- Einstellungen von Station `source` auf Station `destination` übertragen.
function Paste.copy(source, destination)
  if source == destination then return false end
  Paste.apply(destination, source.config)
  return true
end

local function station_of(entity)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  return Registry.get(entity.unit_number)
end

-- Kommt nur bei Spieler-Aktionen (headless ohne Spieler nicht auslösbar).
Events.on(defines.events.on_entity_settings_pasted, function(event)
  local source = station_of(event.source)
  local destination = station_of(event.destination)
  if source and destination then Paste.copy(source, destination) end
end)

return Paste
