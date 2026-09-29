--- Feste Werte der Runtime-Stufe.
return {
  station_combinator = "utl-station-combinator",
  train_stop = "utl-train-stop",
  utl_port = "utl-port", -- nur mit Cargo Ships
  -- Haltestellen mit eingebauter UTL-Logik (UTL-Haltestelle, UTL-Hafen)
  utl_stops = { ["utl-train-stop"] = true, ["utl-port"] = true },
  station_output = "utl-station-output",
  depot_output = "utl-depot-output",
  network_combinator = "utl-network-combinator",


  -- Offene Stationsfenster alle N Heartbeats auffrischen (Standard-Takt 10 → 60 Ticks).
  gui_refresh_every = 6,

  -- Betriebsart einer Station. Bei „station“ entscheiden die Schalter Anbieter/Abnehmer
  -- (beide an = Puffer).
  modes = { "station", "depot", "fuel", "cleanup" },
}
