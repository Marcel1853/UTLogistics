local C = require("prototypes.constants")

data:extend({
  {
    type = "technology",
    name = "utl-train-logistics",
    icons = {
      { icon = "__base__/graphics/technology/automated-rail-transportation.png", icon_size = 256, tint = C.tint },
    },
    effects = {
      { type = "unlock-recipe", recipe = C.train_stop },
      { type = "unlock-recipe", recipe = C.station_combinator },
    },
    prerequisites = { "automated-rail-transportation", "circuit-network" },
    unit = {
      count = 150,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
      time = 30,
    },
  },
})
