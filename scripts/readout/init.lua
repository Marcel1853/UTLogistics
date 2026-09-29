--- Netz-Kombinator: Bau-/Abriss-Events, Blaupausen, Kopieren, Heartbeat-Aufgabe.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Registry = require("scripts.stations.registry")
local Index = require("scripts.dispatcher.index")
local Blueprint = require("scripts.stations.blueprint")
local Aggregate = require("scripts.readout.aggregate")
local Readouts = require("scripts.readout.readouts")
local Output = require("scripts.readout.output")

local TAG = "utl_readout"
local filter = { { filter = "name", name = C.network_combinator } }

-- Filter aller Handler eines Events werden zusammengeführt (events.lua) – deshalb Name prüfen.
local function on_built(event)
  local entity = event.entity or event.destination
  if not (entity and entity.valid and entity.name == C.network_combinator) then return end
  local tags = event.tags
  local entry = Readouts.add(entity, tags and tags[TAG])
  Output.write(entry)
end

Events.on(defines.events.on_built_entity, on_built, filter)
Events.on(defines.events.on_robot_built_entity, on_built, filter)
Events.on(defines.events.script_raised_built, on_built, filter)
Events.on(defines.events.script_raised_revive, on_built, filter)
Events.on(defines.events.on_entity_cloned, function(event)
  local destination = event.destination
  if not (destination and destination.valid and destination.name == C.network_combinator) then return end
  local source = event.source
  local original = source and source.valid and source.unit_number and Readouts.get(source.unit_number)
  local entry = Readouts.add(destination, original and original.config)
  Output.write(entry)
end, filter)

Events.on(defines.events.on_object_destroyed, function(event)
  if event.type == defines.target_type.entity and event.useful_id then Readouts.remove(event.useful_id) end
end)

-- Shift-Kopieren zwischen zwei Netz-Kombinatoren
Events.on(defines.events.on_entity_settings_pasted, function(event)
  local source, destination = event.source, event.destination
  if not (source.valid and destination.valid) then return end
  if source.name ~= C.network_combinator or destination.name ~= C.network_combinator then return end
  local from, to = Readouts.get(source.unit_number), Readouts.get(destination.unit_number)
  if from and to then
    Readouts.configure(to, from.config)
    Output.write(to)
  end
end)

-- Blaupausen: Einstellungen als Tag „utl_readout“ (scripts/stations/blueprint.lua)
Blueprint.register(C.network_combinator, TAG, function(entity)
  local entry = Readouts.get(entity.unit_number)
  return entry and entry.config
end)

-- Summen je Netz mitführen: geänderte Stationen (Dispatcher-Index), Netzwechsel, Abriss
Index.on_change(Aggregate.sync)
Registry.on_config_changed(function(station) Aggregate.sync(station.unit, station) end)
Registry.on_lost(function(station) Aggregate.sync(station.unit, nil) end)

Heartbeat.add_task("network-combinator", 1, Output.step)

-- Nach Mod-Updates: Summen neu aufbauen und alle Kombinatoren neu schreiben (Sicherheitsnetz)
Events.on_configuration_changed(function()
  Aggregate.rebuild()
  for _, entry in pairs(Readouts.data().by_unit) do entry.last = nil end
end)
