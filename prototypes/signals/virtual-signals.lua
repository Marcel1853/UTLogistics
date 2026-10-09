-- Eigene Signale für die Stationswerte (wie bei LTN). Sie dienen als Symbole im Fenster
-- und können später auch per Schaltung gesetzt werden.
local ICONS = "__base__/graphics/icons/"

--- Eigene Zeichnung aus graphics/icons/signals (selbst gezeichnet, siehe
--- tools/make_signal_icons.py).
local function own(name)
  return { { icon = "__UTLogistics__/graphics/icons/signals/" .. name .. ".png", icon_size = 64 } }
end

local function icon(base, overlay)
  return {
    { icon = ICONS .. base, icon_size = 64 },
    { icon = ICONS .. "signal/" .. overlay, icon_size = 64, scale = 0.28, shift = { 8, 8 } },
  }
end

--- Wie icon(), aber mit einem Pfeil aus icons/arrows als kleinem Zeichen.
local function arrow(base, overlay)
  return {
    { icon = ICONS .. base, icon_size = 64 },
    { icon = ICONS .. "arrows/" .. overlay, icon_size = 64, scale = 0.28, shift = { 8, 8 } },
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
  { "utl-fuel-request", arrow("coal.png", "signal-input.png") },
  { "utl-network", icon("radar.png", "signal_N.png") },
  -- UTL-Logo als Signal (Schaltungen, Anzeigen, Kartenmarker)
  { "utl-logo", { { icon = "__UTLogistics__/graphics/icons/utl-logo.png", icon_size = 64 } } },
  -- Rolle als Zahl (Einstellungs-Kombinator, Blaupausen-Parameter): 1 Anbieter … 9 aktiver Anbieter + Abnehmer
  { "utl-role", icon("train-stop.png", "signal_R.png") },
  { "utl-station-output", icon("constant-combinator.png", "signal-lightning.png") },
  -- Depot-Ausgabe: Garage mit Blitz
  { "utl-depot-output", { { icon = "__UTLogistics__/graphics/icons/signals/depot-garage.png", icon_size = 64 },
    { icon = ICONS .. "signal/signal-lightning.png", icon_size = 64, scale = 0.28, shift = { 8, 8 } } } },
  { "utl-train-id", own("train-id") },
  { "utl-train-length", own("train-length") },
  { "utl-train-locos", own("train-locos") },
  { "utl-train-wagons", own("train-wagons") },
  { "utl-cleanup-all-items", icon("cargo-wagon.png", "signal_everything.png") },
  { "utl-cleanup-all-fluids", icon("fluid-wagon.png", "signal_everything.png") },
  -- Auftrags-Ausgabe: 1, solange ein Zug hier lädt bzw. entlädt (z. B. um Lade- und Entlade-Greifarme zu schalten)
  { "utl-loading", arrow("cargo-wagon.png", "signal-input.png") },
  { "utl-unloading", arrow("cargo-wagon.png", "signal-output.png") },
  -- Auftrags-Ausgabe: so viele Lieferzüge fahren gerade zu dieser Station
  { "utl-trains-incoming", icon("locomotive.png", "signal-map-marker.png") },
  -- Netz-Kombinator, Modus „Züge“
  { "utl-trains-total", icon("locomotive.png", "signal_everything.png") },
  { "utl-trains-free", own("depot-garage") }, -- Garage aus „Train Control Signals“ (MIT, siehe LICENSE-…)
  { "utl-trains-busy", icon("locomotive.png", "signal-speed.png") },
  { "utl-deliveries", icon("cargo-wagon.png", "signal-number-sign.png") },
  { "utl-trains-low-fuel", own("fuel-pump") },  -- Zapfsäule aus „Train Control Signals“ (MIT)
  -- unter dem Mindest-Treibstoff: Zapfsäule mit Verbotszeichen
  { "utl-trains-no-fuel", { { icon = "__UTLogistics__/graphics/icons/signals/fuel-pump.png", icon_size = 64 },
    { icon = ICONS .. "signal/signal-deny.png", icon_size = 64, scale = 0.28, shift = { 8, 8 } } } },
  { "utl-trains-no-path", icon("locomotive.png", "signal-deny.png") },
  -- Netzverbund: fremde Züge helfen hier aus / eigene Züge helfen anderswo aus
  { "utl-trains-borrowed", arrow("locomotive.png", "signal-input.png") },
  { "utl-trains-lent", arrow("locomotive.png", "signal-output.png") },
}

-- Stil „Flach“ (Start-Einstellung utl-signal-style): eigene Grundbilder im Stil der Vanilla-Signale
-- (graphics/icons/signals/flat, gezeichnet mit tools/grafik/signals.py, Mipmaps im Bild) und – falls
-- angegeben – ein Vanilla-Signal als Zusatzzeichen unten rechts in halber Größe (per Verweis).
local function flat(base, folder, badge)
  local icons = { { icon = "__UTLogistics__/graphics/icons/signals/flat/" .. base .. ".png", icon_size = 64 } }
  if badge then
    icons[2] = { icon = ICONS .. folder .. "/" .. badge .. ".png", icon_size = 64, scale = 0.25, shift = { 8, 8 } }
  end
  return icons
end
local FLAT = {
  ["utl-min-train-length"] = flat("cargo-wagon", "signal", "signal-greater-than-or-equal-to"),
  ["utl-max-train-length"] = flat("cargo-wagon", "signal", "signal-less-than-or-equal-to"),
  ["utl-max-trains"] = flat("loco", "signal", "signal-number-sign"),
  ["utl-provide-threshold"] = flat("provider-chest", "signal", "signal-greater-than-or-equal-to"),
  ["utl-provide-stack-threshold"] = flat("provider-chest", "signal", "signal-stack-size"),
  ["utl-provide-priority"] = flat("provider-chest", "signal", "signal-star"),
  ["utl-locked-slots"] = flat("cargo-wagon", "signal", "signal-lock"),
  ["utl-filter-load"] = flat("cargo-wagon", "signal", "signal-checked-green"),
  ["utl-request-threshold"] = flat("requester-chest", "signal", "signal-greater-than-or-equal-to"),
  ["utl-request-stack-threshold"] = flat("requester-chest", "signal", "signal-stack-size"),
  ["utl-request-priority"] = flat("requester-chest", "signal", "signal-star"),
  ["utl-fuel-request"] = flat("fuel-pump-flat", "arrows", "signal-input"),
  ["utl-depot-priority"] = flat("depot-garage-flat", "signal", "signal-star"),
  ["utl-network"] = flat("network"),
  ["utl-role"] = flat("train-stop", "signal", "signal_R"),
  ["utl-station-output"] = flat("output", "signal", "signal-lightning"),
  ["utl-depot-output"] = flat("depot-garage-flat", "signal", "signal-lightning"),
  ["utl-train-id"] = flat("train-id"),
  ["utl-train-length"] = flat("train-length"),
  ["utl-train-locos"] = flat("train-locos"),
  ["utl-train-wagons"] = flat("train-wagons"),
  ["utl-cleanup-all-items"] = flat("cargo-wagon", "signal", "signal_everything"),
  ["utl-cleanup-all-fluids"] = flat("fluid-wagon", "signal", "signal_everything"),
  ["utl-loading"] = flat("cargo-wagon", "arrows", "signal-input"),
  ["utl-unloading"] = flat("cargo-wagon", "arrows", "signal-output"),
  ["utl-trains-incoming"] = flat("loco", "signal", "signal-map-marker"),
  ["utl-trains-total"] = flat("loco", "signal", "signal_everything"),
  ["utl-trains-free"] = flat("depot-garage-flat"),
  ["utl-trains-busy"] = flat("loco", "signal", "signal-speed"),
  ["utl-deliveries"] = flat("cargo-wagon", "signal", "signal-number-sign"),
  ["utl-trains-low-fuel"] = flat("fuel-pump-flat"),
  ["utl-trains-no-fuel"] = flat("fuel-pump-flat", "signal", "signal-deny"),
  ["utl-trains-no-path"] = flat("loco", "signal", "signal-deny"),
  ["utl-trains-borrowed"] = flat("loco", "arrows", "signal-input"),
  ["utl-trains-lent"] = flat("loco", "arrows", "signal-output"),
}
if settings.startup["utl-signal-style"].value == "flat" then
  for _, def in ipairs(SIGNALS) do def[2] = FLAT[def[1]] or def[2] end
end

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

-- Schnittstelle für andere Mods: eigene Symbole für UTL-Signale. Eine Mod (Abhängigkeit auf
-- UTLogistics) trägt in data.lua oder data-updates.lua ein:
--   data.raw["mod-data"]["utl-signal-icons"].data["utl-loading"] = { { icon = "__meine-mod__/…png", icon_size = 64 } }
-- Je Stil eigene Symbole: = { classic = { … }, flat = { … } } (eins darf fehlen, dann bleibt UTLs).
-- UTL übernimmt die Einträge in data-final-fixes (prototypes/final-fixes/signal-icons.lua) – eine
-- einfache Liste gilt für beide Stile. Zur Laufzeit: prototypes.mod_data["utl-signal-icons"].
data:extend({ { type = "mod-data", name = "utl-signal-icons", data_type = "utl-signal-icons", data = {} } })

