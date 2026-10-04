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
local YELLOW = "utility-science-pack"
local RAIL_ICON = "__base__/graphics/technology/automated-rail-transportation.png"
local CIRCUIT_ICON = "__base__/graphics/technology/circuit-network.png"

data:extend({
  upgrade("utl-loading-control", CIRCUIT_ICON, { "utl-train-logistics" }, 150, { RED, GREEN },
    { "utl-tech-effect.loading-control" }),
  -- Lager (Fortgeschrittene): Stationsart „Lager“
  upgrade("utl-storage", CIRCUIT_ICON, { "utl-loading-control", "chemical-science-pack" }, 200,
    { RED, GREEN, BLUE }, { "utl-tech-effect.storage" }),
  -- Mehr Waren je Lager: 8 → 12 → 16 → 20 (Wunsch Marcel; Wirkung in scripts/core/unlocks.lua)
  upgrade("utl-storage-2", CIRCUIT_ICON, { "utl-storage" }, 250, { RED, GREEN, BLUE },
    { "utl-tech-effect.storage-slots", "12" }),
  upgrade("utl-storage-3", CIRCUIT_ICON, { "utl-storage-2", "production-science-pack" }, 400,
    { RED, GREEN, BLUE, PURPLE }, { "utl-tech-effect.storage-slots", "16" }),
  upgrade("utl-storage-4", CIRCUIT_ICON, { "utl-storage-3", "utility-science-pack" }, 500,
    { RED, GREEN, BLUE, PURPLE, YELLOW }, { "utl-tech-effect.storage-slots", "20" }),
  upgrade("utl-networks-1", RAIL_ICON, { "utl-train-logistics" }, 100, { RED, GREEN },
    { "utl-tech-effect.networks", "1" }),
  upgrade("utl-networks-2", RAIL_ICON, { "utl-networks-1", "chemical-science-pack" }, 200, { RED, GREEN, BLUE },
    { "utl-tech-effect.networks", "2" }),
  upgrade("utl-networks-3", RAIL_ICON, { "utl-networks-2", "production-science-pack" }, 300,
    { RED, GREEN, BLUE, PURPLE }, { "utl-tech-effect.networks", "3" }),
})

-- Netz-Kombinator: gibt den Zustand eines Netzes als Signale aus (Bestand, Lager, Fehlmenge, Züge).
-- Echtes Bauteil, deshalb unlock-recipe statt „nothing“. Blaue Wissenschaft: das Rezept braucht
-- rote Schaltkreise (Plastik, also Öl).
local readout = upgrade("utl-network-combinator", CIRCUIT_ICON, { "utl-loading-control", "chemical-science-pack" }, 150,
  { RED, GREEN, BLUE }, nil)
readout.effects = { { type = "unlock-recipe", recipe = C.network_combinator } }
data:extend({ readout })
