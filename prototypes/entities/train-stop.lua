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

data:extend({ entity })
