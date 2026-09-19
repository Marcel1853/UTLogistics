--- Gemeinsame GUI-Bausteine im Vanilla-/flib-Stil.
local Builder = {}

--- Titelleiste: Überschrift, Zieh-Fläche, Schließen-Knopf.
function Builder.titlebar(frame, caption, close_action)
  local bar = frame.add({ type = "flow", style = "flib_titlebar_flow" })
  bar.drag_target = frame
  bar.add({ type = "label", style = "frame_title", caption = caption, ignored_by_interaction = true })
  bar.add({ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true })
  bar.add({
    type = "sprite-button",
    style = "frame_action_button",
    sprite = "utility/close",
    tooltip = { "gui.close-instruction" },
    tags = { utl_action = close_action },
  })
  return bar
end

--- Statuszeile wie bei Vanilla-Maschinen: farbige Lampe + Text.
function Builder.status(parent)
  local flow = parent.add({ type = "flow", style = "flib_indicator_flow" })
  local lamp = flow.add({ type = "sprite", style = "flib_indicator", sprite = "flib_indicator_green" })
  local label = flow.add({ type = "label" })
  return { lamp = lamp, label = label }
end

--- `color` = "green" | "yellow" | "red".
function Builder.set_status(status, color, caption)
  status.lamp.sprite = "flib_indicator_" .. color
  status.label.caption = caption
end

--- Abschnitts-Überschrift.
function Builder.heading(parent, caption)
  return parent.add({ type = "label", style = "caption_label", caption = caption })
end

--- Tabelle für Einstellungszeilen: Beschriftung (links, dehnbar) | Eingabe (rechts).
function Builder.rows(parent)
  local grid = parent.add({ type = "table", column_count = 2 })
  grid.style.horizontally_stretchable = true
  grid.style.vertical_spacing = 6
  grid.style.column_alignments[1] = "left"
  grid.style.column_alignments[2] = "right"
  return grid
end

local function row_label(grid, caption, tooltip)
  local label = grid.add({ type = "label", caption = caption, tooltip = tooltip })
  label.style.horizontally_stretchable = true
end

--- Zeile mit Zahlenfeld (rechtsbündig).
function Builder.number_row(grid, caption, tooltip, value, action, allow_negative)
  row_label(grid, caption, tooltip)
  local field = grid.add({
    type = "textfield",
    style = "short_number_textfield",
    text = tostring(value),
    numeric = true,
    allow_decimal = false,
    allow_negative = allow_negative or false,
    lose_focus_on_confirm = true,
    tooltip = tooltip,
    tags = { utl_action = action },
  })
  field.style.horizontal_align = "right"
  field.style.width = 80
  return field
end

--- Zeile mit Textfeld.
function Builder.text_row(grid, caption, tooltip, value, action)
  row_label(grid, caption, tooltip)
  local field = grid.add({
    type = "textfield",
    text = value,
    lose_focus_on_confirm = true,
    tooltip = tooltip,
    tags = { utl_action = action },
  })
  field.style.width = 120
  return field
end

return Builder
