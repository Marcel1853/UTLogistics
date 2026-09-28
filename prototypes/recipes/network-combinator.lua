local C = require("prototypes.constants")

data:extend({
  {
    type = "recipe",
    name = C.network_combinator,
    enabled = false,
    ingredients = {
      { type = "item", name = "constant-combinator", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = C.network_combinator, amount = 1 } },
  },
})
