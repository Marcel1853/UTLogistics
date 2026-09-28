--- Gleisstücke des Lasttest-Builders: Richtungen, Kurven, Abzweig und Einmündung (Factorio 2.x,
--- per Suche im Spiel ermittelt, docs/PLAN.md). Angaben relativ zu einem geraden Gleisstück.
local Track = {}

-- Richtungen: f = Fahrtrichtung, r = rechts davon, dir = Richtung (16er), rail = Richtung gerader Gleise
Track.O = {
  N = { f = { 0, -1 }, r = { 1, 0 }, dir = 0, rail = 0, left = "W", back = "S" },
  E = { f = { 1, 0 }, r = { 0, 1 }, dir = 4, rail = 4, left = "N", back = "W" },
  S = { f = { 0, 1 }, r = { -1, 0 }, dir = 8, rail = 0, left = "E", back = "N" },
  W = { f = { -1, 0 }, r = { 0, -1 }, dir = 12, rail = 4, left = "S", back = "E" },
}

-- { Name, Richtung, dx, dy } – die ersten 4 Stücke; *_END = Lage des folgenden geraden Stücks
-- 90°-Rechtskurve (nur N→E für die Einfahrt und E→S für die Ausfahrt des Abstellbahnhofs)
Track.RIGHT = {
  N = { { "curved-rail-a", 2, 0, -3 }, { "curved-rail-b", 2, 2, -8 }, { "curved-rail-b", 12, 6, -12 }, { "curved-rail-a", 12, 11, -14 } },
  E = { { "curved-rail-a", 6, 3, 0 }, { "curved-rail-b", 6, 8, 2 }, { "curved-rail-b", 0, 12, 6 }, { "curved-rail-a", 0, 14, 11 } },
}
-- Schräge Weichenstraße: waagerecht (Osten) → schräg (Südost) und Abzweig schräg → Osten.
Track.E_TO_SE = { { "curved-rail-a", 6, 3, 0 }, { "curved-rail-b", 6, 8, 2 } }       -- danach Schräge bei (11, 5)
Track.SE_TO_E = { { "curved-rail-b", 14, 3, 3 }, { "curved-rail-a", 14, 8, 5 } }     -- danach Gerade bei (11, 5)
Track.DIAGONAL_SE = 6 -- Richtung schräger gerader Gleise (Schritt 2, 2)

Track.DIVERGE = {
  N = { { "curved-rail-a", 2, 0, -3 }, { "half-diagonal-rail", 2, 2, -8 }, { "half-diagonal-rail", 2, 4, -12 }, { "curved-rail-a", 10, 6, -17 } },
  E = { { "curved-rail-a", 6, 3, 0 }, { "half-diagonal-rail", 6, 8, 2 }, { "half-diagonal-rail", 6, 12, 4 }, { "curved-rail-a", 14, 17, 6 } },
  S = { { "curved-rail-a", 10, 0, 3 }, { "half-diagonal-rail", 2, -2, 8 }, { "half-diagonal-rail", 2, -4, 12 }, { "curved-rail-a", 2, -6, 17 } },
  W = { { "curved-rail-a", 14, -3, 0 }, { "half-diagonal-rail", 6, -8, -2 }, { "half-diagonal-rail", 6, -12, -4 }, { "curved-rail-a", 6, -17, -6 } },
}
Track.MERGE = {
  N = { { "curved-rail-a", 8, 0, 3 }, { "half-diagonal-rail", 0, 2, 8 }, { "half-diagonal-rail", 0, 4, 12 }, { "curved-rail-a", 0, 6, 17 } },
  E = { { "curved-rail-a", 12, -3, 0 }, { "half-diagonal-rail", 4, -8, 2 }, { "half-diagonal-rail", 4, -12, 4 }, { "curved-rail-a", 4, -17, 6 } },
  S = { { "curved-rail-a", 0, 0, -3 }, { "half-diagonal-rail", 0, -2, -8 }, { "half-diagonal-rail", 0, -4, -12 }, { "curved-rail-a", 8, -6, -17 } },
  W = { { "curved-rail-a", 4, 3, 0 }, { "half-diagonal-rail", 4, 8, -2 }, { "half-diagonal-rail", 4, 12, -4 }, { "curved-rail-a", 12, 17, -6 } },
}

return Track
