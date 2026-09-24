--- Verdrahtet das Admin-Fenster mit Befehl und GUI-Events.
local Events = require("scripts.core.events")
local Admin = require("scripts.gui.admin.window")

--- /utl-admin: Fenster öffnen bzw. schließen (nur Admins).
commands.add_command("utl-admin", { "utl-command.admin-help" }, function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if not player then return end
  if not player.admin then
    player.print({ "utl-command.admin-only" })
    return
  end
  if Admin.get(player.index) then Admin.close(player.index) else Admin.open(player) end
end)

local function context(event)
  local element = event.element
  if not (element and element.valid) then return nil end
  local tags = element.tags
  local action = tags and tags.utl_admin
  local player = action and game.get_player(event.player_index)
  if not player then return nil end
  return action, tags, player, element
end

local function handle(event)
  local action, tags, player, element = context(event)
  if not (action and player) then return end
  -- Textfelder: Wert übernehmen, aber das Feld beim Tippen nicht neu schreiben
  local typing = event.name == defines.events.on_gui_text_changed
  if Admin.handle(player, action, tags, element) and not typing then Admin.refresh(player.index) end
end

Events.on(defines.events.on_gui_click, handle)
Events.on(defines.events.on_gui_selection_state_changed, handle)
Events.on(defines.events.on_gui_checked_state_changed, handle)
Events.on(defines.events.on_gui_text_changed, handle)
Events.on(defines.events.on_gui_confirmed, function(event)
  local action, _, player = context(event)
  if action and player then Admin.refresh(player.index) end
end)
Events.on(defines.events.on_gui_closed, function(event)
  if Admin.is_window(event.element) then Admin.close(event.player_index) end
end)
Events.on_configuration_changed(Admin.close_all)
