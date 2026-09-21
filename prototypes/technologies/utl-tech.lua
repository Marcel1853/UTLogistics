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

-- Aufbau-Forschungen: Ladesteuerung (Wagenfilter + Auftrags-Ausgabe) und Zusatznetze in drei
-- Stufen. Die Wirkung prüft das Script (scripts/core/unlocks.lua); hier steht nur die Beschreibung.
-- Mit der Map-Einstellung „UTL-Funktionen brauchen Forschung“ = aus sind alle sofort frei.
local function upgrade(name, icon, prerequisites, count, packs, effect)
  local ingredients = {}
  for _, pack in ipairs(packs) do ingredients[#ingredients + 1] = { pack, 1 } end
  return {
    type = "technology",
    name = name,
    icons = { { icon = icon, icon_size = 256, tint = C.tint } },
    -- Endet der Name auf „-<Zahl>“, sucht Factorio sonst die Übersetzung ohne die Zahl
    -- (technology-name.utl-networks) – deshalb die Texte ausdrücklich setzen.
    localised_name = { "technology-name." .. name },
    localised_description = { "technology-description." .. name },
    effects = { { type = "nothing", effect_description = effect } },
    prerequisites = prerequisites,
    unit = { count = count, ingredients = ingredients, time = 30 },
  }
end

local RED, GREEN = "automation-science-pack", "logistic-science-pack"
local BLUE, PURPLE = "chemical-science-pack", "production-science-pack"
local RAIL_ICON = "__base__/graphics/technology/automated-rail-transportation.png"
local CIRCUIT_ICON = "__base__/graphics/technology/circuit-network.png"

data:extend({
  upgrade("utl-loading-control", CIRCUIT_ICON, { "utl-train-logistics" }, 150, { RED, GREEN },
    { "utl-tech-effect.loading-control" }),
  upgrade("utl-networks-1", RAIL_ICON, { "utl-train-logistics" }, 100, { RED, GREEN },
    { "utl-tech-effect.networks", "1" }),
  upgrade("utl-networks-2", RAIL_ICON, { "utl-networks-1", "chemical-science-pack" }, 200, { RED, GREEN, BLUE },
    { "utl-tech-effect.networks", "2" }),
  upgrade("utl-networks-3", RAIL_ICON, { "utl-networks-2", "production-science-pack" }, 300,
    { RED, GREEN, BLUE, PURPLE }, { "utl-tech-effect.networks", "3" }),
})
