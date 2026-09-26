-- Wende-Greifarm: Kopie des Bulk-Greifarms, blau eingefärbt. Er arbeitet so, wie er gebaut wurde;
-- ist seine Schaltbedingung erfüllt, dreht UTL ihn um (scripts/inserters/). So kann ein Bahnhof,
-- der annimmt und abgibt, mit einem Satz Greifarme auskommen.
local C = require("prototypes.constants")

local function tint_layers(sprite_def)
  if type(sprite_def) ~= "table" then return end
  if sprite_def.filename or sprite_def.filenames then
    if not sprite_def.draw_as_shadow and not sprite_def.draw_as_glow and not sprite_def.draw_as_light then
      sprite_def.tint = C.tint
    end
    return
  end
  for _, child in pairs(sprite_def) do tint_layers(child) end
end

local ICONS = {
  { icon = "__base__/graphics/icons/bulk-inserter.png", tint = C.tint },
  { icon = "__base__/graphics/icons/arrows/signal-left-right-arrow.png", scale = 0.28, shift = { 8, -8 } },
}

local entity = table.deepcopy(data.raw["inserter"]["bulk-inserter"])
entity.name = C.reversible_inserter
entity.icon = nil
entity.icons = ICONS
entity.minable = { mining_time = 0.1, result = C.reversible_inserter }
entity.next_upgrade = nil
-- Nur die Grafik färben, keine Schatten (eigene Liste: Greifarme heißen nicht „…sprites“)
for _, key in ipairs({ "hand_base_picture", "hand_open_picture", "hand_closed_picture", "platform_picture" }) do
  tint_layers(entity[key])
end

local item = table.deepcopy(data.raw["item"]["bulk-inserter"])
item.name = C.reversible_inserter
item.icon = nil
item.icons = ICONS
item.place_result = C.reversible_inserter
item.order = (item.order or "f") .. "-u[utl-reversible]"

data:extend({
  entity,
  item,
  {
    type = "recipe",
    name = C.reversible_inserter,
    enabled = false,
    ingredients = {
      { type = "item", name = "bulk-inserter", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = C.reversible_inserter, amount = 1 } },
  },
})
