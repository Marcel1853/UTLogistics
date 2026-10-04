--- Was der Parameter-Planer abfragen kann, und wie eine Antwort in die Stationseinstellungen kommt.
local Fields = require("scripts.stations.fields")
local Requests = require("scripts.stations.requests")
local Settings = require("scripts.stations.settings-combinator")

local Ask = {}

--- Abfragbare Punkte in Anzeige-Reihenfolge. kind: "role" | "request" | "number".
Ask.list = {
  { key = "role", kind = "role" },
  { key = "request", kind = "request" },
  { key = "min_train_length", kind = "number" },
  { key = "max_train_length", kind = "number" },
  { key = "max_trains", kind = "number" },
  { key = "provide_threshold", kind = "number" },
  { key = "request_threshold", kind = "number" },
  { key = "provide_priority", kind = "number" },
  { key = "request_priority", kind = "number" },
}
Ask.by_key = {}
for _, entry in ipairs(Ask.list) do Ask.by_key[entry.key] = entry end

--- Aktueller Wert aus einer Einstellung (Vorbelegung im Abfrage-Fenster).
function Ask.current(cfg, key)
  if key == "role" then return Settings.role_code(cfg) end
  if key == "request" then
    local r = cfg.requests and cfg.requests[1]
    return r and { signal = r.signal, count = r.count } or { count = 0 }
  end
  return cfg[key] or 0
end

--- Antworten { [key] = Wert } auf eine Einstellung (Tabelle, wird verändert) anwenden.
function Ask.apply(cfg, answers)
  cfg.requests = cfg.requests or {}
  for key, value in pairs(answers) do
    if key == "role" then
      Settings.apply_role(cfg, value)
    elseif key == "request" then
      if value.signal and value.signal.name then
        Requests.set(cfg, 1, value.signal, math.max(0, value.count or 0))
      else
        Requests.set(cfg, 1, nil)
      end
    else
      local field = Fields.by_key[key]
      if field then cfg[key] = Fields.clamp(field, value) end
    end
  end
end

return Ask
