-- Eigene Registerkarte „Züge“ im Crafting-Menü, direkt nach „Logistik“.
-- Befüllt wird sie in data-final-fixes (prototypes/final-fixes/train-items.lua).
data:extend({
  {
    type = "item-group",
    name = "utl-trains",
    order = "ab",
    icon = "__base__/graphics/technology/railway.png",
    icon_size = 256,
  },
  { type = "item-subgroup", name = "utl-rails", group = "utl-trains", order = "a" },
  { type = "item-subgroup", name = "utl-rail-signals", group = "utl-trains", order = "b" },
  { type = "item-subgroup", name = "utl-train-stops", group = "utl-trains", order = "c" },
  { type = "item-subgroup", name = "utl-locomotives", group = "utl-trains", order = "d" },
  { type = "item-subgroup", name = "utl-wagons", group = "utl-trains", order = "e" },
  { type = "item-subgroup", name = "utl-train-circuits", group = "utl-trains", order = "f" },
})
