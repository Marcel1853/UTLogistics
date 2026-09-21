--- 0.0.4: Netzwerke werden als Stern verbunden (storage.network_links, je Oberfläche). Eine frühe
--- Entwicklerfassung speicherte Zusatznetze je Station (`cfg.networks`) – das Feld fällt weg.
--- Läuft einmal je Spielstand und vor on_configuration_changed, deshalb alles vorher prüfen.
if not storage then return end
storage.network_links = storage.network_links or {}
if storage.stations and storage.stations.by_unit then
  for _, station in pairs(storage.stations.by_unit) do
    if station.config then station.config.networks = nil end
  end
end
