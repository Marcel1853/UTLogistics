--- Alle Zahlenwerte einer Station an einer Stelle: Gruppe, Symbol, Standard, Grenzen.
--- Fenster, Standardwerte, Migration und Remote-API lesen nur diese Liste.
local Config = require("scripts.core.config")

local Fields = {}

--- Gruppen in Anzeige-Reihenfolge. `visible(cfg)` entscheidet, ob der Abschnitt erscheint.
Fields.groups = {
  {
    name = "common",
    visible = function() return true end,
    fields = {
      { key = "min_train_length", signal = "utl-min-train-length", default = 0, min = 0 },
      { key = "max_train_length", signal = "utl-max-train-length", default = 0, min = 0 },
      { key = "max_trains", signal = "utl-max-trains", default = 0, min = 0 },
    },
    toggles = {
      { key = "output", signal = "utl-station-output", setting = "station_output", research = "utl-loading-control" },
    },
  },
  {
    name = "provider",
    visible = function(cfg) return cfg.roles.provider end,
    fields = {
      { key = "provide_threshold", signal = "utl-provide-threshold", setting = "default_provide_threshold", min = 1 },
      { key = "provide_stack_threshold", signal = "utl-provide-stack-threshold", default = 0, min = 0 },
      { key = "provide_priority", signal = "utl-provide-priority", default = 0 },
      { key = "locked_slots", signal = "utl-locked-slots", default = 0, min = 0 },
    },
    -- Schalter (ja/nein) unter den Zahlen desselben Abschnitts
    toggles = {
      { key = "filter_load", signal = "utl-filter-load", setting = "wagon_filters", research = "utl-loading-control" },
    },
  },
  {
    name = "requester",
    visible = function(cfg) return cfg.roles.requester end,
    fields = {
      { key = "request_threshold", signal = "utl-request-threshold", setting = "default_request_threshold", min = 1 },
      { key = "request_stack_threshold", signal = "utl-request-stack-threshold", default = 0, min = 0 },
      { key = "request_priority", signal = "utl-request-priority", default = 0 },
    },
  },
  {
    name = "depot",
    visible = function(cfg) return cfg.roles.depot end,
    fields = {
      { key = "depot_priority", signal = "utl-depot-priority", default = 0 },
    },
  },
}

Fields.by_key = {}
Fields.toggles = {}
for _, group in ipairs(Fields.groups) do
  for _, field in ipairs(group.fields) do Fields.by_key[field.key] = field end
  for _, toggle in ipairs(group.toggles or {}) do Fields.toggles[toggle.key] = toggle end
end

--- Standardwert eines Schalters: die Map-Einstellung, solange die Station nichts eigenes sagt.
function Fields.toggle_default(toggle)
  local cfg = Config.get()
  return cfg and cfg[toggle.setting] == true
end

--- Standardwert eines Feldes (Schwellen kommen aus den Map-Einstellungen).
function Fields.default(field)
  if field.setting then return Config.get()[field.setting] end
  return field.default
end

--- Wert auf die Grenzen des Feldes bringen.
function Fields.clamp(field, value)
  value = math.floor(value)
  if field.min and value < field.min then value = field.min end
  return value
end

--- Fehlende Felder mit Standardwerten auffüllen.
function Fields.fill(cfg)
  for key, field in pairs(Fields.by_key) do
    if cfg[key] == nil then cfg[key] = Fields.default(field) end
  end
  for key, toggle in pairs(Fields.toggles) do
    if cfg[key] == nil then cfg[key] = Fields.toggle_default(toggle) end
  end
  cfg.requests = cfg.requests or {}       -- [slot] = { signal = SignalID, count = n }
  cfg.request_map = cfg.request_map or {} -- [key] = Menge (abgeleitet)
  -- Zusatznetze („auch in diesen Netzen“); leer = nur das Heimatnetz cfg.network
  cfg.networks = cfg.networks or {}
  -- Cleanup: was hier geleert werden darf. Standard wie früher: alles.
  cfg.cleanup = cfg.cleanup or { all_items = true, all_fluids = true, items = {}, fluids = {} }
  cfg.cleanup.items = cfg.cleanup.items or {}   -- [slot] = Item-Name
  cfg.cleanup.fluids = cfg.cleanup.fluids or {} -- [slot] = Flüssigkeits-Name
end

Fields.cleanup_item_slots = 10
Fields.cleanup_fluid_slots = 5

--- Nimmt eine Cleanup-Station diese Ware an? Zweiter Wert: ausdrücklich eingetragen (nicht nur
--- über „Alle Items“/„Alle Flüssigkeiten“) – solche Stationen werden bevorzugt.
function Fields.cleanup_accepts(cfg, kind, name)
  local cleanup = cfg.cleanup
  if not cleanup then return true, false end
  for _, entry in pairs(kind == "fluid" and cleanup.fluids or cleanup.items) do
    if entry == name then return true, true end
  end
  if kind == "fluid" then return cleanup.all_fluids == true, false end
  return cleanup.all_items == true, false
end

return Fields
