-- UTL-Netz-Kombinator: Kopie des Konstant-Kombinators, bernsteinfarben. Gibt den Zustand eines
-- UTL-Netzes als Signale aus (Bestand, Lagerbestand, Fehlmenge oder Zugzahlen); die Werte setzt
-- das Script (scripts/readout/), das Fenster ersetzt UTL durch ein eigenes.
local C = require("prototypes.constants")

local function tint_layers(sprite_def)
  if type(sprite_def) ~= "table" then return end
  if sprite_def.filename or sprite_def.filenames then
    if not sprite_def.draw_as_shadow and not sprite_def.draw_as_glow and not sprite_def.draw_as_light then
      sprite_def.tint = C.network_tint
    end
    return
  end
  for _, child in pairs(sprite_def) do
    tint_layers(child)
  end
end

local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = C.network_combinator
entity.icon = nil
entity.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.network_tint } }
entity.minable = { mining_time = 0.1, result = C.network_combinator }
entity.fast_replaceable_group = nil
entity.next_upgrade = nil

-- Nur Grafik-Felder einfärben (Schlüssel enden auf „sprites“), keine Sounds.
for key, value in pairs(entity) do
  if type(key) == "string" and key:sub(-7) == "sprites" then
    tint_layers(value)
  end
end

data:extend({ entity })
