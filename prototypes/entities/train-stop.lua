-- UTL-Haltestelle: normale Haltestelle mit UTL-Logik. Kisten direkt an die
-- Haltestelle anschließen. Gleiche Ersetzungsgruppe wie der Vanilla-Halt, so kann
-- man bestehende Halte einfach überbauen.
local C = require("prototypes.constants")

local entity = table.deepcopy(data.raw["train-stop"]["train-stop"])
entity.name = C.train_stop
entity.icon = nil
entity.icons = { { icon = "__base__/graphics/icons/train-stop.png", tint = C.tint } }
entity.minable = { mining_time = 0.2, result = C.train_stop }
entity.color = C.stop_color
entity.next_upgrade = nil

-- Aussehen (Start-Einstellung): eigenes 3D-Modell statt der Vanilla-Grafik. Der Ausleger liegt in
-- top_animations, damit Züge darunter durchfahren. Die Vanilla-Lampen (light1/light2) säßen neben den
-- Lampen des Modells und entfallen, ebenso die Vanilla-Kabel am Gleis (rail_overlay_animations) – das Modell
-- bringt eigene Kabel und Verteiler hinter dem Gleis mit.
if settings.startup["utl-stop-style"].value == "utl" then
  local sprites = require("prototypes.sprites.utl-train-stop")
  entity.animations = sprites.animations
  entity.top_animations = sprites.top_animations
  entity.light1 = nil
  entity.light2 = nil
  entity.rail_overlay_animations = nil
end

data:extend({ entity })
