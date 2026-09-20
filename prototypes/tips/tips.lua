-- Tipps & Tricks (Wunsch Marcel): eigene Kategorie mit Beispielszenen. In den Szenen läuft UTL
-- selbst (mods = { "UTLogistics", "flib" }) – der Zug wird wirklich disponiert, beladen und entladen.
local code = require("prototypes.tips.simulation-code")

local function simulation(init)
  return { init = init, mods = { "UTLogistics", "flib" }, init_update_count = 60 }
end

local unlock = { type = "research", technology = "utl-train-logistics" }

-- Sofort sichtbar: ein Auslöser allein (Forschung) greift nicht, wenn die Technologie schon vor
-- dem Mod-Update erforscht war – dann blieben die Tipps für immer versteckt. Der Auslöser meldet
-- sie weiterhin als Vorschlag, sobald die Forschung fertig wird.
local function item(name, order, scene, extra)
  local entry = { type = "tips-and-tricks-item", name = name, category = "utl", order = order, indent = 1,
    trigger = unlock, starting_status = "unlocked", simulation = scene and simulation(code[scene]) }
  for key, value in pairs(extra or {}) do entry[key] = value end
  return entry
end

-- Nur Bedienung des Mods (Wunsch Marcel) – keine Tipps zum Gleisbau. Jeder Eintrag hat eine Szene.
data:extend({
  { type = "tips-and-tricks-item-category", name = "utl", order = "f-[trains]-z[utl]" },
  item("utl-overview", "a", "basic", { is_title = true, indent = 0 }),
  item("utl-train-stop", "b", "stop_window", { tag = "[item=utl-train-stop]" }),
  item("utl-combinator", "c", "combinator", { tag = "[item=utl-station-combinator]" }),
  item("utl-roles", "d", "roles"),
  item("utl-requests", "e", "requests"),
  item("utl-values", "f", "values"),
  item("utl-networks", "f2", "networks", { tag = "[virtual-signal=utl-network]" }),
  item("utl-depots", "g", "depots"),
  item("utl-fuel", "h", "fuel", { tag = "[item=coal]" }),
  item("utl-cleanup", "i", "cleanup"),
  item("utl-copy", "j", "copy", { tag = "[item=blueprint]" }),
  item("utl-manager", "k", "manager"),
})
