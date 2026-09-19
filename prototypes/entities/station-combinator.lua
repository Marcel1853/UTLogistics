-- UTL-Stations-Combinator: Kopie des Rechen-Kombinators, blau eingefärbt.
-- Der Eingang liest den Lagerbestand bzw. Bedarf der Station. Die Rechenfunktion
-- bleibt leer, das Fenster ersetzt UTL durch ein eigenes.
local C = require("prototypes.constants")

local function tint_layers(sprite_def)
  if type(sprite_def) ~= "table" then return end
  if sprite_def.filename or sprite_def.filenames then
    if not sprite_def.draw_as_shadow and not sprite_def.draw_as_glow and not sprite_def.draw_as_light then
      sprite_def.tint = C.tint
    end
    return
  end
  for _, child in pairs(sprite_def) do
    tint_layers(child)
  end
end

local entity = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])
entity.name = C.station_combinator
entity.icon = nil
entity.icons = { { icon = "__base__/graphics/icons/arithmetic-combinator.png", tint = C.tint } }
entity.minable = { mining_time = 0.1, result = C.station_combinator }
entity.fast_replaceable_group = nil
entity.next_upgrade = nil
-- Reines Logik-Bauteil: braucht keinen Strom (kein „Kein Strom“-Symbol, keine Leitung nötig).
entity.energy_source = { type = "void" }

-- Nur Grafik-Felder einfärben (Schlüssel enden auf „sprites“), keine Sounds.
for key, value in pairs(entity) do
  if type(key) == "string" and key:sub(-7) == "sprites" then
    tint_layers(value)
  end
end

data:extend({ entity })
