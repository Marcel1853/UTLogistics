--- Admin-Fenster „UTL-Admin: Teams“ (Befehl /utl-admin, nur Admins): ein Team wählen, Leiter
--- bestimmen oder entfernen und die Team-Werte ändern – z. B. wenn ein Team hängt, weil kein
--- Leiter mehr erreichbar ist.
local TeamPanel = require("scripts.gui.common.team-panel")
local Teams = require("scripts.core.teams")

local Admin = {}

local NAME = "utl_admin"
local TAG = "utl_admin"

--- storage.admin_windows[player_index] = { frame, pick, panel, forces, force_index }
local function windows()
  storage.admin_windows = storage.admin_windows or {}
  return storage.admin_windows
end

function Admin.get(player_index)
  local w = windows()[player_index]
  if w and w.frame.valid then return w end
  return nil
end

function Admin.close(player_index)
  local w = windows()[player_index]
  windows()[player_index] = nil
  if w and w.frame.valid then w.frame.destroy() end
end

function Admin.close_all()
  for index in pairs(windows()) do Admin.close(index) end
end

function Admin.is_window(element)
  return element and element.valid and element.name == NAME
end

function Admin.refresh(player_index)
  local w = Admin.get(player_index)
  if not w then return end
  -- ohne Teams gelten nur die Kartenwerte – dann nichts zum Einstellen anbieten
  local list = Teams.active() and Teams.list() or {}
  local items, forces, selected = {}, {}, 0
  for i, team in ipairs(list) do
    items[i], forces[i] = team.name, team.index
    if team.index == w.force_index then selected = i end
  end
  if selected == 0 then w.force_index = list[1] and list[1].index or nil end
  if selected == 0 and w.force_index then selected = 1 end
  -- erst die Einträge, dann die Auswahl (eine Auswahl in einer leeren Liste ist ein Fehler)
  w.pick.items = items
  if selected > 0 then w.pick.selected_index = selected end
  w.pick.enabled = #items > 0
  w.forces = forces
  w.body.visible = w.force_index ~= nil
  w.empty.visible = w.force_index == nil
  if w.force_index then TeamPanel.refresh(w.panel, w.force_index, true, false) end
end

function Admin.open(player)
  Admin.close(player.index)
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical" })
  frame.auto_center = true
  local bar = frame.add({ type = "flow", style = "flib_titlebar_flow" })
  bar.drag_target = frame
  bar.add({ type = "label", style = "frame_title", caption = { "utl-admin.title" }, ignored_by_interaction = true })
  bar.add({ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true })
  bar.add({ type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
    tooltip = { "utl-manager.close" }, mouse_button_filter = { "left" }, tags = { [TAG] = "close" } })

  local inner = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  inner.style.width = 720
  local row = inner.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.add({ type = "label", style = "utl_header_label", caption = { "utl-admin.team" } })
  local pick = row.add({ type = "drop-down", tags = { [TAG] = "team_pick" } })
  pick.style.width = 220
  local empty = inner.add({ type = "label", caption = { "utl-admin.no-teams" } })
  local body = inner.add({ type = "flow", direction = "vertical" })
  body.style.top_margin = 8
  body.style.vertical_spacing = 4
  local panel = TeamPanel.build(body, TAG)

  windows()[player.index] = { frame = frame, pick = pick, panel = panel, body = body, empty = empty,
    force_index = player.force_index }
  player.opened = frame
  Admin.refresh(player.index)
end

--- Aktion aus dem Fenster ausführen (nur Admins). Liefert true, wenn neu gefüllt werden muss.
function Admin.handle(player, action, tags, element)
  local w = Admin.get(player.index)
  if not (w and player.admin) then return false end
  if action == "close" then
    Admin.close(player.index)
    return false
  elseif action == "team_pick" then
    w.force_index = w.forces[element.selected_index]
    return true
  end
  local force_index = w.force_index
  if not force_index then return false end
  if action == "leader_remove" then
    return Teams.admin_set(force_index, tags.player, false)
  elseif action == "leader_add" then
    local target = w.panel.candidates and w.panel.candidates[element.selected_index]
    return target ~= nil and Teams.admin_set(force_index, target, true)
  elseif action:match("^team_") then
    return TeamPanel.apply(w.panel, force_index, action, tags.id, element)
  end
  return false
end

return Admin
