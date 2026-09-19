--- Reiter „Alarme“ (wie „Alerts“ bei LTN Manager): die letzten Warnungen zum Nachlesen.
--- Zeit | Symbol | Meldung (mit Anzahl bei Wiederholung) | Ort (Klick → Karte).
--- Zeigt alle Warnungen, auch Gruppen, die der Spieler als Factorio-Warnung abgeschaltet hat.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Alerts = require("scripts.alerts.alerts")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-time" }, width = 70 },
  { caption = "", width = 32 },
  { caption = { "utl-manager.col-alert" }, width = 560 },
  { caption = { "utl-manager.col-place" }, width = 120 },
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
    tooltip = { "utl-manager.alerts-clear" },
    tags = { utl_mgr = "clear_alerts" },
  })
  return { count = count, rows = List.build(parent, COLUMNS) }
end

local function fill(row, entry)
  List.cell(row, COLUMNS[1].width, { type = "label", caption = Widgets.duration(entry.tick) })
  local icon = List.cell(row, COLUMNS[2].width, { type = "sprite", sprite = Alerts.sprite(entry.icon) })
  icon.style.stretch_image_to_widget_size = true
  icon.style.height = 32
  local caption = entry.message
  if entry.count > 1 then caption = { "", caption, "  ", { "utl-manager.alerts-repeat", entry.count } } end
  local text = List.cell(row, COLUMNS[3].width, { type = "label", caption = caption })
  text.style.single_line = false
  local place = List.cell(row, COLUMNS[4].width, {
    type = "label",
    style = "clickable_label",
    caption = { "utl-manager.alerts-goto" },
    tooltip = { "utl-manager.goto-station" },
    tags = { utl_mgr = "goto", surface = entry.surface, x = entry.position.x, y = entry.position.y },
  })
  place.style.font = "default-bold"
end

function Tab.refresh(refs)
  local list = storage.alert_log
  refs.count.caption = { "utl-manager.alerts-count", #list }
  List.sync(refs.rows, list, fill)
end

return Tab
