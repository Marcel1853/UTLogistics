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
  -- „Neu in UTL“: das Wichtigste der aktuellen Version, verlinkt aus dem Update-Hinweis im Chat
  item("utl-news", "a1", nil, { tag = "[virtual-signal=signal-star]" }),
  -- Grundlagen: Haltestelle einrichten
  item("utl-train-stop", "b1", "stop_window", { tag = "[item=utl-train-stop]" }),
  item("utl-combinator", "b2", "combinator", { tag = "[item=utl-station-combinator]" }),
  item("utl-roles", "b3", "roles", { tag = "[item=locomotive]" }),
  item("utl-requests", "b4", "requests", { tag = "[virtual-signal=utl-request-threshold]" }),
  item("utl-values", "b5", "values", { tag = "[virtual-signal=signal-info]" }),
  item("utl-copy", "b6", "copy", { tag = "[item=blueprint]" }),
  -- besondere Stationen
  item("utl-depots", "c1", "depots", { tag = "[virtual-signal=utl-trains-free]" }),
  item("utl-fuel", "c2", "fuel", { tag = "[item=coal]" }),
  item("utl-cleanup", "c3", "cleanup", { tag = "[virtual-signal=utl-cleanup-all-items]" }),
  item("utl-cleanup-return", "c4", "cleanup_return", { indent = 2, tag = "[virtual-signal=signal-recycle]" }),
  item("utl-storage", "c5", "storage", { tag = "[item=steel-chest]" }),
  -- Netze
  item("utl-networks", "d1", "networks", { tag = "[virtual-signal=utl-network]" }),
  item("utl-network-links", "d2", "links", { indent = 2, tag = "[virtual-signal=utl-trains-borrowed]" }),
  item("utl-network-combinator", "d3", "network_combinator", { indent = 2, tag = "[item=utl-network-combinator]" }),
  -- Überblick
  item("utl-manager", "e1", "manager", { tag = "[img=utility/search]" }),
  item("utl-manager-networks", "e2", "manager_networks", { indent = 2, tag = "[item=radar]" }),
  item("utl-manager-inventory", "e3", "manager_inventory", { indent = 2, tag = "[item=iron-chest]" }),
})
