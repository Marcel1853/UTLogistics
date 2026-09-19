local C = require("prototypes.constants")

local item = table.deepcopy(data.raw["item"]["arithmetic-combinator"])
item.name = C.station_combinator
item.icon = nil
item.icons = { { icon = "__base__/graphics/icons/arithmetic-combinator.png", tint = C.tint } }
item.place_result = C.station_combinator
item.subgroup = "train-transport"
item.order = "b[train-automation]-b[utl-station-combinator]"

data:extend({ item })
