-- 0.0.10: Umbauten aus sehr alten Spielständen, die bisher state.lua erledigt hat (state.lua ergänzt
-- nur noch fehlende Tabellen, Regel 4):
--   storage.trains.refueling → storage.trains.service
--   storage.fuel_stations    → storage.service_stations.fuel
-- Läuft je Spielstand einmal, vor on_configuration_changed – Tabellen können fehlen.
local trains = storage.trains
if trains and trains.refueling then
  trains.service = trains.service or trains.refueling
  trains.refueling = nil
end
if storage.fuel_stations then
  storage.service_stations = storage.service_stations or {}
  storage.service_stations.fuel = storage.service_stations.fuel or storage.fuel_stations
  storage.fuel_stations = nil
end
