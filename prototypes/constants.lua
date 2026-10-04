-- Gemeinsame Werte für Prototypen (Namen, Farbe).
return {
  station_combinator = "utl-station-combinator",
  train_stop = "utl-train-stop",
  utl_port = "utl-port", -- nur mit Cargo Ships
  station_output = "utl-station-output",
  depot_output = "utl-depot-output",
  station_settings = "utl-station-settings", -- versteckter Einstellungs-Kombinator (Blaupausen-Parameter)
  network_combinator = "utl-network-combinator",
  -- Netz-Kombinator: bernsteinfarben, damit er sich vom (blauen) Stations-Combinator abhebt
  network_tint = { r = 1.0, g = 0.72, b = 0.3, a = 1.0 },
  tint = { r = 0.55, g = 0.8, b = 1.0, a = 1.0 },
  -- Depot-Ausgabe: grün, damit sie sich von der (blauen) Auftrags-Ausgabe abhebt
  depot_tint = { r = 0.5, g = 1.0, b = 0.55, a = 1.0 },
  stop_color = { r = 0.1, g = 0.55, b = 1.0, a = 1.0 },
}
