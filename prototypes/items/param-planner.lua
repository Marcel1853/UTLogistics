-- Parameter-Planer: Auswahl-Werkzeug wie der Blaupausen-Planer. Bereich ziehen → Fenster: was beim
-- Platzieren abgefragt werden soll → fertige Blaupause im Cursor. Beim Platzieren fragt UTL die
-- Werte in einem kleinen Fenster ab (scripts/parameter/). Kommt über den Knopf in der Shortcut-Leiste.

-- UTL-Logo (aus thumbnail.png) mit dem Parameter-Zeichen des Spiels unten rechts
local ICONS = {
  { icon = "__UTLogistics__/graphics/icons/utl-logo.png", icon_size = 64 },
  { icon = "__base__/graphics/icons/parameter/parameter-0.png", icon_size = 64, scale = 0.25, shift = { 8, 8 } },
}
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
    icons = ICONS,
    small_icons = ICONS,
    order = "u[utl]-c[param-planner]",
  },
})
