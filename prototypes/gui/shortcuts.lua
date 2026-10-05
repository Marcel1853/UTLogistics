-- Knopf in der Shortcut-Leiste (unten rechts) für das Manager-Fenster.
data:extend({
  {
    type = "shortcut",
    name = "utl-toggle-manager",
    action = "lua",
    toggleable = true,
    associated_control_input = "utl-toggle-manager",
    -- UTL-Logo (aus thumbnail.png) statt der Lok – so unterscheidet man ihn vom Planer
    icon = "__UTLogistics__/graphics/icons/utl-logo.png",
    icon_size = 64,
    small_icon = "__UTLogistics__/graphics/icons/utl-logo.png",
    small_icon_size = 64,
    order = "u[utl]-a[manager]",
  },
})
