-- Parameter-Planer: Auswahl-Werkzeug wie der Blaupausen-Planer. Bereich ziehen → Fenster: was beim
-- Platzieren abgefragt werden soll → fertige Blaupause im Cursor. Beim Platzieren fragt UTL die
-- Werte in einem kleinen Fenster ab (scripts/parameter/). Kommt über den Knopf in der Shortcut-Leiste.
local C = require("prototypes.constants")

local ICONS = { { icon = "__base__/graphics/icons/blueprint.png", icon_size = 64, tint = C.tint } }
local SELECT = { border_color = { r = 0.3, g = 0.75, b = 1 }, cursor_box_type = "copy", mode = { "blueprint", "any-entity" },
  ignore_cannot_select_tiles = true } -- 2.1: „blueprint“ schließt Entities/Kacheln nicht mehr ein

data:extend({
  {
    type = "selection-tool",
    name = "utl-param-planner",
    icons = ICONS,
    flags = { "only-in-cursor", "not-stackable", "spawnable" },
    subgroup = "tool",
    order = "z[utl]-a[param-planner]",
    stack_size = 1,
    select = SELECT,
    alt_select = SELECT,
  },
  {
    type = "shortcut",
    name = "utl-param-planner",
    action = "spawn-item",
    item_to_spawn = "utl-param-planner",
    icon = "__base__/graphics/icons/blueprint.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/blueprint.png",
    small_icon_size = 64,
    order = "u[utl]-c[param-planner]",
  },
})
