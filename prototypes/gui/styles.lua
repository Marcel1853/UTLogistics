-- GUI-Styles im Stil von LTN Combinator Modernized (Vanilla + flib).
local styles = data.raw["gui-style"].default

-- Symbol vor einer Einstellungszeile.
styles.utl_entry_sprite = {
  type = "image_style",
  parent = "image",
  size = 32,
  stretch_image_to_widget_size = true,
}

-- Rechtsbündiges Zahlenfeld einer Einstellungszeile.
styles.utl_entry_text = {
  type = "textbox_style",
  parent = "short_number_textfield",
  width = 80,
  horizontal_align = "right",
  horizontally_stretchable = "off",
}

-- Abschnitts-Überschrift („Allgemein“, „Anbieter“ …).
styles.utl_header_label = {
  type = "label_style",
  parent = "caption_label",
  top_margin = 4,
  bottom_margin = 4,
}

-- Kleiner grauer Knopf „auf Standard zurücksetzen“ vor jeder Zeile (nur aktiv, wenn geändert).
styles.utl_reset_button = {
  type = "button_style",
  parent = "tool_button",
  size = 20,
  padding = 0,
}

-- Beschriftung einer Einstellungszeile: feste Breite, damit alle Felder untereinander stehen.
styles.utl_entry_label = {
  type = "label_style",
  parent = "caption_label",
  width = 190,
  single_line = true,
}

-- Bestätigen / Verwerfen im Mengen-Editor.
styles.utl_confirm_button = {
  type = "button_style",
  parent = "green_button",
  size = 28,
  padding = 0,
  top_margin = 1,
}
styles.utl_cancel_button = {
  type = "button_style",
  parent = "red_button",
  size = 28,
  padding = 0,
  top_margin = 1,
}

-- Zahl unten rechts in einem Slot.
styles.utl_slot_count = {
  type = "label_style",
  parent = "count_label",
  size = 36,
  horizontal_align = "right",
  vertical_align = "bottom",
  right_padding = 2,
}
