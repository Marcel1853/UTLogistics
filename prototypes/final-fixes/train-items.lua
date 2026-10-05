-- Sortiert alle Zug-Items in die UTL-Registerkarte – auch die anderer Mods.
-- Erkannt wird über den Typ der platzierten Entity, nicht über Namen.
-- Einstellung „utl-item-group“: auto (Standard) | utl | off – siehe settings/startup.lua.
local mode = settings.startup["utl-item-group"].value
if mode == "off" then return end

local C = require("prototypes.constants")
local GROUP = "utl-trains"
local ITEM_TYPES = { "item", "item-with-entity-data", "rail-planner" }

--- Reiter und Zeile, in der ein Item gerade liegt.
local function place_of(item)
  local subgroup = item and data.raw["item-subgroup"][item.subgroup or ""]
  return subgroup and subgroup.group, subgroup and subgroup.name
end

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

-- Automatisch: Liegt die Lok schon in einem fremden Reiter (weder „Logistik“ noch UTL), hat eine
-- andere Mod einen eigenen Zug-Reiter (z. B. Train Construction Site). Dann nichts umsortieren und
-- die UTL-Sachen dort zu den Haltestellen legen – ein Reiter statt zwei, die sich streiten.
if mode == "auto" then
  local loco = data.raw["item-with-entity-data"]["locomotive"] or data.raw["item"]["locomotive"]
  local foreign = place_of(loco)
  if foreign and foreign ~= "logistics" and foreign ~= GROUP then
    local stop_group, stop_subgroup = place_of(data.raw["item"]["train-stop"])
    local _, loco_subgroup = place_of(loco)
    local target = stop_group == foreign and stop_subgroup or loco_subgroup
    local ours = {}
    for name, subgroup in pairs(data.raw["item-subgroup"]) do
      if subgroup.group == GROUP then ours[name] = true end
    end
    -- alles in UTL-Zeilen und alle eigenen UTL-Items (Kombinatoren, Hafen …) mitnehmen
    for _, item_type in ipairs(ITEM_TYPES) do
      for name, item in pairs(data.raw[item_type] or {}) do
        if (item.subgroup and ours[item.subgroup]) or (string.sub(name, 1, 4) == "utl-" and not item.hidden) then
          item.subgroup = target
        end
      end
    end
    for _, recipe in pairs(data.raw["recipe"]) do
      if recipe.subgroup and ours[recipe.subgroup] then recipe.subgroup = target end
    end
    -- Zug-Sachen, die der fremde Reiter nicht mitnimmt (z. B. Hochbahn-Rampe und -Stütze), dazulegen:
    -- Schienen-Artiges zu den Schienen, der Rest zu den Haltestellen
    local _, rail_subgroup = place_of(data.raw["rail-planner"]["rail"])
    for _, item_type in ipairs(ITEM_TYPES) do
      for _, item in pairs(data.raw[item_type] or {}) do
        local kind = item.place_result and subgroup_by_entity[item.place_result]
        if kind and not item.hidden and not item.parameter and place_of(item) ~= foreign then
          item.subgroup = (kind == "utl-rails" and rail_subgroup) or target
        end
      end
    end
    -- UTL-Reiter entfernen, wenn nichts mehr darin liegt
    local used = false
    for _, prototypes in pairs(data.raw) do
      for _, prototype in pairs(prototypes) do
        if type(prototype) == "table" and prototype.subgroup and ours[prototype.subgroup] then used = true end
      end
    end
    if not used then
      for name in pairs(ours) do data.raw["item-subgroup"][name] = nil end
      data.raw["item-group"][GROUP] = nil
    end
    log("UTL: fremder Zug-Reiter „" .. foreign .. "“ erkannt – UTL-Sachen nach „" .. tostring(target)
      .. "“, UTL-Reiter " .. (used and "bleibt" or "entfernt"))
    return
  end
end

-- Zug-Steuerung, die kein Zug-Typ ist (eigene + bekannte Mods).
local TRAIN_CIRCUITS = {
  C.station_combinator,
  C.network_combinator,
  "ltn-combinator",                                                     -- LTN Combinator Modernized
  "smart-train-combinator", "stc-multi", "stc2-buffer-probe", "stc-typed-probe", -- Smart Train Combinator
}
for _, name in ipairs(TRAIN_CIRCUITS) do
  subgroup_by_entity[name] = "utl-train-circuits"
end

local moved = {} -- [item-name] = subgroup
local was = {}   -- [item-name] = Zeile vor dem Umzug (für Rezepte, die ihrem Item folgen)
for _, item_type in ipairs(ITEM_TYPES) do
  for name, item in pairs(data.raw[item_type] or {}) do
    local place_result = item.place_result
    local subgroup = place_result and subgroup_by_entity[place_result]
    if not subgroup and item_type == "rail-planner" then subgroup = "utl-rails" end
    if subgroup and not item.hidden and not item.parameter then
      was[name] = item.subgroup
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
local KEEP_GROUPS = { signals = true, environment = true, effects = true, other = true, [GROUP] = true }
for name, subgroup in pairs(data.raw["item-subgroup"]) do
  local total, trains = in_subgroup[name] or 0, train_in_subgroup[name] or 0
  if total > 0 and trains == total and not KEEP_GROUPS[subgroup.group] then
    subgroup.group = GROUP
    subgroup.order = "z-" .. (subgroup.order or name)
  end
end

-- Rezepte mit fest eingetragener Zeile ebenfalls umziehen (sonst bleiben sie im alten Reiter) – aber
-- nur, wenn sie in derselben Zeile standen wie ihr Item. Rezepte, die eine andere Mod bewusst in eine
-- eigene Zeile legt, bleiben dort: Voidcraft z. B. baut zu jedem eigenen Rezept eine Kopie in der
-- Zeile „<zeile>-qual“ und legt diese Zeilen nur für seine eigenen an („utl-rails-qual“ gäbe es nicht).
for _, recipe in pairs(data.raw["recipe"]) do
  if recipe.subgroup and recipe.results then
    local main = recipe.main_product or (#recipe.results == 1 and recipe.results[1].name)
    if main and moved[main] and recipe.subgroup == was[main] then recipe.subgroup = moved[main] end
  end
end
