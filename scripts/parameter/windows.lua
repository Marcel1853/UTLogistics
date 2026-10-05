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
local Unlocks = require("scripts.core.unlocks")
local Fields = require("scripts.stations.fields")
local RequestSlots = require("scripts.stations.requests").slot_count

local Windows = {}

Windows.CHOOSE, Windows.ASK = "utl_param_choose", "utl_param_ask"

local LABELS = {
  cleanup_all_items = { "virtual-signal-name.utl-cleanup-all-items" },
  cleanup_all_fluids = { "virtual-signal-name.utl-cleanup-all-fluids" },
  cleanup_offer = { "utl-gui.cleanup-offer" },
  storage_limits = { "utl-gui.section-storage" },
  storage_leftover = { "utl-gui.storage-leftover" },
  cleanup_wares = { "utl-param.cleanup-wares" },
}

local function label_of(key)
  if key == "role" or key == "request" or key == "network" then return { "utl-param." .. key } end
  return LABELS[key] or { "utl-gui.value-" .. key }
end

--- Lager: je Zeile Ware | Mindest | Höchst.
local function add_limits(grid, key, limits, player, empty)
  local StorageSlots = Unlocks.storage_slots(player.force)
  local t = grid.add({ type = "table", name = key, column_count = 3 })
  t.add({ type = "label", caption = { "utl-gui.storage-good" } })
  t.add({ type = "label", caption = { "utl-gui.storage-min" } })
  t.add({ type = "label", caption = { "utl-gui.storage-max" } })
  -- belegte Zeilen der Reihe nach (auch Text-Schlüssel „3“ aus JSON), dazu zwei leere – nicht immer
  -- alle 8, sonst wird der Reiter (und damit das ganze Fenster) unnötig lang
  local filled = {}
  for slot = 1, StorageSlots do
    local limit = limits[slot] or limits[tostring(slot)]
    if limit and limit.signal then filled[#filled + 1] = limit end
  end
  -- belegte Zeilen + `empty` leere (mindestens eine Zeile); weitere über den Knopf „+“
  for slot = 1, math.min(StorageSlots, math.max(1, #filled + empty)) do
    local limit = filled[slot] or {}
    t.add({ type = "choose-elem-button", name = "s" .. slot, style = "slot_button", elem_type = "signal",
      signal = limit.signal, elem_filters = { { filter = "type", type = "item" }, { filter = "type", type = "fluid" } } })
    t.add({ type = "textfield", name = "min" .. slot, text = tostring(limit.min or 0), numeric = true, style = "utl_entry_text" }).style.width = 70
    t.add({ type = "textfield", name = "max" .. slot, text = tostring(limit.max or 0), numeric = true, style = "utl_entry_text" }).style.width = 70
  end
end

local function frame(player, name, caption, deep)
  local old = player.gui.screen[name]
  local location = old and old.location
  if old then old.destroy() end
  local f = player.gui.screen.add({ type = "frame", name = name, direction = "vertical" })
  local bar = Builder.titlebar(f, caption, "")
  bar.children[3].tags = { utl_param = "close", window = name }
  if location then f.location = location else f.auto_center = true end
  -- `deep`: Reiter brauchen den dunklen Vanilla-Rahmen (sonst doppelte Ränder)
  local inner = f.add({ type = "frame", name = "inner", direction = "vertical",
    style = deep and "inside_deep_frame" or "inside_shallow_frame_with_padding" })
  return f, inner
end

local function footer(f, caption, action, note)
  local bar = f.add({ type = "flow", style = "dialog_buttons_horizontal_flow" })
  if note then bar.add({ type = "label", caption = note }).style.top_margin = 4 end
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

--- Cleanup: einzelne Waren, die angenommen werden – je eine Reihe Items und Flüssigkeiten.
local function add_wares(parent, key, wares)
  local t = parent.add({ type = "table", name = key, column_count = 1 })
  for _, kind in ipairs({ "item", "fluid" }) do
    local count = kind == "item" and Fields.cleanup_item_slots or Fields.cleanup_fluid_slots
    local list = wares[kind == "item" and "items" or "fluids"] or {}
    local row = t.add({ type = "table", name = kind, column_count = count, style = "filter_slot_table" })
    for i = 1, count do
      row.add({ type = "choose-elem-button", name = "e" .. i, style = "slot_button", elem_type = kind,
        [kind] = list[i] or list[tostring(i)] })
    end
  end
end

--- Knöpfe „+“ / „−“ unter einer mehrzeiligen Eingabe: Zeile dazu bzw. letzte weg. Klein (halbe
--- Slot-Breite) und mittig zwischen den Spalten Ware und Menge (Wunsch Marcel).
local function row_buttons(parent, key)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.left_margin = 20
  flow.style.horizontal_spacing = 4
  for _, b in ipairs({ { "+", "add_row", "utl-param.add-row" }, { "-", "remove_row", "utl-param.remove-row" } }) do
    local button = flow.add({ type = "button", style = "mini_button", caption = b[1], tooltip = { b[3] },
      tags = { utl_param = b[2], key = key } })
    button.style.width = 20
    button.style.height = 20
    button.style.padding = 0
    button.style.font = "default-bold"
  end
end

local function add_input(grid, player, key, cfg, extra)
  extra = extra or {}
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
    flow.add({ type = "label", caption = { "utl-param.network-new-label" }, tooltip = { "utl-param.network-new" } })
    local new = flow.add({ type = "textfield", name = "new", tooltip = { "utl-param.network-new" } })
    new.style.width = 90
    flow.style.vertical_align = "center"
  elseif key == "request" then
    -- je Ware eine Zeile (Ware | Menge), dazu zwei leere für weitere Waren
    local t = grid.add({ type = "table", name = key, column_count = 2 })
    t.style.vertical_spacing = 4
    t.add({ type = "label", caption = { "utl-gui.storage-good" } })
    t.add({ type = "label", caption = { "utl-param.amount" } })
    local rows = current --[[@as table]]
    local fuel_only = cfg.mode == "fuel"
    for i = 1, math.min(RequestSlots, math.max(1, #rows + (extra.request or 0))) do
      local row = rows[i] or { count = 0 }
      local pick = t.add({ type = "choose-elem-button", name = "w" .. i, style = "slot_button",
        tags = { utl_param = "ware", row = i },
        elem_type = fuel_only and "item-with-quality" or "signal",
        elem_filters = fuel_only and Util.locomotive_fuel_filters() or nil })
      local signal = row.signal
      if signal and fuel_only then
        if signal.type ~= "fluid" then pick.elem_value = { name = signal.name, quality = signal.quality or "normal" } end
      elseif signal then
        pick.elem_value = { type = signal.type or "item", name = signal.name, quality = signal.quality }
      end
      t.add({ type = "textfield", name = "c" .. i, text = tostring(row.count or 0), numeric = true, style = "utl_entry_text" }).style.width = 80
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
  elseif entry.kind == "wares" then
    add_wares(grid, key, current --[[@as table]])
  elseif entry.kind == "limits" then
    add_limits(grid, key, current --[[@as table]], player, extra.storage_limits or 0)
  else
    grid.add({ type = "textfield", name = key, text = tostring(current), numeric = true, style = "utl_entry_text",
      allow_negative = key:find("priority") ~= nil })
  end
end

--- Abfrage-Fenster: nur Punkte aus `keys`, die zur Rolle passen; vorbelegt aus `cfg`.
--- `extra` = { [key] = Anzahl zusätzlicher leerer Zeilen } (Knopf „+“).
function Windows.ask(player, keys, cfg, count, extra, tab)
  local f, inner = frame(player, Windows.ASK, { "utl-param.ask-title" }, true)
  -- drei Reiter, damit das Fenster klein bleibt (Wunsch Marcel); leere Reiter fallen weg
  local tabs = inner.add({ type = "tabbed-pane", name = "pages", style = "tabbed_pane_with_no_side_padding" })
  local content = inner.add({ type = "flow", name = "content", direction = "vertical" })
  local role = Settings.role_code(cfg)
  local grids = {}
  for _, tab in ipairs(Ask.TABS) do
    local has = false
    for _, key in ipairs(keys) do
      if Ask.relevant(key, role) and Ask.by_key[key].tab == tab then has = true end
    end
    if has then
      -- Reiter nur als Kopf (leerer Inhalt); der echte Inhalt steht darunter in `content` –
      -- Factorio macht ein tabbed-pane so hoch wie seinen längsten Inhalt, auch wenn er verborgen ist
      local head = tabs.add({ type = "tab", caption = { "utl-param.tab-" .. tab } })
      local empty = tabs.add({ type = "empty-widget" })
      empty.style.height = 0
      tabs.add_tab(head, empty)
      local scroll = content.add({ type = "scroll-pane", name = tab, horizontal_scroll_policy = "never" })
      scroll.style.maximal_height = 420
      scroll.style.padding = 12
      local grid = scroll.add({ type = "table", name = "grid", column_count = 2 })
      grid.style.vertical_spacing = 6
      grids[tab] = grid
    end
  end
  local headed = {}
  for _, key in ipairs(keys) do
    local entry = Ask.by_key[key]
    local grid = Ask.relevant(key, role) and grids[entry.tab]
    if grid then
      if entry.kind == "request" or entry.kind == "limits" or entry.kind == "wares" then
        -- mehrzeilig: Überschrift über voller Breite, darunter die Tabelle (nicht neben dem Text)
        local scroll = grid.parent
        scroll.add({ type = "label", style = "utl_header_label", caption = label_of(key) }).style.top_margin = 6
        add_input(scroll, player, key, cfg, extra)
        if entry.kind ~= "wares" then row_buttons(scroll, key) end
      else
        -- Werte-Reiter: Überschrift „Anbieter“ / „Abnehmer“ vor der ersten Zeile der Gruppe
        local group = entry.group
        if group and not headed[group] then
          headed[group] = true
          grid.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.section-" .. group } })
          grid.add({ type = "empty-widget" })
        end
        grid.add({ type = "label", caption = key == "output" and cfg.mode == "depot" and { "utl-gui.value-depot-output" }
          or label_of(key) })
        add_input(grid, player, key, cfg)
      end
    end
  end
  -- Hinweis „gilt für n Stationen“ unten neben dem Knopf (statt eigener Zeile über den Reitern)
  -- gewählten Reiter behalten (+ / − / Rollenwechsel bauen neu auf); nur der sichtbare Reiter zählt
  -- für die Höhe – sonst ist „Allgemein“ so lang wie „Waren“
  if tab and tab <= #tabs.tabs then tabs.selected_tab_index = tab else tabs.selected_tab_index = 1 end
  Windows.show_tab(tabs)
  footer(f, { "utl-param.apply" }, "apply", { "utl-param.ask-intro", count })
  -- kein player.opened: die Blaupause soll in der Hand bleiben (weiter platzieren)
end

--- Ware in einer Anforderungs-Zeile gewählt: steht die Menge noch auf 0, einen Stapel eintragen
--- (Flüssigkeit 1000) – wie im Stationsfenster.
function Windows.ware_chosen(element)
  local row = element.tags.row
  local count = row and element.parent["c" .. row]
  if not (count and (tonumber(count.text) or 0) == 0) then return end
  local v = element.elem_value --[[@as table?]]
  if not (v and v.name) then return end
  local key = Util.signal_key({ type = v.type or "item", name = v.name, quality = v.quality })
  count.text = tostring(key and Util.stack_size(key) or 1000)
end

--- Nur den gewählten Reiter sichtbar machen (die anderen bestimmen dann nicht die Höhe).
function Windows.show_tab(tabs)
  local content = tabs.parent.content
  for i, page in ipairs(content.children) do page.visible = i == tabs.selected_tab_index end
end

--- Gewählter Reiter des Abfrage-Fensters (oder nil).
function Windows.selected_tab(player)
  local f = player.gui.screen[Windows.ASK]
  return f and f.inner.pages.selected_tab_index or nil
end

--- Eingaben des Abfrage-Fensters → { [key] = Wert } (nur sichtbare Punkte).
function Windows.answers(player)
  local f = player.gui.screen[Windows.ASK]
  local answers = {}
  if not f then return answers end
  local elements = {}
  for _, content in pairs(f.inner.content.children) do
    if content.type == "scroll-pane" then
      for _, el in pairs(content.children) do
        if el.name == "grid" then
          for _, cell in pairs(el.children) do elements[#elements + 1] = cell end
        elseif el.name ~= "" then
          elements[#elements + 1] = el -- mehrzeilige Eingaben (Anforderungen, Lager) unter dem Raster
        end
      end
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
    elseif entry and entry.kind == "wares" then
      local wares = { items = {}, fluids = {} }
      for _, kind in ipairs({ "item", "fluid" }) do
        local list = wares[kind == "item" and "items" or "fluids"]
        for _, button in ipairs(el[kind].children) do
          if button.elem_value then list[#list + 1] = button.elem_value end
        end
      end
      answers[el.name] = wares
    elseif entry and entry.kind == "limits" then
      local limits = {}
      local shown = 0
      for slot = 1, 20 do
        if not el["s" .. slot] then break end
        shown = slot
        local v = el["s" .. slot].elem_value --[[@as SignalID?]]
        if v and v.name and (v.type == "item" or v.type == "fluid" or v.type == nil) then
          limits[#limits + 1] = { signal = { type = v.type or "item", name = v.name, quality = v.quality },
            min = math.max(0, tonumber(el["min" .. slot].text) or 0), max = math.max(0, tonumber(el["max" .. slot].text) or 0) }
        end
      end
      answers[el.name] = limits
      answers.storage_rows = shown -- für „+“: wie viele Zeilen gerade stehen
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
