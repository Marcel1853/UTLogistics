--- 0.0.3: Stationen bekommen Zusatznetze (`cfg.networks`). Bestehende Spielstände kennen das Feld
--- nicht; eine leere Menge bedeutet „verhält sich wie bisher“.
--- Läuft einmal je Spielstand und vor on_configuration_changed, deshalb prüfen wir alle Tabellen.
if not (storage and storage.stations and storage.stations.by_unit) then return end

for _, station in pairs(storage.stations.by_unit) do
  local cfg = station.config
  if cfg and cfg.networks == nil then cfg.networks = {} end
end
