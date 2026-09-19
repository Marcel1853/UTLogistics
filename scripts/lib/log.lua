--- Protokoll in factorio-current.log. Debug-Ausgaben nur mit Einstellung „utl-debug-log“.
local Config = require("scripts.core.config")

local Log = {}

function Log.info(message)
  log("[UTL] " .. message)
end

function Log.debug(message)
  local cfg = Config.get()
  if cfg and cfg.debug_log then
    log("[UTL][debug] " .. message)
  end
end

return Log
