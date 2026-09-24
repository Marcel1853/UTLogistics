--- Zwischenspeicher der Map-Einstellungen, damit der Heißpfad nicht ständig
--- `settings.global[...]` abfragt.
---
--- Im UTL-Manager (Reiter „Einstellungen“) geänderte Kartenwerte liegen in
--- `storage.map_config[name]` und gelten statt des Menüwerts. UTL schreibt `settings.global`
--- absichtlich nicht: das Spiel meldet solche Änderungen ohne Spieler, und manche Mods stürzen
--- dabei ab (z. B. Modlist UI). Ändert jemand denselben Wert im Einstellungsmenü, gewinnt wieder
--- das Menü (events.lua löscht dann den Manager-Wert).
local Config = {}

-- Einstellung → Schlüssel im Zwischenspeicher
Config.KEYS = {
  ["utl-heartbeat-interval"] = "heartbeat_interval",
  ["utl-station-batch-size"] = "station_batch_size",
  ["utl-max-deliveries-per-cycle"] = "max_deliveries",
  ["utl-fuel-threshold"] = "fuel_threshold",
  ["utl-chaining"] = "chaining",
  ["utl-wagon-filters"] = "wagon_filters",
  ["utl-station-output"] = "station_output",
  ["utl-research-required"] = "research_required",
  ["utl-alert-no-train-minutes"] = "alert_no_train_minutes",
  ["utl-default-provide-threshold"] = "default_provide_threshold",
  ["utl-default-request-threshold"] = "default_request_threshold",
  ["utl-load-timeout"] = "load_timeout",
  ["utl-unload-timeout"] = "unload_timeout",
  ["utl-timeout-mode"] = "timeout_mode",
  ["utl-leader-inactive-days"] = "leader_inactive_days",
  ["utl-debug-log"] = "debug_log",
}

-- Wer auf geänderte Werte reagieren muss (z. B. Takt neu anmelden), meldet sich hier an.
local listeners = {}

--- `fn(setting_name)` nach jeder Änderung aufrufen (Menü oder Manager).
function Config.listen(fn)
  listeners[#listeners + 1] = fn
end

function Config.refresh()
  local s, own = settings.global, storage.map_config or {}
  local cfg = {}
  for name, key in pairs(Config.KEYS) do
    local value = own[name]
    if value == nil then value = s[name].value end
    cfg[key] = value
  end
  storage.cfg = cfg
end

--- Gültiger Wert einer Einstellung (Manager-Wert oder Menüwert).
function Config.value(name)
  local own = storage.map_config and storage.map_config[name]
  if own ~= nil then return own end
  return settings.global[name].value
end

--- Hat der Manager diesen Wert überschrieben?
function Config.is_own(name)
  return storage.map_config ~= nil and storage.map_config[name] ~= nil
end

--- Kartenwert aus dem Manager setzen (nil = wieder der Menüwert) und alle Beteiligten informieren.
function Config.set(name, value)
  storage.map_config = storage.map_config or {}
  if value == settings.global[name].value then value = nil end -- gleich dem Menü: nichts merken
  storage.map_config[name] = value
  Config.refresh()
  Config.changed(name)
end

--- Nach einer Änderung (Menü oder Manager) die angemeldeten Module benachrichtigen.
function Config.changed(name)
  for i = 1, #listeners do listeners[i](name) end
end

--- Nur lesen, auch in on_load erlaubt.
function Config.get()
  return storage.cfg
end

return Config
