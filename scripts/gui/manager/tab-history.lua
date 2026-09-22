--- Reiter „Verlauf“ (wie LTN Manager): Depot | Strecke | Laufzeit | Beendet | Ladung.
--- Abgebrochene Lieferungen stehen rot mit Grund darin.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Filter = require("scripts.gui.manager.surface-filter")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-depot" }, width = 120 },
  { caption = { "utl-manager.col-route" }, width = 260 },
  { caption = { "utl-manager.col-runtime" }, width = 70 },
  { caption = { "utl-manager.col-finished" }, width = 80 },
  { caption = { "utl-manager.col-cargo" }, width = 160 },
}

function Tab.build(parent)
  local bar = parent.add({ type = "flow", direction = "horizontal" })
  bar.style.vertical_align = "center"
  local count = bar.add({ type = "label" })
  bar.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  bar.add({
    type = "sprite-button",
    style = "tool_button_red",
    sprite = "utility/trash",
    tooltip = { "utl-manager.history-clear" },
    tags = { utl_mgr = "clear_history" },
  })
  return { count = count, rows = List.build(parent, COLUMNS) }
end

-- Manager des laufenden Auffrischens (fill bekommt nur Zeile und Eintrag)
local current = nil

local function fill(row, entry)
  local depot = current and Filter.name(current, entry.depot or "", entry.surface) or entry.depot or ""
  List.cell(row, COLUMNS[1].width, { type = "label", caption = depot }).style.font = "default-bold"
  local route = List.cell(row, COLUMNS[2].width, { type = "flow", direction = "vertical" })
  route.style.vertical_spacing = 0
  route.add({ type = "label", caption = entry.from or "?" }).style.font = "default-bold"
  route.add({ type = "label", caption = { "utl-manager.route-to", entry.to or "?" } })
  if entry.canceled then
    local reason = route.add({ type = "label", caption = { "utl-manager.canceled", entry.canceled } })
    reason.style.font_color = { 1, 0.3, 0.3 }
  end
  List.cell(row, COLUMNS[3].width, { type = "label", caption = Widgets.duration(entry.finished - entry.started) })
  List.cell(row, COLUMNS[4].width, { type = "label", caption = Widgets.duration(entry.finished) })
  local grid = Widgets.slot_grid(row, 4)
  -- ältere Einträge (vor den Ladelisten) haben key/amount
  local manifest = entry.manifest or (entry.key and { [entry.key] = entry.amount }) or {}
  Widgets.add_slots(grid, manifest, entry.canceled and "request" or "cargo")
end

function Tab.refresh(refs, manager)
  local search = manager.search
  local items = {}
  for _, entry in ipairs(storage.history) do
    -- ältere Einträge ohne Oberfläche erscheinen nur unter „Alle“
    if Filter.match(manager, entry.surface) and (search == ""
      or string.find(string.lower(entry.from or ""), search, 1, true)
      or string.find(string.lower(entry.to or ""), search, 1, true)
      or string.find(string.lower(entry.depot or ""), search, 1, true)) then
      items[#items + 1] = entry
    end
  end
  refs.count.caption = { "utl-manager.history-count", #items }
  current = manager
  List.sync(refs.rows, items, fill)
  current = nil
end

return Tab
