-- Einstellungs-Kombinator: unsichtbarer Konstant-Kombinator auf jeder Station. In ausgeschalteten
-- Abschnitten (geben nichts aufs Kabel) stehen Anforderungen, Rolle und Werte der Station. So
-- erkennt Factorio darin Blaupausen-Parameter und fragt sie beim Platzieren ab; UTL liest die
-- gewählten Werte danach zurück (scripts/stations/settings-combinator.lua).
--
-- Unsichtbar, nicht anklickbar, kollidiert mit nichts (liegt auf der Haltestelle), kein Kabel.
local C = require("prototypes.constants")

local EMPTY = { filename = "__core__/graphics/empty.png", size = 1, priority = "extra-high" }
local EMPTY4 = { north = EMPTY, east = EMPTY, south = EMPTY, west = EMPTY }

local entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
entity.name = C.station_settings
entity.icon = nil
entity.icons = { { icon = "__base__/graphics/icons/constant-combinator.png", tint = C.tint } }
entity.minable = nil
entity.next_upgrade = nil
entity.fast_replaceable_group = nil
entity.selection_box = nil
entity.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
entity.collision_mask = { layers = {} }
entity.sprites = EMPTY4
entity.activity_led_sprites = EMPTY4
entity.circuit_wire_max_distance = 0
entity.draw_circuit_wires = false
entity.draw_copper_wires = false
entity.hidden = true
entity.hidden_in_factoriopedia = true
entity.flags = { "player-creation", "not-rotatable", "not-deconstructable", "placeable-off-grid",
  "not-selectable-in-game", "not-on-map", "not-flammable" }
-- wie bei der Ausgabe: nur mit Item kommt er in Blaupausen (prototypes/entities/station-output.lua)
entity.placeable_by = { item = entity.name, count = 1 }

data:extend({
  entity,
  {
    type = "item",
    name = entity.name,
    icons = entity.icons,
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = { "only-in-cursor" },
    subgroup = "circuit-network",
    order = "z[utl]-" .. entity.name,
    place_result = entity.name,
    stack_size = 1,
  },
})
