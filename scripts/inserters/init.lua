--- Verdrahtet den Wende-Greifarm: Bauen/Abreißen, Drehen von Hand, Kopieren, Blaupausen, Fenster
--- und die Heartbeat-Aufgabe.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Unlocks = require("scripts.core.unlocks")
local Blueprint = require("scripts.stations.blueprint")
local Reversible = require("scripts.inserters.reversible")
local Window = require("scripts.inserters.window")

-- Eigener Filter: Events.on führt die Filter aller Handler zusammen, dieser Handler bekommt also
-- auch Haltestellen usw. – deshalb unten zusätzlich nach dem Namen prüfen.
local filter = { { filter = "name", name = C.reversible_inserter } }

local function on_built(event)
  local entity = event.entity or event.destination
  if not (entity and entity.valid and entity.name == C.reversible_inserter) then return end
  local tag = event.tags and event.tags.utl_rev
  if type(tag) == "table" then
    Reversible.add(entity, tag.cfg, tag.flipped)
  else
    Reversible.add(entity)
  end
end

for _, event in ipairs({ defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built, defines.events.script_raised_revive }) do
  Events.on(event, on_built, filter)
end

-- Geklont (Editor, Plattformen …): Einstellung der Quelle übernehmen
Events.on(defines.events.on_entity_cloned, function(event)
  local entity = event.destination
  if not (entity and entity.valid and entity.name == C.reversible_inserter) then return end
  local source = event.source and event.source.valid and Reversible.get(event.source.unit_number)
  Reversible.add(entity, source and source.cfg, source and source.flipped)
end, filter)

Events.on(defines.events.on_object_destroyed, function(event)
  if event.type == defines.target_type.entity and event.useful_id then Reversible.remove(event.useful_id) end
end)

Events.on(defines.events.on_player_rotated_entity, function(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == C.reversible_inserter then Reversible.rotated(entity) end
end)

-- Einstellungen kopieren (Umschalt + Rechtsklick → Umschalt + Linksklick)
Events.on(defines.events.on_entity_settings_pasted, function(event)
  local source, destination = event.source, event.destination
  if not (source.valid and destination.valid) then return end
  if source.name ~= C.reversible_inserter or destination.name ~= C.reversible_inserter then return end
  local from = Reversible.get(source.unit_number)
  local to = Reversible.get(destination.unit_number) or Reversible.add(destination)
  if from and to then
    to.cfg = table.deepcopy(from.cfg)
    Reversible.update(to, game.tick)
  end
end)

Blueprint.extra[C.reversible_inserter] = Reversible.tag

-- Fenster
Events.on(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  local player = game.get_player(event.player_index)
  if player and entity and entity.valid and entity.name == C.reversible_inserter then Window.open(player, entity) end
end)
Events.on(defines.events.on_gui_closed, function(event)
  local entity = event.entity
  local player = game.get_player(event.player_index)
  if player and entity and entity.valid and entity.name == C.reversible_inserter then
    Window.close(player)
    if storage.rev_open then storage.rev_open[player.index] = nil end
  end
end)
for _, event in ipairs({ defines.events.on_gui_elem_changed, defines.events.on_gui_selection_state_changed,
  defines.events.on_gui_text_changed, defines.events.on_gui_checked_state_changed }) do
  Events.on(event, function(e)
    if e.element and e.element.valid then Window.apply(e.element) end
  end)
end

Heartbeat.add_task("reversible", 1, Reversible.step)
Heartbeat.add_task("reversible-window", 6, Window.refresh_open)

--- Ohne Forschungspflicht (Map-Einstellung) gibt es das Rezept sofort.
local function unlock_recipes()
  if Unlocks.research_required() then return end
  for _, force in pairs(game.forces) do
    local recipe = force.recipes[C.reversible_inserter]
    if recipe then recipe.enabled = true end
  end
end

Events.on_configuration_changed(function()
  Reversible.rebuild()
  unlock_recipes()
  Heartbeat.update_registration()
end)
Events.on_init(unlock_recipes)
Events.on(defines.events.on_runtime_mod_setting_changed, function() unlock_recipes() end)
Events.on(defines.events.on_force_created, function() unlock_recipes() end)
