--- Anzeigefelder mit Erklärtext an den Bahnhöfen des Beispiel-Szenarios (Schlüssel = Lage der
--- Haltestelle in der Blaupause, wie in build.lua). Je ein Feld vor der Haltestelle.
local Signs = require("__UTLogistics__/scripts/lib/signs")

-- Lage der Haltestelle → Sprachschlüssel utl-sign.<key>
local TEXTS = {
  ["65/3"] = "bsp-mixed", ["115/3"] = "bsp-workshop", ["69/19"] = "fuel-low", ["115/19"] = "bsp-copper",
  ["11/41"] = "bsp-depot", ["137/61"] = "bsp-depot2", ["79/83"] = "bsp-tanks", ["33/83"] = "bsp-oil",
  ["33/99"] = "bsp-water", ["83/99"] = "cleanup",
}

-- Vorwärtsvektor je Fahrtrichtung der Haltestelle
local AHEAD = { [0] = { 0, -1 }, [4] = { 1, 0 }, [8] = { 0, 1 }, [12] = { -1, 0 } }

return function(stops)
  local placed = 0
  for key, text in pairs(TEXTS) do
    local stop = stops[key]
    if stop and stop.valid then
      local f = AHEAD[stop.direction] or AHEAD[0]
      if Signs.place(stop.surface, { stop.position.x + 3 * f[1], stop.position.y + 3 * f[2] }, text,
        { type = "item", name = "utl-train-stop" }) then
        placed = placed + 1
      end
    end
  end
  return placed
end
