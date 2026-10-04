--- Was der Parameter-Planer abfragen kann, für welche Rolle es gilt und wie eine Antwort in die
--- Stationseinstellungen kommt.
local Fields = require("scripts.stations.fields")
local Requests = require("scripts.stations.requests")
local Settings = require("scripts.stations.settings-combinator")

local Ask = {}

-- Rollen-Nummern (settings-combinator.lua): 1 Anbieter, 2 aktiver Anbieter, 3 Abnehmer,
-- 4 Anbieter + Abnehmer, 5 Depot, 6 Tankstelle, 7 Cleanup, 8 Lager, 9 aktiver Anbieter + Abnehmer
local PROVIDER = { [1] = true, [2] = true, [4] = true, [9] = true }
local REQUESTER = { [3] = true, [4] = true, [9] = true }
local DEPOT = { [5] = true }

--- Abfragbare Punkte in Anzeige-Reihenfolge. kind: role | network | request | number | toggle.
--- `roles` = nur für diese Rollen sichtbar (nil = immer).
Ask.list = {
  { key = "role", kind = "role" },
  { key = "network", kind = "network" },
  { key = "request", kind = "request", roles = REQUESTER },
  { key = "min_train_length", kind = "number" },
  { key = "max_train_length", kind = "number" },
  { key = "max_trains", kind = "number" },
  { key = "provide_threshold", kind = "number", roles = PROVIDER },
  { key = "provide_priority", kind = "number", roles = PROVIDER },
  { key = "filter_load", kind = "toggle", roles = PROVIDER },
  { key = "request_threshold", kind = "number", roles = REQUESTER },
  { key = "request_priority", kind = "number", roles = REQUESTER },
  { key = "depot_priority", kind = "number", roles = DEPOT },
  { key = "output", kind = "toggle" },
}
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
    local r = cfg.requests and cfg.requests[1]
    local proto = r and r.signal and r.signal.type ~= "fluid" and prototypes.item[r.signal.name]
    if r and not (proto and proto.parameter) then return { signal = r.signal, count = r.count } end
    return { count = r and r.count or 0 } -- Platzhalter nicht vorbelegen
  end
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
      if value.signal and value.signal.name then
        Requests.set(cfg, 1, value.signal, math.max(0, value.count or 0))
      else
        Requests.set(cfg, 1, nil)
      end
    elseif entry and entry.kind == "toggle" then
      cfg[key] = value == true
    else
      local field = Fields.by_key[key]
      if field then cfg[key] = Fields.clamp(field, value) end
    end
  end
end

return Ask
