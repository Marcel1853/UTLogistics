-- Update-Test: Spielstand einer älteren UTL-Version mit dem neuen Stand laden und prüfen, dass
-- Stationen erhalten bleiben und Lieferungen weiterlaufen. Ausgabe: „[UPD] …“-Zeilen.
local function log_line(text) log("[UPD] " .. text) end

local function snapshot()
  local stats = remote.call("utl", "get_statistics") --[[@as table]]
  return {
    stations = remote.call("utl", "station_count"),
    deliveries = remote.call("utl", "delivery_count"),
    done = stats.deliveries,
  }
end

script.on_nth_tick(60, function(event)
  storage.upd = storage.upd or {}
  local u = storage.upd
  if not u.start then
    u.start = event.tick
    u.first = snapshot()
    log_line(("geladen: Stationen %d, laufende Lieferungen %d"):format(u.first.stations, u.first.deliveries))
  elseif not u.ended and event.tick - u.start >= 60 * 60 * 3 then
    u.ended = true
    local last = snapshot()
    local ok = last.stations == u.first.stations and last.done > u.first.done
    log_line(("nach 3 min: Stationen %d → %d, fertige Lieferungen %d → %d, laufend %d"):format(
      u.first.stations, last.stations, u.first.done, last.done, last.deliveries))
    log_line(ok and "PASS" or "FAIL")
  end
end)
