local C = require("prototypes.constants")

data:extend({
  {
    type = "recipe",
    name = C.network_combinator,
    enabled = false,
    ingredients = {
      { type = "item", name = "constant-combinator", amount = 1 },
      { type = "item", name = "advanced-circuit", amount = 5 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "steel-plate", amount = 5 },
      { type = "item", name = "copper-cable", amount = 10 },
    },
    results = { { type = "item", name = C.network_combinator, amount = 1 } },
  },
})
