--- Einstellungen in Blaupausen (auch Strg + C / Strg + V): Beim Erstellen einer Blaupause
--- bekommen UTL-Haltestellen und -Combinators ihre Einstellungen als Tag „utl“ mit; beim
--- Bauen aus der Blaupause (Spieler, Roboter, Script) werden sie wieder angewendet.
--- Vorbild: LTN Combinator Modernized (Tags an den Blaupausen-Entities).
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Registry = require("scripts.stations.registry")
local Paste = require("scripts.stations.settings-paste")

local Blueprint = {}

local TAG = "utl"
local NAMES = { [C.train_stop] = true, [C.station_combinator] = true }

--- Blaupause des Events: Item im Cursor/Bibliothek-Eintrag (2.x: stack oder record).
local function blueprint_of(event, player)
  local bp = event.stack or event.record
  if bp and (bp.object_name == "LuaRecord" or bp.valid_for_read) then return bp end
  bp = player.blueprint_to_setup
  if bp and bp.valid_for_read then return bp end
  bp = player.cursor_stack
  if bp and bp.valid_for_read and bp.is_blueprint then return bp end
  return nil
end

--- Echte Entity zu einem Blaupausen-Eintrag: über die Zuordnung, sonst über Name und
--- Position auf der Oberfläche (wie LTN Combinator Modernized).
local function real_entity(surface, mapping, index, entry)
  local entity = mapping and mapping[index]
  if entity and entity.valid then return entity end
  return surface and surface.find_entity(entry.name, entry.position)
end

--- Einstellungen aller UTL-Stationen als Tag in die Blaupause schreiben.
--- `mapping` = [Blaupausen-Index] = echte Entity (vom Event oder von create_blueprint).
function Blueprint.tag(bp, mapping, surface)
  local entities = bp.get_blueprint_entities()
  if not entities then return 0 end
  local tagged = 0
  for index, entry in pairs(entities) do
    if NAMES[entry.name] then
      local entity = real_entity(surface, mapping, index, entry)
      local station = entity and entity.unit_number and Registry.get(entity.unit_number)
      if station then
        bp.set_blueprint_entity_tag(index, TAG, station.config)
        tagged = tagged + 1
      end
    end
  end
  return tagged
end

Events.on(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local bp = blueprint_of(event, player)
  if not bp then return end
  local mapping = nil
  if event.mapping and event.mapping.valid then mapping = event.mapping.get() end
  Blueprint.tag(bp, mapping, event.surface)
end)

--- Nach dem Bauen: Einstellungen aus den Tags übernehmen (falls vorhanden).
function Blueprint.apply_tags(station, tags)
  local config = tags and tags[TAG]
  if station and type(config) == "table" and config.mode then Paste.apply(station, config) end
end

return Blueprint
