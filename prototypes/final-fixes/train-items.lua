-- Sortiert alle Zug-Items in die UTL-Registerkarte – auch die anderer Mods.
-- Erkannt wird über den Typ der platzierten Entity, nicht über Namen.
if not settings.startup["utl-own-item-group"].value then return end

local C = require("prototypes.constants")

-- Entity-Typ → Zeile in der Registerkarte.
local SUBGROUP_BY_ENTITY_TYPE = {
  ["straight-rail"] = "utl-rails",
  ["curved-rail-a"] = "utl-rails",
  ["curved-rail-b"] = "utl-rails",
  ["half-diagonal-rail"] = "utl-rails",
  ["legacy-straight-rail"] = "utl-rails",
  ["legacy-curved-rail"] = "utl-rails",
  ["elevated-straight-rail"] = "utl-rails",
  ["elevated-curved-rail-a"] = "utl-rails",
  ["elevated-curved-rail-b"] = "utl-rails",
  ["elevated-half-diagonal-rail"] = "utl-rails",
  ["rail-ramp"] = "utl-rails",
  ["rail-support"] = "utl-rails",
  ["rail-signal"] = "utl-rail-signals",
  ["rail-chain-signal"] = "utl-rail-signals",
  ["train-stop"] = "utl-train-stops",
  ["locomotive"] = "utl-locomotives",
  ["cargo-wagon"] = "utl-wagons",
  ["fluid-wagon"] = "utl-wagons",
  ["artillery-wagon"] = "utl-wagons",
  ["infinity-cargo-wagon"] = "utl-wagons",
}

-- Entity-Name → Zeile (einmal aufbauen, dann nur nachschlagen).
local subgroup_by_entity = {}
for entity_type, subgroup in pairs(SUBGROUP_BY_ENTITY_TYPE) do
  for name in pairs(data.raw[entity_type] or {}) do
    subgroup_by_entity[name] = subgroup
  end
end
-- Zug-Steuerung, die kein Zug-Typ ist (eigene + bekannte Mods).
local TRAIN_CIRCUITS = {
  C.station_combinator,
  "ltn-combinator",                                                     -- LTN Combinator Modernized
  "smart-train-combinator", "stc-multi", "stc2-buffer-probe", "stc-typed-probe", -- Smart Train Combinator
}
for _, name in ipairs(TRAIN_CIRCUITS) do
  subgroup_by_entity[name] = "utl-train-circuits"
end

local ITEM_TYPES = { "item", "item-with-entity-data", "rail-planner" }

local moved = {} -- [item-name] = subgroup
for _, item_type in ipairs(ITEM_TYPES) do
  for name, item in pairs(data.raw[item_type] or {}) do
    local place_result = item.place_result
    local subgroup = place_result and subgroup_by_entity[place_result]
    if not subgroup and item_type == "rail-planner" then subgroup = "utl-rails" end
    if subgroup and not item.hidden and not item.parameter then
      item.subgroup = subgroup
      moved[name] = subgroup
    end
  end
end

-- Ganze Zeilen anderer Mods umhängen – aber nur, wenn dort **ausschließlich** Zug-Items stehen
-- (z. B. Zugfabriken, Train Construction Site). Früher entschied der Name („train“/„rail“), das
-- riss auch gemischte Zeilen fremder Mods aus ihrem Reiter.
local in_subgroup, train_in_subgroup = {}, {}
for _, item_type in ipairs(ITEM_TYPES) do
  for name, item in pairs(data.raw[item_type] or {}) do
    local group = item.subgroup
    if group and not item.hidden and not item.parameter then
      in_subgroup[group] = (in_subgroup[group] or 0) + 1
      local place_result = item.place_result
      if (place_result and subgroup_by_entity[place_result]) or item_type == "rail-planner" or moved[name] then
        train_in_subgroup[group] = (train_in_subgroup[group] or 0) + 1
      end
    end
  end
end
local KEEP_GROUPS = { signals = true, environment = true, effects = true, other = true, ["utl-trains"] = true }
for name, subgroup in pairs(data.raw["item-subgroup"]) do
  local total, trains = in_subgroup[name] or 0, train_in_subgroup[name] or 0
  if total > 0 and trains == total and not KEEP_GROUPS[subgroup.group] then
    subgroup.group = "utl-trains"
    subgroup.order = "z-" .. (subgroup.order or name)
  end
end

-- Rezepte mit fest eingetragener Zeile ebenfalls umziehen (sonst bleiben sie im alten Reiter).
for _, recipe in pairs(data.raw["recipe"]) do
  if recipe.subgroup and recipe.results then
    local main = recipe.main_product or (#recipe.results == 1 and recipe.results[1].name)
    if main and moved[main] then recipe.subgroup = moved[main] end
  end
end
