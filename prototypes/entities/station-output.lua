-- Auftrags-Ausgabe (und Depot-Ausgabe, unten): kleiner Konstant-Kombinator neben der Haltestelle, an dem die laufende
-- Lieferung anliegt (beim Anbieter positiv, beim Abnehmer negativ). Der Spieler verdrahtet ihn
-- mit Filter-Greifarmen, Pumpen oder Anzeigen.
--
-- UTL setzt ihn selbst neben jede Station; er ist nicht baubar, nicht abbaubar und hat kein
-- Rezept. Er kollidiert nur mit Gleisen, passt also überall neben den Bahnsteig.
local C = require("prototypes.constants")

local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = C.station_output
entity.icon = nil
entity.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.tint } }
entity.minable = nil
entity.next_upgrade = nil
entity.fast_replaceable_group = nil
entity.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
entity.selection_priority = (entity.selection_priority or 50) + 10
entity.collision_box = { { -0.15, -0.15 }, { 0.15, 0.15 } }
entity.collision_mask = { layers = { rail = true } }
entity.hidden = true
entity.hidden_in_factoriopedia = true
entity.flags = { "player-creation", "not-rotatable", "not-deconstructable", "placeable-off-grid" }

-- Depot-Ausgabe: dasselbe Bauteil neben Depots, eigener Name und eigene Farbe – dort liegen keine
-- Aufträge an, sondern der Zug im Depot, freie Züge und Züge auf dem Heimweg.
local depot = table.deepcopy(entity)
depot.name = C.depot_output
depot.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.depot_tint } }
-- auch in der Welt grün (nur Grafik-Felder, keine Schatten/Leuchten)
local function tint_layers(sprite_def)
  if type(sprite_def) ~= "table" then return end
  if sprite_def.filename or sprite_def.filenames then
    if not sprite_def.draw_as_shadow and not sprite_def.draw_as_glow and not sprite_def.draw_as_light then
      sprite_def.tint = C.depot_tint
    end
    return
  end
  for _, child in pairs(sprite_def) do tint_layers(child) end
end
for key, value in pairs(depot) do
  if type(key) == "string" and key:sub(-7) == "sprites" then tint_layers(value) end
end

data:extend({ entity, depot })
