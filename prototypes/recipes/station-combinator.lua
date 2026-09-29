local C = require("prototypes.constants")

data:extend({
  {
    type = "recipe",
    name = C.station_combinator,
    enabled = false,
    ingredients = {
      { type = "item", name = "arithmetic-combinator", amount = 1 },
      { type = "item", name = "decider-combinator", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "iron-plate", amount = 5 },
      { type = "item", name = "copper-cable", amount = 10 },
    },
    results = { { type = "item", name = C.station_combinator, amount = 1 } },
  },
})
