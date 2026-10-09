-- Eigenes Signal im passenden UTL-Signal-Stil (Doku: Wiki „Signal-Symbole“)
local style = settings.startup["utl-signal-style"]
local flat = style and style.value == "flat"
data:extend({ {
  type = "virtual-signal",
  name = "utl-addontest-siding",
  icon = flat and "__base__/graphics/icons/signal/signal-stack-size.png" or "__base__/graphics/icons/rail.png",
  icon_size = 64,
  subgroup = "virtual-signal",
  order = "z[utl-addontest]",
} })
