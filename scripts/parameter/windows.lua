--- Die beiden kleinen Fenster des Parameter-Planers:
---   * Auswahl („Was soll beim Platzieren abgefragt werden?“) nach dem Ziehen,
---   * Abfrage (Werte eingeben) beim Platzieren der Blaupause.
--- Tags: { utl_param = Aktion, key = … }.
local Builder = require("scripts.gui.common.builder")
local Ask = require("scripts.parameter.fields")
local Settings = require("scripts.stations.settings-combinator")
local Util = require("scripts.lib.util")

local Windows = {}

Windows.CHOOSE, Windows.ASK = "utl_param_choose", "utl_param_ask"

local function label_of(key)
  if key == "role" then return { "utl-param.role" } end
  if key == "request" then return { "utl-param.request" } end
  return { "utl-gui.value-" .. key }
end

local function frame(player, name, caption)
  local old = player.gui.screen[name]
  if old then old.destroy() end
  local f = player.gui.screen.add({ type = "frame", name = name, direction = "vertical" })
  Builder.titlebar(f, caption, "")
  f.children[1].children[3].tags = { utl_param = "close", window = name }
  f.auto_center = true
  local inner = f.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  return f, inner
end

--- Auswahl-Fenster nach dem Ziehen. `count` = UTL-Stationen im Bereich.
function Windows.choose(player, count, checked)
  local f, inner = frame(player, Windows.CHOOSE, { "utl-param.choose-title" })
  inner.add({ type = "label", caption = { "utl-param.choose-intro", count } }).style.single_line = false
  for _, entry in ipairs(Ask.list) do
    inner.add({ type = "checkbox", name = entry.key, caption = label_of(entry.key),
      state = checked == nil or checked[entry.key] == true })
  end
  local bar = f.add({ type = "flow", style = "dialog_buttons_horizontal_flow" })
  bar.add({ type = "empty-widget", style = "flib_dialog_footer_drag_handle" }).drag_target = f
  bar.add({ type = "button", style = "confirm_button", caption = { "utl-param.make-blueprint" },
    tags = { utl_param = "make" } })
  player.opened = f
end

--- Gewählte Punkte aus dem Auswahl-Fenster.
function Windows.chosen(player)
  local f = player.gui.screen[Windows.CHOOSE]
  local keys = {}
  if not f then return keys end
  for _, child in pairs(f.children[2].children) do
    if child.type == "checkbox" and child.state then keys[#keys + 1] = child.name end
  end
  return keys
end

local function role_items()
  local items = { { "utl-param.role-0" } }
  for code = 1, Settings.ROLE_COUNT do items[#items + 1] = { "utl-param.role-" .. code } end
  return items
end

--- Abfrage-Fenster beim Platzieren: je Punkt ein Eingabefeld, vorbelegt aus `cfg`.
function Windows.ask(player, keys, cfg, count)
  local f, inner = frame(player, Windows.ASK, { "utl-param.ask-title" })
  inner.add({ type = "label", caption = { "utl-param.ask-intro", count } }).style.single_line = false
  local grid = inner.add({ type = "table", name = "grid", column_count = 2 })
  grid.style.vertical_spacing = 6
  for _, key in ipairs(keys) do
    grid.add({ type = "label", caption = label_of(key) })
    local current = Ask.current(cfg, key)
    if key == "role" then
      grid.add({ type = "drop-down", name = key, items = role_items(), selected_index = current + 1 })
    elseif key == "request" then
      local flow = grid.add({ type = "flow", name = key })
      local signal = current.signal
      local pick = flow.add({ type = "choose-elem-button", name = "ware", elem_type = "signal" })
      if signal then pick.elem_value = { type = signal.type or "item", name = signal.name, quality = signal.quality } end
      local field = flow.add({ type = "textfield", name = "count", text = tostring(current.count or 0), numeric = true })
      field.style.width = 90
    else
      local field = grid.add({ type = "textfield", name = key, text = tostring(current), numeric = true,
        allow_negative = key:find("priority") ~= nil })
      field.style.width = 90
    end
  end
  local bar = f.add({ type = "flow", style = "dialog_buttons_horizontal_flow" })
  bar.add({ type = "empty-widget", style = "flib_dialog_footer_drag_handle" }).drag_target = f
  bar.add({ type = "button", style = "confirm_button", caption = { "utl-param.apply" }, tags = { utl_param = "apply" } })
  player.opened = f
end

--- Eingaben des Abfrage-Fensters → { [key] = Wert }.
function Windows.answers(player)
  local f = player.gui.screen[Windows.ASK]
  local answers = {}
  if not f then return answers end
  for _, el in pairs(f.children[2].grid.children) do
    if el.name == "role" then
      answers.role = el.selected_index - 1
    elseif el.name == "request" then
      local v = el.ware.elem_value --[[@as SignalID?]]
      local signal = v and v.name and Util.signal_key(v) and { type = v.type or "item", name = v.name, quality = v.quality }
      answers.request = { signal = signal or nil, count = tonumber(el.count.text) or 0 }
    elseif el.type == "textfield" and Ask.by_key[el.name] then
      answers[el.name] = tonumber(el.text) or 0
    end
  end
  return answers
end

function Windows.close(player, name)
  local f = player.gui.screen[name]
  if f then f.destroy() end
end

return Windows
