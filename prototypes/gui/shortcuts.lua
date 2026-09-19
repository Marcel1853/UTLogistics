-- Knopf in der Shortcut-Leiste (unten rechts) für das Manager-Fenster.
data:extend({
  {
    type = "shortcut",
    name = "utl-toggle-manager",
    action = "lua",
    toggleable = true,
    associated_control_input = "utl-toggle-manager",
    icon = "__base__/graphics/icons/locomotive.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/locomotive.png",
    small_icon_size = 64,
    order = "u[utl]-a[manager]",
  },
})
