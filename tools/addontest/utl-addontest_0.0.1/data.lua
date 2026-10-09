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

-- UTL-Signale mit eigenen Symbolen (Doku: Wiki „Signal-Symbole“), nur zum Testen Flüssigkeiten:
--   Laden: je Stil verschieden · Entladen: nur im flachen Stil · Lieferungen: für beide Stile gleich
local fluid = function(name) return { { icon = "__base__/graphics/icons/fluid/" .. name .. ".png", icon_size = 64 } } end
local icons = data.raw["mod-data"]["utl-signal-icons"].data
icons["utl-loading"] = { classic = fluid("water"), flat = fluid("crude-oil") }
icons["utl-unloading"] = { flat = fluid("steam") }
icons["utl-deliveries"] = fluid("lubricant")
