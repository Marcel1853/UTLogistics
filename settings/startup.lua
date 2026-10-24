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
  -- Aussehen der UTL-Signale: „classic“ = Fahrzeug-/Kisten-Symbole des Spiels mit Zeichen,
  -- „flat“ = eigene flache Symbole im Stil der Vanilla-Signale
  {
    type = "string-setting",
    name = "utl-signal-style",
    setting_type = "startup",
    default_value = "classic",
    allowed_values = { "classic", "flat" },
    order = "a-b",
  },
  -- Farbige Lampen oben an UTL-Haltestellen: blau = Zug kommt, grün = Zug steht da, gelb = nichts los,
  -- rot = Haltestelle ausgeschaltet (Farben einstellbar). Standard aus: am Mast nur ein paar Pixel groß –
  -- das Anzeigefeld am Kabel ist die Hauptanzeige. Aus: beim Laden werden alle Lampen entfernt.
  {
    type = "bool-setting",
    name = "utl-station-lamps",
    setting_type = "startup",
    default_value = false,
    order = "a-c",
  },
  -- Aussehen der UTL-Haltestelle: „vanilla“ = Grafik der Spiel-Haltestelle, „utl“ = eigenes 3D-Modell
  -- (Blender, tools/grafik) mit Verteilern hinter dem Gleis, „utl-compact“ = dasselbe ohne Verteiler, dafür mit
  -- den Vanilla-Teilen am Gleis; die Stationsfarbe bleibt bei allen frei wählbar
  {
    type = "string-setting",
    name = "utl-stop-style",
    setting_type = "startup",
    default_value = "vanilla",
    allowed_values = { "vanilla", "utl", "utl-compact" },
    order = "a-d",
  },
})
