--- Feste Werte der Runtime-Stufe.
return {
  station_combinator = "utl-station-combinator",
  train_stop = "utl-train-stop",
  station_output = "utl-station-output",


  -- Offene Stationsfenster alle N Heartbeats auffrischen (Standard-Takt 10 → 60 Ticks).
  gui_refresh_every = 6,

  -- Betriebsart einer Station. Bei „station“ entscheiden die Schalter Anbieter/Abnehmer
  -- (beide an = Puffer).
  modes = { "station", "depot", "fuel", "cleanup" },
}
