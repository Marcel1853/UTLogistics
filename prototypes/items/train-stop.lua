local C = require("prototypes.constants")

local item = table.deepcopy(data.raw["item"]["train-stop"])
item.name = C.train_stop
item.icon = nil
item.icons = { { icon = "__base__/graphics/icons/train-stop.png", tint = C.tint } }
item.place_result = C.train_stop
item.order = "b[train-automation]-a[utl-train-stop]"

data:extend({ item })
