--- Verdrahtet den Stationsbereich mit Events und Heartbeat.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Paste = require("scripts.stations.settings-paste") -- vor dem GUI-Handler anmelden
local Blueprint = require("scripts.stations.blueprint")
local Output = require("scripts.stations.output")
local Settings = require("scripts.stations.settings-combinator")
local Unlocks = require("scripts.core.unlocks")
local Config = require("scripts.core.config")

-- UTL-Haltestelle ist ebenfalls vom Typ train-stop, der Typ-Filter deckt sie mit ab.
local build_filter = {
  { filter = "name", name = C.station_combinator },
  { filter = "type", type = "train-stop" },
  { filter = "name", name = C.station_settings },
}

--- Einstellungs-Kombinator hat Werte aus einer Blaupause übernommen: Station neu lesen.
local function settings_taken(station)
  Reader.read(station)
  Registry.config_changed(station)
end

-- Bauen (auch aus Blaupausen): Einstellungen aus den Tags übernehmen. Danach gewinnt der
-- Einstellungs-Kombinator (Blaupausen-Parameter, scripts/stations/settings-combinator.lua).
local function on_built(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == C.station_settings then
    -- einzeln gebaut (Haltestelle stand schon): der Station darunter zuordnen
    local station = Settings.adopt(entity)
    if station then settings_taken(station) end
    return
  end
  local station = Registry.on_built(entity)
  if event.tags then Blueprint.apply_tags(station, event.tags) end
  if station then
    Output.refresh(station)
    if Settings.refresh(station) then settings_taken(station) end
  end
end

Events.on(defines.events.on_built_entity, on_built, build_filter)
Events.on(defines.events.on_robot_built_entity, on_built, build_filter)
Events.on(defines.events.script_raised_built, on_built, build_filter)
Events.on(defines.events.script_raised_revive, on_built, build_filter)

-- Blaupause platziert (Geister): Einstellungs-Kombinator aus älteren Blaupausen neben die Mitte der
-- Haltestelle rücken – lag er darauf und wurde zuerst gebaut, verschwand manchmal die Haltestelle.
Events.on(defines.events.on_built_entity, function(event)
  local entity = event.entity
  if entity and entity.valid and entity.type == "entity-ghost" then Settings.move_ghost(entity) end
end, { { filter = "ghost_name", name = C.station_settings }, { filter = "ghost_type", type = "train-stop" } })
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
Heartbeat.add_task("station-output", 1, Output.step)

-- Auftrags-Ausgabe: anlegen, wenn eine Station eine Haltestelle bekommt, und mit ihr verschwinden.
Registry.on_config_changed(Output.refresh)
Registry.on_lost(Output.destroy)
-- Einstellungs-Kombinator: Änderungen hineinschreiben (oder Werte aus einer Blaupause übernehmen)
Registry.on_config_changed(function(station)
  if Settings.refresh(station) then settings_taken(station) end
end)
Registry.on_lost(Settings.destroy)

--- Ausgaben neu anlegen bzw. entfernen – für eine Force (Forschung) oder alle (Einstellung).
local function refresh_outputs(force)
  for _, station in pairs(storage.stations.by_unit) do
    if not force or Unlocks.force_of(station) == force then Output.refresh(station) end
  end
end

-- Forschung „Ladesteuerung“ fertig oder zurückgenommen: Ausgaben dieser Force anpassen.
local function on_research(event)
  local tech = event.research
  if tech and tech.name == Unlocks.LOADING_TECH then refresh_outputs(tech.force) end
end
Events.on(defines.events.on_research_finished, on_research)
Events.on(defines.events.on_research_reversed, on_research)

-- Map-Einstellung „UTL-Funktionen brauchen Forschung“ umgestellt (Menü oder UTL-Manager).
Config.listen(function(name)
  if name == "utl-research-required" or name == "utl-station-output" then refresh_outputs(nil) end
end)

-- Nach Mod-Updates fehlende Stationswerte ergänzen (neue Felder bekommen ihren Standard).
local Fields = require("scripts.stations.fields")
Events.on_configuration_changed(function()
  for _, station in pairs(storage.stations.by_unit) do
    if station.config then
      Fields.fill(station.config)
      Output.refresh(station) -- bestehende Spielstände bekommen ihre Ausgabe
      Settings.refresh(station) -- … und ihren Einstellungs-Kombinator
    end
  end
end)
