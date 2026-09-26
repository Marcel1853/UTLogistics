--- Verdrahtet den Dispatcher mit dem Heartbeat.
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Dispatch = require("scripts.dispatcher.dispatch")
local Depot = require("scripts.trains.depot")
local Reach = require("scripts.dispatcher.reach")

-- Gleisnetz geändert (Gleise/Signale gebaut oder abgerissen): Erreichbarkeits-Cache verwerfen.
local topology_filter = {}
for _, type in ipairs(Reach.TOPOLOGY_TYPES) do topology_filter[#topology_filter + 1] = { filter = "type", type = type } end
-- Die Filter aller Handler eines Events werden zusammengeführt (core/events.lua) – hier also auch
-- Haltestellen, Combinatoren, Wende-Greifarme. Nur echte Gleis-/Signaländerungen zählen.
local topology_types = {}
for _, type in ipairs(Reach.TOPOLOGY_TYPES) do topology_types[type] = true end
local function topology_changed(event)
  local entity = event.entity
  if not (entity and entity.valid) or topology_types[entity.type] then Reach.invalidate() end
end
for _, event in ipairs({
  defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built,
  defines.events.script_raised_revive, defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity,
  defines.events.on_entity_died, defines.events.script_raised_destroy,
}) do
  Events.on(event, topology_changed, topology_filter)
end

-- Alle 3 Heartbeats (Standard-Takt 10 → alle 30 Ticks).
Heartbeat.add_task("dispatch", 3, Dispatch.run)
-- Sammelwarnung „kein freier Zug“ je Netzwerk (alle 60 Heartbeats, Standard 10 s)
Heartbeat.add_task("starving-alerts", 60, Dispatch.starving_alerts)

-- Nach Mod-Update: alle Stationen neu indizieren und schon geparkte Depot-Züge erfassen.
Events.on_configuration_changed(function()
  for unit, station in pairs(storage.stations.by_unit) do
    storage.stations.dirty[unit] = true
    Depot.scan(station)
  end
end)
