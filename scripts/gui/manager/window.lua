--- UTL-Manager (Vorbild LTN Manager): Reiter Depots, Stationen, Netzwerke, Inventar, Verlauf, Alarme.
--- Öffnen über den Shortcut-Knopf oder Strg + Umschalt + U.
--- Aufgefrischt wird nur, solange das Fenster offen ist, und nur der sichtbare Reiter.
local Tabs = {
  depots = require("scripts.gui.manager.tab-depots"),
  stations = require("scripts.gui.manager.tab-stations"),
  networks = require("scripts.gui.manager.tab-networks"),
  inventory = require("scripts.gui.manager.tab-inventory"),
  history = require("scripts.gui.manager.tab-history"),
  alerts = require("scripts.gui.manager.tab-alerts"),
}

local Manager = {}

local NAME = "utl_manager"
local SHORTCUT = "utl-toggle-manager"
-- Bei jedem Umbau des Fensters erhöhen (alte Fenster werden dann geschlossen statt aufgefrischt).
local GUI_VERSION = 3
local ORDER = { "depots", "stations", "networks", "inventory", "history", "alerts" }
-- Reiter, die sich im Takt selbst auffrischen (Inventar nur auf Klick, sonst springt die Detailliste).
local AUTO_REFRESH = { depots = true, stations = true, networks = true, history = true, alerts = true }

local function frame_button(parent, sprite, tooltip, action)
  return parent.add({
    type = "sprite-button",
    style = "frame_action_button",
    sprite = sprite,
    tooltip = tooltip,
    mouse_button_filter = { "left" },
    tags = { utl_mgr = action },
  })
end

function Manager.get(player_index)
  local manager = storage.managers[player_index]
  if manager and manager.version == GUI_VERSION and manager.frame.valid then return manager end
  return nil
end

function Manager.close(player_index)
  local manager = storage.managers[player_index]
  storage.managers[player_index] = nil
  if manager and manager.frame and manager.frame.valid then manager.frame.destroy() end
  local player = game.get_player(player_index)
  if player then
    local old = player.gui.screen[NAME]
    if old then old.destroy() end
    player.set_shortcut_toggled(SHORTCUT, false)
  end
end

function Manager.close_all()
  for _, player in pairs(game.players) do Manager.close(player.index) end
end

local function selected_name(manager)
  return ORDER[manager.tabs.selected_tab_index or 1] or ORDER[1]
end

--- Sichtbaren Reiter neu befüllen. `auto` = Aufruf aus dem Takt.
function Manager.refresh(player_index, auto)
  local manager = Manager.get(player_index)
  if not manager then
    if storage.managers[player_index] then Manager.close(player_index) end
    return
  end
  local name = selected_name(manager)
  if auto and not AUTO_REFRESH[name] then return end
  Tabs[name].refresh(manager.refs[name], manager)
end

function Manager.refresh_all()
  for player_index in pairs(storage.managers) do Manager.refresh(player_index, true) end
end

function Manager.open(player)
  Manager.close(player.index)
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical" })
  frame.auto_center = true

  local bar = frame.add({ type = "flow", style = "flib_titlebar_flow" })
  bar.drag_target = frame
  bar.add({ type = "label", style = "frame_title", caption = { "utl-manager.title" }, ignored_by_interaction = true })
  bar.add({ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true })
  local search = bar.add({
    type = "textfield",
    style = "flib_titlebar_search_textfield",
    visible = false,
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    tags = { utl_mgr = "search" },
  })
  frame_button(bar, "utility/search", { "utl-manager.search" }, "toggle_search")
  frame_button(bar, "utility/refresh", { "utl-manager.refresh" }, "refresh")
  frame_button(bar, "utility/close", { "utl-manager.close" }, "close")

  local tabs = frame.add({ type = "tabbed-pane", style = "tabbed_pane_with_no_side_padding",
    tags = { utl_mgr = "tabs" } })
  local refs = {}
  for _, name in ipairs(ORDER) do
    local tab = tabs.add({ type = "tab", caption = { "utl-manager.tab-" .. name } })
    local content = tabs.add({ type = "flow", direction = "vertical" })
    content.style.width = 880
    content.style.height = 560
    content.style.padding = 8
    content.style.vertical_spacing = 8
    tabs.add_tab(tab, content)
    refs[name] = Tabs[name].build(content)
  end
  tabs.selected_tab_index = 1

  storage.managers[player.index] = {
    version = GUI_VERSION,
    frame = frame,
    tabs = tabs,
    search_field = search,
    search = "",
    refs = refs,
  }
  player.opened = frame
  player.set_shortcut_toggled(SHORTCUT, true)
  Manager.refresh(player.index)
end

function Manager.toggle(player)
  if Manager.get(player.index) then Manager.close(player.index) else Manager.open(player) end
end

function Manager.is_window(element)
  return element and element.valid and element.name == NAME
end

function Manager.toggle_search(manager)
  local field = manager.search_field
  field.visible = not field.visible
  if field.visible then
    field.focus()
  else
    field.text = ""
    manager.search = ""
  end
end

function Manager.set_search(manager, text)
  manager.search = string.lower(text)
end

--- Reiter per Name wählen (z. B. für die Tipps-Szenen).
function Manager.select(player_index, name)
  local manager = Manager.get(player_index)
  if not manager then return end
  for index, tab in ipairs(ORDER) do
    if tab == name then
      manager.tabs.selected_tab_index = index
      Manager.refresh(player_index)
    end
  end
end

--- Aktion eines Reiters weiterreichen (z. B. Depot-Auswahl).
function Manager.tab(name)
  return Tabs[name]
end

return Manager
