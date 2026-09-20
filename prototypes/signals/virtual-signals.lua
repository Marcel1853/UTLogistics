-- Eigene Signale für die Stationswerte (wie bei LTN). Sie dienen als Symbole im Fenster
-- und können später auch per Schaltung gesetzt werden.
local ICONS = "__base__/graphics/icons/"

local function icon(base, overlay)
  return {
    { icon = ICONS .. base, icon_size = 64 },
    { icon = ICONS .. "signal/" .. overlay, icon_size = 64, scale = 0.28, shift = { 8, 8 } },
  }
end

local SIGNALS = {
  { "utl-min-train-length", icon("cargo-wagon.png", "signal-greater-than-or-equal-to.png") },
  { "utl-max-train-length", icon("cargo-wagon.png", "signal-less-than-or-equal-to.png") },
  { "utl-max-trains", icon("locomotive.png", "signal-number-sign.png") },
  { "utl-provide-threshold", icon("passive-provider-chest.png", "signal-greater-than-or-equal-to.png") },
  { "utl-provide-stack-threshold", icon("passive-provider-chest.png", "signal-stack-size.png") },
  { "utl-provide-priority", icon("passive-provider-chest.png", "signal-star.png") },
  { "utl-locked-slots", icon("cargo-wagon.png", "signal-lock.png") },
  { "utl-filter-load", icon("cargo-wagon.png", "signal-checked-green.png") },
  { "utl-request-threshold", icon("requester-chest.png", "signal-greater-than-or-equal-to.png") },
  { "utl-request-stack-threshold", icon("requester-chest.png", "signal-stack-size.png") },
  { "utl-request-priority", icon("requester-chest.png", "signal-star.png") },
  { "utl-depot-priority", icon("train-stop.png", "signal-star.png") },
  { "utl-network", icon("radar.png", "signal_N.png") },
  { "utl-station-output", icon("constant-combinator.png", "signal-lightning.png") },
  { "utl-cleanup-all-items", icon("cargo-wagon.png", "signal_everything.png") },
  { "utl-cleanup-all-fluids", icon("fluid-wagon.png", "signal_everything.png") },
}

local prototypes = {
  { type = "item-subgroup", name = "utl-signals", group = "signals", order = "z-utl" },
}
for i, def in ipairs(SIGNALS) do
  prototypes[#prototypes + 1] = {
    type = "virtual-signal",
    name = def[1],
    icons = def[2],
    subgroup = "utl-signals",
    order = string.format("a-%02d", i),
  }
end
data:extend(prototypes)
