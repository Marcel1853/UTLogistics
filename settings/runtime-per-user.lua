-- Spieler-Einstellungen: Warnungen (wie bei LTN) pro Gruppe abschaltbar.
data:extend({
  {
    type = "bool-setting",
    name = "utl-alerts-no-train",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a-a",
  },
  {
    type = "bool-setting",
    name = "utl-alerts-cargo",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a-b",
  },
  {
    type = "bool-setting",
    name = "utl-alerts-trains",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a-c",
  },
  -- Nach einem Update eine kurze Zeile im Chat, was neu ist (mit Link auf Tipps & Tricks)
  {
    type = "bool-setting",
    name = "utl-news",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b-a",
  },
  -- Größe des UTL-Managers (Inhalt in Pixeln bei 100 % UI-Skalierung); zu groß für den Bildschirm → kleiner
  {
    type = "int-setting",
    name = "utl-manager-width",
    setting_type = "runtime-per-user",
    default_value = 1040,
    minimum_value = 800,
    maximum_value = 3000,
    order = "c-a",
  },
  {
    type = "int-setting",
    name = "utl-manager-height",
    setting_type = "runtime-per-user",
    default_value = 620,
    minimum_value = 450,
    maximum_value = 2000,
    order = "c-b",
  },
})
