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
local StorageSlots = require("scripts.stations.fields").storage_slots
local RequestSlots = require("scripts.stations.requests").slot_count

local Windows = {}

Windows.CHOOSE, Windows.ASK = "utl_param_choose", "utl_param_ask"

local LABELS = {
  cleanup_all_items = { "virtual-signal-name.utl-cleanup-all-items" },
  cleanup_all_fluids = { "virtual-signal-name.utl-cleanup-all-fluids" },
  cleanup_offer = { "utl-gui.cleanup-offer" },
  storage_limits = { "utl-gui.section-storage" },
}

local function label_of(key)
  if key == "role" or key == "request" or key == "network" then return { "utl-param." .. key } end
  return LABELS[key] or { "utl-gui.value-" .. key }
end

--- Lager: je Zeile Ware | Mindest | Höchst.
local function add_limits(grid, key, limits)
  local t = grid.add({ type = "table", name = key, column_count = 3 })
  t.add({ type = "label", caption = { "utl-gui.storage-good" } })
  t.add({ type = "label", caption = { "utl-gui.storage-min" } })
  t.add({ type = "label", caption = { "utl-gui.storage-max" } })
  for slot = 1, StorageSlots do
    local limit = limits[slot] or {}
    t.add({ type = "choose-elem-button", name = "s" .. slot, style = "slot_button", elem_type = "signal",
      signal = limit.signal, elem_filters = { { filter = "type", type = "item" }, { filter = "type", type = "fluid" } } })
    t.add({ type = "textfield", name = "min" .. slot, text = tostring(limit.min or 0), numeric = true }).style.width = 70
    t.add({ type = "textfield", name = "max" .. slot, text = tostring(limit.max or 0), numeric = true }).style.width = 70
  end
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
  local columns = inner.add({ type = "table", name = "checks", column_count = 2 })
  columns.style.horizontal_spacing = 24
  for _, entry in ipairs(Ask.list) do
    columns.add({ type = "checkbox", name = entry.key, caption = label_of(entry.key), state = true })
  end
  footer(f, { "utl-param.make-blueprint" }, "make")
  player.opened = f
end

--- Gewählte Punkte aus dem Auswahl-Fenster.
function Windows.chosen(player)
  local f = player.gui.screen[Windows.CHOOSE]
  local keys = {}
  if not f then return keys end
  for _, child in pairs(f.inner.checks.children) do
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
    -- je Ware eine Zeile (Ware | Menge), dazu zwei leere für weitere Waren
    local t = grid.add({ type = "table", name = key, column_count = 2 })
    local rows = current --[[@as table]]
    local fuel_only = cfg.mode == "fuel"
    for i = 1, math.min(RequestSlots, #rows + 2) do
      local row = rows[i] or { count = 0 }
      local pick = t.add({ type = "choose-elem-button", name = "w" .. i,
        elem_type = fuel_only and "item-with-quality" or "signal",
        elem_filters = fuel_only and { { filter = "fuel-value", comparison = ">", value = 0 } } or nil })
      local signal = row.signal
      if signal and fuel_only then
        if signal.type ~= "fluid" then pick.elem_value = { name = signal.name, quality = signal.quality or "normal" } end
      elseif signal then
        pick.elem_value = { type = signal.type or "item", name = signal.name, quality = signal.quality }
      end
      t.add({ type = "textfield", name = "c" .. i, text = tostring(row.count or 0), numeric = true }).style.width = 90
    end
  elseif entry.kind == "toggle" then
    grid.add({ type = "checkbox", name = key, state = current })
  elseif entry.kind == "offer" then
    local items, selected = {}, 1
    for i, tier in ipairs(Ask.CLEANUP_OFFER) do
      items[i] = tier == "off" and { "utl-param.offer-off" } or { "utl-gui.cleanup-offer-" .. tier }
      if tier == current then selected = i end
    end
    grid.add({ type = "drop-down", name = key, items = items, selected_index = selected })
  elseif entry.kind == "limits" then
    add_limits(grid, key, current --[[@as table]])
  else
    grid.add({ type = "textfield", name = key, text = tostring(current), numeric = true,
      allow_negative = key:find("priority") ~= nil }).style.width = 90
  end
end

--- Abfrage-Fenster: nur Punkte aus `keys`, die zur Rolle passen; vorbelegt aus `cfg`.
function Windows.ask(player, keys, cfg, count)
  local f, inner = frame(player, Windows.ASK, { "utl-param.ask-title" })
  inner.add({ type = "label", caption = { "utl-param.ask-intro", count } }).style.single_line = false
  -- drei Reiter, damit das Fenster klein bleibt (Wunsch Marcel); leere Reiter fallen weg
  local tabs = inner.add({ type = "tabbed-pane", name = "pages" })
  local role = Settings.role_code(cfg)
  local grids = {}
  for _, tab in ipairs(Ask.TABS) do
    local has = false
    for _, key in ipairs(keys) do
      if Ask.relevant(key, role) and Ask.by_key[key].tab == tab then has = true end
    end
    if has then
      local head = tabs.add({ type = "tab", caption = { "utl-param.tab-" .. tab } })
      local scroll = tabs.add({ type = "scroll-pane", horizontal_scroll_policy = "never" })
      scroll.style.maximal_height = 420
      tabs.add_tab(head, scroll)
      local grid = scroll.add({ type = "table", name = "grid", column_count = 2 })
      grid.style.vertical_spacing = 6
      grids[tab] = grid
    end
  end
  for _, key in ipairs(keys) do
    local grid = Ask.relevant(key, role) and grids[Ask.by_key[key].tab]
    if grid then
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
  local elements = {}
  for _, content in pairs(f.inner.pages.children) do
    if content.type == "scroll-pane" and content.grid then
      for _, el in pairs(content.grid.children) do elements[#elements + 1] = el end
    end
  end
  for _, el in pairs(elements) do
    local entry = Ask.by_key[el.name]
    if el.name == "role" then
      answers.role = el.selected_index - 1
    elseif el.name == "network" then
      local typed = el.new.text:gsub("^%s+", ""):gsub("%s+$", "")
      local picked = el.pick.selected_index > 0 and el.pick.get_item(el.pick.selected_index)
      answers.network = typed ~= "" and typed or (type(picked) == "string" and picked or nil)
    elseif el.name == "request" then
      local rows = {}
      local i = 1
      while el["w" .. i] do
        local v = el["w" .. i].elem_value --[[@as table?]]
        local signal = nil
        if v and v.name then
          signal = { type = v.type or "item", name = v.name, quality = v.quality }
          if not Util.signal_key(signal) then signal = nil end
        end
        rows[#rows + 1] = { signal = signal, count = tonumber(el["c" .. i].text) or 0 }
        i = i + 1
      end
      answers.request = rows
    elseif entry and entry.kind == "toggle" then
      answers[el.name] = el.state
    elseif entry and entry.kind == "offer" then
      answers[el.name] = Ask.CLEANUP_OFFER[el.selected_index] or "off"
    elseif entry and entry.kind == "limits" then
      local limits = {}
      for slot = 1, StorageSlots do
        local v = el["s" .. slot].elem_value --[[@as SignalID?]]
        if v and v.name and (v.type == "item" or v.type == "fluid" or v.type == nil) then
          limits[slot] = { signal = { type = v.type or "item", name = v.name, quality = v.quality },
            min = math.max(0, tonumber(el["min" .. slot].text) or 0), max = math.max(0, tonumber(el["max" .. slot].text) or 0) }
        end
      end
      answers[el.name] = limits
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
