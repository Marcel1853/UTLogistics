--- Verdrahtet den UTL-Manager mit Shortcut, Tastenkürzel, GUI-Events und dem Takt.
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local C = require("scripts.core.constants")
local Manager = require("scripts.gui.manager.window")

local SHORTCUT = "utl-toggle-manager"

local function toggle(event)
  local player = game.get_player(event.player_index)
  if player then Manager.toggle(player) end
end

Events.on(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == SHORTCUT then toggle(event) end
end)
Events.on("utl-toggle-manager", toggle)

--- tags + Manager eines Events aus unserem Fenster.
local function context(event)
  local element = event.element
  if not (element and element.valid) then return nil end
  local tags = element.tags
  local action = tags and tags.utl_mgr
  if not action then return nil end
  local manager = Manager.get(event.player_index)
  if not manager then return nil end
  return action, tags, manager
end

--- Fernsicht öffnen, ohne dass das Manager-Fenster dabei zugeht.
local function remote_view(player, manager, surface, position, entity)
  manager.jumping = true
  player.set_controller({ type = defines.controllers.remote, position = position, surface = surface })
  if entity then player.centered_on = entity end
  manager.jumping = nil
  if manager.frame.valid then player.opened = manager.frame end
end

Events.on(defines.events.on_gui_click, function(event)
  local action, tags, manager = context(event)
  if not (action and tags and manager) then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  if action == "close" then
    Manager.close(event.player_index)
  elseif action == "refresh" then
    Manager.refresh(event.player_index)
  elseif action == "toggle_search" then
    Manager.toggle_search(manager)
    Manager.refresh(event.player_index)
  elseif action == "goto" then
    remote_view(player, manager, tags.surface, { x = tags.x, y = tags.y })
  elseif action == "follow" then
    local train = game.train_manager.get_train_by_id(tags.train_id)
    local locomotive = train and train.front_stock
    if locomotive then remote_view(player, manager, locomotive.surface_index, locomotive.position, locomotive) end
  elseif action == "ware" then
    manager.ware = manager.ware ~= tags.key and tags.key or nil
    Manager.refresh(event.player_index)
  elseif action == "clear_history" then
    storage.history = {}
    Manager.refresh(event.player_index)
  elseif action == "clear_alerts" then
    storage.alert_log = {}
    Manager.refresh(event.player_index)
  end
end)

Events.on(defines.events.on_gui_text_changed, function(event)
  local action, _, manager = context(event)
  if action ~= "search" or not manager then return end
  Manager.set_search(manager, event.element.text)
  Manager.refresh(event.player_index)
end)

Events.on(defines.events.on_gui_selected_tab_changed, function(event)
  local action = context(event)
  if action == "tabs" then Manager.refresh(event.player_index) end
end)

Events.on(defines.events.on_gui_selection_state_changed, function(event)
  local action, _, manager = context(event)
  if not manager then return end
  if action == "depot_list" then
    Manager.tab("depots").select(manager.refs.depots, manager, event.element.selected_index)
  elseif action == "network_list" then
    Manager.tab("networks").select(manager.refs.networks, manager, event.element.selected_index)
  else
    return
  end
  Manager.refresh(event.player_index)
end)

Events.on(defines.events.on_gui_closed, function(event)
  if not Manager.is_window(event.element) then return end
  local manager = storage.managers[event.player_index]
  if manager and manager.jumping then return end
  Manager.close(event.player_index)
end)

-- Nach einem Mod-Update schließen; beim nächsten Öffnen wird es neu gebaut.
Events.on_configuration_changed(Manager.close_all)

Heartbeat.add_task("manager-refresh", C.gui_refresh_every, Manager.refresh_all)
