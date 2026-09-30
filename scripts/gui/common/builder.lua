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

return Builder
