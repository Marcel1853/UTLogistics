-- Start-Einstellungen (brauchen Neustart des Spiels).
data:extend({
  -- Zug-Reiter im Crafting-Menü: „auto“ = eigener UTL-Reiter, außer eine andere Mod hat schon einen
  -- Zug-Reiter (dann kommen die UTL-Sachen dort hinein); „utl“ = immer der UTL-Reiter mit allen
  -- Zug-Sachen; „off“ = nichts umsortieren (UTL-Sachen im UTL-Reiter).
  -- Ersetzt den Schalter „utl-own-item-group“ (bis 0.0.9).
  {
    type = "string-setting",
    name = "utl-item-group",
    setting_type = "startup",
    default_value = "auto",
    allowed_values = { "auto", "utl", "off" },
    order = "a-a",
  },
})
