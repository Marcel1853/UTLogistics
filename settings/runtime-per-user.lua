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
})
