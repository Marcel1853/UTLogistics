-- Gleisteile der Vanilla-Haltestelle für das Aussehen „UTL kompakt“: nur Ausschnitte der Vanilla-Grafik
-- (train-stop-ground.png, je Richtung ein 386 × 377-Feld). Mastfuß (Dreieck) und Kasten davor gehören zum
-- Vanilla-Mast und hingen neben unserem Modell in der Luft – sie fallen weg. Wo ein Vanilla-Kabel zum Mast lief,
-- reicht der Ausschnitt bis an den Kabelkanal des Modells.
local FILE = "__base__/graphics/entity/train-stop/train-stop-ground.png"
local W, H = 386, 377
local BASE_SHIFT_Y = -0.75 / 32 -- wie in der Vanilla-Haltestelle

-- Ausschnitte { x, y, Breite, Höhe } im Feld der Richtung
local CUTS = {
  north = { { 0, 0, 132, 377 } },
  east = { { 0, 0, 386, 130 }, { 200, 130, 70, 35 } },
  south = { { 256, 0, 130, 377 } },
  west = { { 0, 276, 386, 101 }, { 86, 212, 33, 64 } },
}

local result = {}
for index, direction in ipairs({ "north", "east", "south", "west" }) do
  local layers = {}
  for _, cut in ipairs(CUTS[direction]) do
    local x, y, w, h = cut[1], cut[2], cut[3], cut[4]
    layers[#layers + 1] = {
      filename = FILE,
      x = (index - 1) * W + x,
      y = y,
      width = w,
      height = h,
      -- Mitte des Ausschnitts relativ zur Feldmitte, 64 Pixel je Feld (scale 0.5)
      shift = { (x + w / 2 - W / 2) / 64, (y + h / 2 - H / 2) / 64 + BASE_SHIFT_Y },
      scale = 0.5,
    }
  end
  result[direction] = { layers = layers }
end
return result
