--- Zeitmessung (für /utl-perf und den Lasttest): Für die nächsten N Heartbeats wird jede
--- Aufgabe und jedes Zug-Event mit helpers.create_profiler gemessen und ins Log geschrieben.
--- Ohne aktive Messung kostet das nur einen Vergleich.
local Perf = {}

function Perf.start(heartbeats)
  local hb = storage.heartbeat
  hb.profile_until = hb.count + heartbeats
end

function Perf.active()
  local hb = storage.heartbeat
  return hb.profile_until ~= nil and hb.count <= hb.profile_until
end

--- `fn(...)` ausführen und – wenn die Messung läuft – die Dauer protokollieren.
function Perf.measure(name, fn, ...)
  if not Perf.active() then return fn(...) end
  local profiler = helpers.create_profiler()
  fn(...)
  profiler.stop()
  log({ "", "[UTL][perf] tick ", game.tick, " ", name, ": ", profiler })
end

return Perf
