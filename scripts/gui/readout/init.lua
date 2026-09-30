--- Fenster des Netz-Kombinators mit den GUI-Events verdrahten (eigenes Tag „utl_readout“, damit
--- sich die Handler nicht mit denen des Stationsfensters in die Quere kommen).
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Readouts = require("scripts.readout.readouts")
local Output = require("scripts.readout.output")
local Window = require("scripts.gui.readout.window")

local function action_of(element)
  if not (element and element.valid) then return nil end
  local tags = element.tags
  return tags and tags.utl_readout, tags
end

--- Einstellung ändern, sofort neu schreiben, Fenster auffrischen bzw. neu aufbauen.
local function apply(event, changes, rebuild)
  local entry = Window.entry_of(event.player_index)
  if not entry then return end
  Readouts.configure(entry, changes)
  Output.write(entry)
  local player = game.get_player(event.player_index)
  if rebuild and player then
    Window.open(player, entry)
  else
    Window.refresh(event.player_index)
  end
end

Events.on(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == C.network_combinator) then return end
  local player = game.get_player(event.player_index)
  local entry = Readouts.get(entity.unit_number) or Readouts.add(entity)
  if player and entry then Window.open(player, entry) end
end)

Events.on(defines.events.on_gui_closed, function(event)
  if Window.is_window(event.element) then Window.close(event.player_index) end
end)

-- Titelleiste: Builder.titlebar setzt „utl_action“ – den Schließen-Knopf fangen wir hier ab
Events.on(defines.events.on_gui_click, function(event)
  local element = event.element
  if element and element.valid and element.tags and element.tags.utl_action == "readout_close" then
    Window.close(event.player_index)
  end
end)

Events.on(defines.events.on_gui_selection_state_changed, function(event)
  if action_of(event.element) ~= "network" then return end
  local element = event.element
  local name = element.items[element.selected_index]
  if type(name) == "string" then apply(event, { network = name }) end
end)

Events.on(defines.events.on_gui_checked_state_changed, function(event)
  local action, tags = action_of(event.element)
  if action == "star" then
    apply(event, { star = event.element.state })
  elseif action == "transit" then
    apply(event, { transit = event.element.state })
  elseif action == "mode" and tags and event.element.state then
    apply(event, { mode = tags.mode }, true) -- Radiobuttons und „unterwegs“-Häkchen neu setzen
  end
end)

Heartbeat.add_task("network-combinator-gui", C.gui_refresh_every, Window.refresh_all, 4)
