-- Auftrags-Ausgabe: kleiner Konstant-Kombinator neben der Haltestelle, an dem die laufende
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

data:extend({ entity })
