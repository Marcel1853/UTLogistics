--- Was der Parameter-Planer abfragen kann, für welche Rolle es gilt und wie eine Antwort in die
--- Stationseinstellungen kommt.
local Fields = require("scripts.stations.fields")
local Requests = require("scripts.stations.requests")
local Settings = require("scripts.stations.settings-combinator")

local Ask = {}

-- Rollen-Nummern (settings-combinator.lua): 1 Anbieter, 2 aktiver Anbieter, 3 Abnehmer,
-- 4 Anbieter + Abnehmer, 5 Depot, 6 Tankstelle, 7 Cleanup, 8 Lager, 9 aktiver Anbieter + Abnehmer
local PROVIDER = { [1] = true, [2] = true, [4] = true, [9] = true }
local REQUEST_SLOT = { [3] = true, [4] = true, [6] = true, [9] = true } -- Tankstelle: Treibstoff anfordern
local DEPOT = { [5] = true }
local FUEL = { [6] = true }
local CLEANUP = { [7] = true }
local STORAGE = { [8] = true }

Ask.CLEANUP_OFFER = { "off", "reserve", "normal", "first" }

--- Abfragbare Punkte in Anzeige-Reihenfolge. kind: role | network | request | number | toggle.
--- `roles` = nur für diese Rollen sichtbar (nil = immer).
Ask.list = {
  { key = "role", kind = "role", tab = "general" },
  { key = "network", kind = "network", tab = "general" },
  { key = "fuel_request", kind = "toggle", roles = FUEL, tab = "goods" },
  { key = "request", kind = "request", roles = REQUEST_SLOT, tab = "goods" },
  { key = "min_train_length", kind = "number", tab = "general" },
  { key = "max_train_length", kind = "number", tab = "general" },
  { key = "max_trains", kind = "number", tab = "general" },
  { key = "provide_threshold", kind = "number", roles = PROVIDER, tab = "values", group = "provider" },
  { key = "provide_stack_threshold", kind = "number", roles = PROVIDER, tab = "values", group = "provider" },
  { key = "provide_priority", kind = "number", roles = PROVIDER, tab = "values", group = "provider" },
  { key = "locked_slots", kind = "number", roles = PROVIDER, tab = "values", group = "provider" },
  { key = "filter_load", kind = "toggle", roles = PROVIDER, tab = "values", group = "provider" },
  { key = "request_threshold", kind = "number", roles = REQUEST_SLOT, tab = "values", group = "requester" },
  { key = "request_stack_threshold", kind = "number", roles = REQUEST_SLOT, tab = "values", group = "requester" },
  { key = "request_priority", kind = "number", roles = REQUEST_SLOT, tab = "values", group = "requester" },
  { key = "depot_priority", kind = "number", roles = DEPOT, tab = "values" },
  { key = "cleanup_all_items", kind = "toggle", roles = CLEANUP, tab = "goods" },
  { key = "cleanup_all_fluids", kind = "toggle", roles = CLEANUP, tab = "goods" },
  { key = "cleanup_offer", kind = "offer", roles = CLEANUP, tab = "goods" },
  { key = "storage_limits", kind = "limits", roles = STORAGE, tab = "goods" },
  { key = "storage_leftover", kind = "toggle", roles = STORAGE, tab = "goods" },
  { key = "output", kind = "toggle", tab = "general" },
}
Ask.TABS = { "general", "goods", "values" }
Ask.by_key = {}
for _, entry in ipairs(Ask.list) do Ask.by_key[entry.key] = entry end

--- Gehört der Punkt zur Rolle `code`?
function Ask.relevant(key, code)
  local entry = Ask.by_key[key]
  return entry ~= nil and (entry.roles == nil or entry.roles[code] == true)
end

--- Aktueller Wert aus einer Einstellung (Vorbelegung im Abfrage-Fenster).
function Ask.current(cfg, key)
  local entry = Ask.by_key[key]
  if key == "role" then return Settings.role_code(cfg) end
  if key == "network" then return cfg.network or "default" end
  if key == "request" then
    -- alle belegten Anforderungs-Slots der Reihe nach; Platzhalter (parameter-0 …) zählen als leer
    local rows = {}
    local by_slot = {}
    for key, r in pairs(cfg.requests or {}) do
      local n = tonumber(key)
      if n then by_slot[n] = r end -- auch Text-Schlüssel („3“) aus dem Blaupausen-Textformat
    end
    for slot = 1, Requests.slot_count do
      local r = by_slot[slot]
      local proto = r and r.signal and r.signal.type ~= "fluid" and prototypes.item[r.signal.name]
      if r and r.signal and not (proto and proto.parameter) then
        rows[#rows + 1] = { signal = r.signal, count = r.count }
      end
    end
    return rows
  end
  local cleanup = cfg.cleanup or {}
  if key == "cleanup_all_items" then return cleanup.all_items ~= false end
  if key == "cleanup_all_fluids" then return cleanup.all_fluids ~= false end
  if key == "cleanup_offer" then return cleanup.offer or "off" end
  if key == "storage_limits" then return (cfg.storage and cfg.storage.limits) or {} end
  if key == "storage_leftover" then return not (cfg.storage and cfg.storage.accept_leftover == false) end
  if entry and entry.kind == "toggle" then return cfg[key] == true end
  return cfg[key] or 0
end

--- Antworten { [key] = Wert } auf eine Einstellung (Tabelle, wird verändert) anwenden.
function Ask.apply(cfg, answers)
  cfg.requests = cfg.requests or {}
  for key, value in pairs(answers) do
    local entry = Ask.by_key[key]
    if key == "role" then
      Settings.apply_role(cfg, value)
    elseif key == "network" then
      if type(value) == "string" and value ~= "" then cfg.network = value end
    elseif key == "request" then
      -- Zeilen mit Ware der Reihe nach in die Slots, der Rest wird geleert
      cfg.requests = {}
      local slot = 0
      for _, row in ipairs(value) do
        if row.signal and row.signal.name and slot < Requests.slot_count then
          slot = slot + 1
          cfg.requests[slot] = { signal = row.signal, count = math.max(0, row.count or 0) }
        end
      end
      Requests.rebuild_map(cfg)
    elseif key == "cleanup_all_items" or key == "cleanup_all_fluids" then
      cfg.cleanup = cfg.cleanup or {}
      cfg.cleanup[key == "cleanup_all_items" and "all_items" or "all_fluids"] = value == true
    elseif key == "cleanup_offer" then
      cfg.cleanup = cfg.cleanup or {}
      if value ~= "off" then cfg.cleanup.offer_tier = value end
      cfg.cleanup.offer = value ~= "off" and value or false
    elseif key == "storage_leftover" then
      cfg.storage = cfg.storage or {}
      cfg.storage.accept_leftover = value == true
    elseif key == "storage_limits" then
      cfg.storage = cfg.storage or {}
      cfg.storage.limits = value
    elseif entry and entry.kind == "toggle" then
      cfg[key] = value == true
    else
      local field = Fields.by_key[key]
      if field then cfg[key] = Fields.clamp(field, value) end
    end
  end
end

return Ask
