--- Kasten im Vanilla-Stil: heller Rahmen mit dunkler Kopfleiste (Titel) und Inhalt mit Innenabstand.
--- Für die Manager-Reiter „Einstellungen“ und „Inventar“.
local Section = {}

--- Liefert `frame, title, body`: `title` ist das Label in der Kopfleiste (Text änderbar), `body` der Inhalt.
function Section.add(parent, caption)
  local frame = parent.add({ type = "frame", style = "inside_shallow_frame", direction = "vertical" })
  frame.style.horizontally_stretchable = true
  local head = frame.add({ type = "frame", style = "subheader_frame" })
  head.style.horizontally_stretchable = true
  local title = head.add({ type = "label", style = "subheader_caption_label", caption = caption })
  local body = frame.add({ type = "flow", direction = "vertical" })
  body.style.padding = { 8, 12, 12, 12 }
  body.style.vertical_spacing = 6
  return frame, title, body
end

return Section
