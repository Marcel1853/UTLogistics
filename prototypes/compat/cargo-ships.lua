-- Cargo Ships (Wunsch aus der Portal-Diskussion): ein UTL-Hafen, gebaut aus dem Hafen der
-- installierten Mod. Nichts wird einkopiert – die Grafiken kommen aus cargo-ships-graphics
-- (LGPL v3), das Cargo Ships immer mitbringt. Ohne Cargo Ships gibt es den UTL-Hafen nicht.
if not mods["cargo-ships"] then return end
local port = data.raw["train-stop"]["port"]
local port_item = data.raw["item"]["port"]
if not (port and port_item) then return end

local C = require("prototypes.constants")

-- Symbol des Hafens mit UTL-Tönung (Hafen-Symbol: icon + icon_size oder icons)
local function tinted_icons(source)
  if source.icons then
    local icons = table.deepcopy(source.icons)
    for _, layer in pairs(icons) do layer.tint = C.tint end
    return icons
  end
  return { { icon = source.icon, icon_size = source.icon_size, tint = C.tint } }
end

local entity = table.deepcopy(port)
entity.name = C.utl_port
entity.icons = tinted_icons(port)
entity.icon, entity.icon_size = nil, nil
entity.minable = { mining_time = 1, result = C.utl_port }
entity.color = C.stop_color
entity.next_upgrade = nil

local item = table.deepcopy(port_item)
item.name = C.utl_port
item.icons = tinted_icons(port_item)
item.icon, item.icon_size = nil, nil
item.place_result = C.utl_port
item.order = (port_item.order or "") .. "-u[utl-port]"

local recipe = {
  type = "recipe",
  name = C.utl_port,
  enabled = false,
  ingredients = {
    { type = "item", name = "port", amount = 1 },
    { type = "item", name = "electronic-circuit", amount = 10 },
    { type = "item", name = "steel-plate", amount = 5 },
    { type = "item", name = "copper-cable", amount = 10 },
  },
  results = { { type = "item", name = C.utl_port, amount = 1 } },
}

data:extend({ entity, item, recipe })

local SWAP_ICONS = {
  { icon = "__base__/graphics/icons/rail.png", icon_size = 64, scale = 0.32, shift = { -6, -6 } },
  { icon = "__cargo-ships-graphics__/graphics/icons/water_rail.png", icon_size = 64, scale = 0.32, shift = { 6, 6 } },
  { icon = "__base__/graphics/icons/arrows/signal-rightwards-leftwards-arrow.png", icon_size = 64, scale = 0.2,
    shift = { 8, -8 } },
}

-- Knopf „Blaupause: Gleis ↔ Wasserweg“ (scripts/compat/cargo-ships.lua); Symbol aus der
-- installierten Grafik-Mod (Verweis, keine Kopie)
data:extend({
  {
    type = "shortcut",
    name = "utl-blueprint-water",
    action = "lua",
    -- Gleis oben links, Doppelpfeil oben rechts, Wasserweg (blauer Pfeil von Cargo Ships) unten rechts
    icons = SWAP_ICONS,
    small_icons = SWAP_ICONS,
    order = "u[utl]-b[blueprint-water]",
  },
})

-- Freigeschaltet mit der Forschung, die auch den Hafen von Cargo Ships bringt (vorher fehlt die
-- Zutat „port“); ohne sie mit „Unified Train Logistics“ wie die UTL-Haltestelle
local tech = data.raw["technology"]["automated_water_transport"] or data.raw["technology"]["utl-train-logistics"]
if tech then
  tech.effects = tech.effects or {}
  table.insert(tech.effects, { type = "unlock-recipe", recipe = C.utl_port })
end
