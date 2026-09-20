--- Ladefilter und Auftrags-Ausgabe: neue Felder je Station und zwei neue Tabellen im Speicher.
--- Läuft einmal je Spielstand und vor on_configuration_changed, deshalb alles vorher prüfen.
--- Die Ausgabe-Objekte selbst legt on_configuration_changed an (dort ist `game` sicher nutzbar).
if not storage then return end

if storage.trains then
  storage.trains.filtered = storage.trains.filtered or {}
end
if storage.deliveries then
  storage.deliveries.output_dirty = storage.deliveries.output_dirty or {}
end

if storage.stations and storage.stations.by_unit then
  for _, station in pairs(storage.stations.by_unit) do
    local cfg = station.config
    if cfg then
      -- Standard: beides an – wie in den Map-Einstellungen vorgegeben.
      if cfg.filter_load == nil then cfg.filter_load = true end
      if cfg.output == nil then cfg.output = true end
    end
  end
end
