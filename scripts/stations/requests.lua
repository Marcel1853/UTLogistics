--- Anforderungen, die direkt im Stationsfenster in Slots eingetragen werden
--- (wie die Signal-Slots bei LTN Combinator). Sie wirken wie ein Konstanten-Kombinator
--- mit negativen Werten am Eingang – nur ohne Verdrahtung.
local Util = require("scripts.lib.util")

local Requests = {}

Requests.slot_count = 20

--- Baut die Nachschlage-Tabelle [key] = Menge neu auf (nach jeder Änderung im Fenster).
function Requests.rebuild_map(cfg)
  local map = {}
  for _, request in pairs(cfg.requests) do
    local key = Util.signal_key(request.signal)
    if key and request.count > 0 then map[key] = (map[key] or 0) + request.count end
  end
  cfg.request_map = map
end

function Requests.set(cfg, slot, signal, count)
  if signal then
    cfg.requests[slot] = { signal = signal, count = count }
  else
    cfg.requests[slot] = nil
  end
  Requests.rebuild_map(cfg)
end

return Requests
