local C = require("prototypes.constants")

data:extend({
  {
    type = "recipe",
    name = C.train_stop,
    enabled = false,
    ingredients = {
      { type = "item", name = "train-stop", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = C.train_stop, amount = 1 } },
  },
})
