--- Werte je Team (Force): Mehrere Teams auf einem Server können z. B. unterschiedliche Lade-Werte
--- haben. Fehlt ein Team-Wert, gilt der Kartenwert (Config). Einstellbar im UTL-Manager, Reiter
--- „Einstellungen“ – von den Team-Leitern (teams.lua). Gibt es keine Teams (alle Spieler in einer
--- Force), zählen nur die Kartenwerte.
local Config = require("scripts.core.config")
local Teams = require("scripts.core.teams")

local TeamConfig = {}

--- Team-Werte mit zugehöriger Karten-Einstellung (Standard) – Reihenfolge wie im Manager.
TeamConfig.KEYS = {
  { key = "load_timeout", setting = "utl-load-timeout" },
  { key = "unload_timeout", setting = "utl-unload-timeout" },
  { key = "timeout_mode", setting = "utl-timeout-mode" },
}

local function force_index(force)
  if type(force) == "number" then return force end
  return force and force.valid and force.index or nil
end

--- Wert für ein Team: eigener Wert (nur wenn es Teams gibt) oder der Kartenwert.
function TeamConfig.get(force, key)
  local index = force_index(force)
  local own = index and Teams.active() and storage.team_config[index]
  if own and own[key] ~= nil then return own[key] end
  local cfg = Config.get()
  return cfg and cfg[key]
end

--- Hat das Team einen eigenen Wert? (Ohne Teams zählen nur die Kartenwerte.)
function TeamConfig.is_own(force, key)
  local index = Teams.active() and force_index(force) or nil
  local own = index and storage.team_config[index]
  return own ~= nil and own[key] ~= nil
end

--- Eigenen Wert setzen; nil = zurück auf den Kartenwert.
function TeamConfig.set(force, key, value)
  local index = force_index(force)
  if not index then return end
  local own = storage.team_config[index] or {}
  own[key] = value
  storage.team_config[index] = next(own) and own or nil
end

--- Force gelöscht oder zusammengelegt: Werte der alten Force verwerfen.
function TeamConfig.forget(index)
  storage.team_config[index] = nil
end

return TeamConfig
