-- Tastenkürzel für das Manager-Fenster (im Spiel unter Einstellungen → Steuerung änderbar).
data:extend({
  {
    type = "custom-input",
    name = "utl-toggle-manager",
    key_sequence = "CONTROL + SHIFT + U",
    -- Unter Linux fängt IBus Strg + Umschalt + U ab (Unicode-Eingabe) – deshalb eine zweite Taste.
    alternative_key_sequence = "CONTROL + ALT + U",
    order = "a",
  },
})
