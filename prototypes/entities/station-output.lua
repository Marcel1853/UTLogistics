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
-- drehbar: sonst lassen sich Blaupausen mit UTL-Haltestellen nicht drehen
entity.flags = { "player-creation", "not-deconstructable", "placeable-off-grid" }

-- Depot-Ausgabe: dasselbe Bauteil neben Depots, eigener Name und eigene Farbe – dort liegen keine
-- Aufträge an, sondern der Zug im Depot, freie Züge und Züge auf dem Heimweg.
local depot = table.deepcopy(entity)
depot.name = C.depot_output
depot.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.depot_tint } }
-- Eigenes Aussehen (immer, unabhängig von der Haltestellen-Einstellung): Schaltkasten aus Blender mit Kennfarbe
-- im Bild (Auftrags-Ausgabe blau, Depot-Ausgabe grün), Anschlusspunkte der Signalkabel auf den Isolatoren des
-- Modells. Die Leuchte des Vanilla-Kombinators säße woanders und entfällt.
local function own_look(e, file)
  local s = require("prototypes.sprites." .. file)
  e.sprites = s.animations
  e.circuit_wire_connection_points = s.circuit_wire_connection_points
  e.activity_led_sprites = nil
end
own_look(entity, "utl-station-output")
own_look(depot, "utl-depot-output")

-- Unsichtbares Item ohne Rezept: Factorio nimmt nur Gebäude mit Item in Blaupausen auf. So kommt
-- die Ausgabe samt Kabeln mit; bauen kann den Geist niemand (das Item hat keiner) – UTL baut ihn
-- selbst auf, sobald die Haltestelle steht (scripts/stations/output.lua, Output.ensure).
-- Anzahl 0: Die Blaupause verlangt das Item nicht (sonst stand es dort als fehlend).
local items = {}
for _, e in ipairs({ entity, depot }) do
  e.placeable_by = { item = e.name, count = 0 }
  items[#items + 1] = {
    type = "item",
    name = e.name,
    icons = e.icons,
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = { "only-in-cursor" },
    subgroup = "circuit-network",
    order = "z[utl]-" .. e.name,
    place_result = e.name,
    stack_size = 1,
  }
end

data:extend({ entity, depot })
data:extend(items)
