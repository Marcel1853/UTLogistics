local C = require("prototypes.constants")

local item = table.deepcopy(data.raw["item"]["constant-combinator"])
item.name = C.network_combinator
item.icon = nil
item.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.network_tint } }
item.place_result = C.network_combinator
item.subgroup = "train-transport"
item.order = "b[train-automation]-c[utl-network-combinator]"

data:extend({ item })
