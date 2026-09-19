--- Verdrahtet den Stationsbereich mit Events und Heartbeat.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Paste = require("scripts.stations.settings-paste") -- vor dem GUI-Handler anmelden
local Blueprint = require("scripts.stations.blueprint")

-- UTL-Haltestelle ist ebenfalls vom Typ train-stop, der Typ-Filter deckt sie mit ab.
local build_filter = {
  { filter = "name", name = C.station_combinator },
  { filter = "type", type = "train-stop" },
}

-- Bauen (auch aus Blaupausen): Einstellungen aus den Tags übernehmen.
local function on_built(event)
  local station = Registry.on_built(event.entity)
  if event.tags then Blueprint.apply_tags(station, event.tags) end
end

Events.on(defines.events.on_built_entity, on_built, build_filter)
Events.on(defines.events.on_robot_built_entity, on_built, build_filter)
Events.on(defines.events.script_raised_built, on_built, build_filter)
Events.on(defines.events.script_raised_revive, on_built, build_filter)
-- Geklont (Editor, Plattformen …): Einstellungen der Quelle übernehmen.
Events.on(defines.events.on_entity_cloned, function(event)
  local station = Registry.on_built(event.destination)
  local source = event.source
  local original = source and source.valid and source.unit_number and Registry.get(source.unit_number)
  if station and original then Paste.apply(station, original.config) end
end, build_filter)

Events.on(defines.events.on_object_destroyed, function(event)
  if event.type == defines.target_type.entity and event.useful_id then
    Registry.on_destroyed(event.useful_id)
  end
end)

Heartbeat.add_task("stations-read", 1, Reader.step)

-- Nach Mod-Updates fehlende Stationswerte ergänzen (neue Felder bekommen ihren Standard).
local Fields = require("scripts.stations.fields")
Events.on_configuration_changed(function()
  for _, station in pairs(storage.stations.by_unit) do
    if station.config then Fields.fill(station.config) end
  end
end)
