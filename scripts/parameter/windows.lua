--- Die beiden kleinen Fenster des Parameter-Planers:
---   * Auswahl („Was soll beim Platzieren abgefragt werden?“) nach dem Ziehen,
---   * Abfrage (Werte eingeben) beim Platzieren der Blaupause – zeigt nur, was zur gewählten Rolle
---     gehört; wechselt die Rolle, wird das Fenster mit den bisherigen Eingaben neu aufgebaut.
--- Tags: { utl_param = Aktion, … }.
local Builder = require("scripts.gui.common.builder")
local Ask = require("scripts.parameter.fields")
local Settings = require("scripts.stations.settings-combinator")
local More = require("scripts.api.remote-more")
local Util = require("scripts.lib.util")

local Windows = {}

Windows.CHOOSE, Windows.ASK = "utl_param_choose", "utl_param_ask"

local function label_of(key)
  if key == "role" or key == "request" or key == "network" then return { "utl-param." .. key } end
  return { "utl-gui.value-" .. key }
end

local function frame(player, name, caption)
  local old = player.gui.screen[name]
  local location = old and old.location
  if old then old.destroy() end
  local f = player.gui.screen.add({ type = "frame", name = name, direction = "vertical" })
  local bar = Builder.titlebar(f, caption, "")
  bar.children[3].tags = { utl_param = "close", window = name }
  if location then f.location = location else f.auto_center = true end
  local inner = f.add({ type = "frame", name = "inner", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  return f, inner
end

local function footer(f, caption, action)
  local bar = f.add({ type = "flow", style = "dialog_buttons_horizontal_flow" })
  bar.add({ type = "empty-widget", style = "flib_dialog_footer_drag_handle" }).drag_target = f
  bar.add({ type = "button", style = "confirm_button", caption = caption, tags = { utl_param = action } })
end

--- Auswahl-Fenster nach dem Ziehen. `count` = UTL-Stationen im Bereich.
function Windows.choose(player, count)
  local f, inner = frame(player, Windows.CHOOSE, { "utl-param.choose-title" })
  inner.add({ type = "label", caption = { "utl-param.choose-intro", count } }).style.single_line = false
  for _, entry in ipairs(Ask.list) do
    inner.add({ type = "checkbox", name = entry.key, caption = label_of(entry.key), state = true })
  end
  footer(f, { "utl-param.make-blueprint" }, "make")
  player.opened = f
end

--- Gewählte Punkte aus dem Auswahl-Fenster.
function Windows.chosen(player)
  local f = player.gui.screen[Windows.CHOOSE]
  local keys = {}
  if not f then return keys end
  for _, child in pairs(f.inner.children) do
    if child.type == "checkbox" and child.state then keys[#keys + 1] = child.name end
  end
  return keys
end

local function role_items()
  local items = { { "utl-param.role-0" } }
  for code = 1, Settings.ROLE_COUNT do items[#items + 1] = { "utl-param.role-" .. code } end
  return items
end

local function add_input(grid, player, key, cfg)
  local entry = Ask.by_key[key] or {}
  local current = Ask.current(cfg, key)
  if key == "role" then
    grid.add({ type = "drop-down", name = key, items = role_items(), selected_index = current + 1,
      tags = { utl_param = "role" } })
  elseif key == "network" then
    local flow = grid.add({ type = "flow", name = key })
    local names = More.get_networks(player.surface_index, player.force.name)
    local selected = 0
    for i, name in ipairs(names) do if name == current then selected = i end end
    if selected == 0 then
      names[#names + 1] = current
      selected = #names
    end
    flow.add({ type = "drop-down", name = "pick", items = names, selected_index = selected })
    local new = flow.add({ type = "textfield", name = "new", tooltip = { "utl-param.network-new" } })
    new.style.width = 100
  elseif key == "request" then
    local flow = grid.add({ type = "flow", name = key })
    local pick = flow.add({ type = "choose-elem-button", name = "ware", elem_type = "signal" })
    local request = current --[[@as table]]
    local signal = request.signal
    if signal then pick.elem_value = { type = signal.type or "item", name = signal.name, quality = signal.quality } end
    flow.add({ type = "textfield", name = "count", text = tostring(request.count or 0), numeric = true }).style.width = 90
  elseif entry.kind == "toggle" then
    grid.add({ type = "checkbox", name = key, state = current })
  else
    grid.add({ type = "textfield", name = key, text = tostring(current), numeric = true,
      allow_negative = key:find("priority") ~= nil }).style.width = 90
  end
end

--- Abfrage-Fenster: nur Punkte aus `keys`, die zur Rolle passen; vorbelegt aus `cfg`.
function Windows.ask(player, keys, cfg, count)
  local f, inner = frame(player, Windows.ASK, { "utl-param.ask-title" })
  inner.add({ type = "label", caption = { "utl-param.ask-intro", count } }).style.single_line = false
  local grid = inner.add({ type = "table", name = "grid", column_count = 2 })
  grid.style.vertical_spacing = 6
  local role = Settings.role_code(cfg)
  for _, key in ipairs(keys) do
    if Ask.relevant(key, role) then
      grid.add({ type = "label", caption = key == "output" and cfg.mode == "depot" and { "utl-gui.value-depot-output" }
        or label_of(key) })
      add_input(grid, player, key, cfg)
    end
  end
  footer(f, { "utl-param.apply" }, "apply")
  -- kein player.opened: die Blaupause soll in der Hand bleiben (weiter platzieren)
end

--- Eingaben des Abfrage-Fensters → { [key] = Wert } (nur sichtbare Punkte).
function Windows.answers(player)
  local f = player.gui.screen[Windows.ASK]
  local answers = {}
  if not f then return answers end
  for _, el in pairs(f.inner.grid.children) do
    local entry = Ask.by_key[el.name]
    if el.name == "role" then
      answers.role = el.selected_index - 1
    elseif el.name == "network" then
      local typed = el.new.text:gsub("^%s+", ""):gsub("%s+$", "")
      local picked = el.pick.selected_index > 0 and el.pick.get_item(el.pick.selected_index)
      answers.network = typed ~= "" and typed or (type(picked) == "string" and picked or nil)
    elseif el.name == "request" then
      local v = el.ware.elem_value --[[@as SignalID?]]
      local signal = v and v.name and Util.signal_key(v) and { type = v.type or "item", name = v.name, quality = v.quality }
      answers.request = { signal = signal or nil, count = tonumber(el.count.text) or 0 }
    elseif entry and entry.kind == "toggle" then
      answers[el.name] = el.state
    elseif entry and el.type == "textfield" then
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
