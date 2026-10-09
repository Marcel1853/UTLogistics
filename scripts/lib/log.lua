--- Protokoll in factorio-current.log. Debug-Ausgaben nur mit Einstellung „utl-debug-log“.
local Config = require("scripts.core.config")

local Log = {}

function Log.info(message)
  log("[UTL] " .. message)
end

--- Ist das Debug-Protokoll an? An häufig durchlaufenen Stellen vorher fragen, damit der Text
--- ohne Debug gar nicht erst gebaut wird (Regel 5).
function Log.on()
  local cfg = Config.get()
  return cfg ~= nil and cfg.debug_log == true
end

function Log.debug(message)
  if Log.on() then
    log("[UTL][debug] " .. message)
  end
end

-- Schon gemeldete Schlüssel (nur für das Protokoll, nicht in storage: beeinflusst das Spiel nicht)
local said = {}

--- Debug-Meldung nur einmal je Schlüssel (z. B. je Haltestelle), damit das Protokoll nicht volläuft.
function Log.debug_once(key, message)
  if said[key] or not Log.on() then return end
  said[key] = true
  log("[UTL][debug] " .. message)
end

--- Name einer Haltestelle für das Protokoll (auch ungültig oder nil).
function Log.stop_name(stop)
  if not (stop and stop.valid) then return "(ungültig)" end
  return "„" .. stop.backer_name .. "“ (" .. stop.unit_number .. ")"
end

return Log
