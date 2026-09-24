--- Erreichbarkeits-Cache: Kann ein Zug aus Depot A die Haltestelle B erreichen?
--- Die Pfadsuche ist der teuerste Schritt beim Anlegen einer Lieferung (auf großen Karten
--- mehrere ms). Schlüssel ist der Depot-*Name* + Oberfläche: gleichnamige Depot-Haltestellen
--- liegen praktisch immer zusammen, so reicht eine Suche für alle Züge dieses Depots.
--- Verworfen wird alles, sobald sich das Gleisnetz ändert (Gleise, Signale gebaut/abgerissen),
--- und sicherheitshalber jede Stunde.
local Reach = {}

local MAX_AGE = 60 * 60 * 60
-- Höchstens so viele *neue* Pfadsuchen pro Dispatcher-Lauf (je ~1–4 ms auf großen Karten; Lasttest: 1);
-- der Rest kommt im nächsten Lauf dran. Verhindert Ruckler, wenn viele Anfragen auf einmal kommen.
local SEARCHES_PER_RUN = 1
local searches_left = SEARCHES_PER_RUN
local PATH_STEPS = 20000

-- Gleise und Signale: Bau/Abriss ändert, was erreichbar ist.
Reach.TOPOLOGY_TYPES = {
  "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "rail-ramp",
  "elevated-straight-rail", "elevated-curved-rail-a", "elevated-curved-rail-b",
  "elevated-half-diagonal-rail", "legacy-straight-rail", "legacy-curved-rail",
  "rail-signal", "rail-chain-signal",
}

local function cache()
  local reach = storage.dispatch.reach
  if not reach or game.tick - reach.created > MAX_AGE then
    reach = { created = game.tick, from = {} }
    storage.dispatch.reach = reach
  end
  return reach.from
end

--- Zu Beginn jedes Dispatcher-Laufs: Budget für neue Pfadsuchen auffüllen.
function Reach.begin_run()
  searches_left = SEARCHES_PER_RUN
end

--- Budget für neue Pfadsuchen in diesem Lauf aufgebraucht?
function Reach.exhausted()
  return searches_left <= 0
end

--- Gleisnetz geändert: alles vergessen.
function Reach.invalidate()
  storage.dispatch.reach = nil
end

--- Erreicht `train` (steht im Depot `depot_stop`) die Haltestelle `stop`?
--- Nur beim ersten Mal je Depot-Name wird wirklich gesucht. Liefert nil, wenn das
--- Such-Budget dieses Laufs aufgebraucht ist (dann im nächsten Lauf erneut).
function Reach.check(train, depot_stop, stop, ignore_budget)
  local from = cache()
  -- Schlüssel mit Team: zwei Teams können gleichnamige Depots auf derselben Oberfläche haben
  local key = depot_stop.surface_index .. ":" .. depot_stop.force_index .. "|" .. depot_stop.backer_name
  local by_stop = from[key]
  if not by_stop then
    by_stop = {}
    from[key] = by_stop
  end
  local unit = stop.unit_number
  local known = by_stop[unit]
  if known ~= nil then return known end
  if not ignore_budget then
    if searches_left <= 0 then return nil end
    searches_left = searches_left - 1
  end
  local result = game.train_manager.request_train_path({
    train = train,
    goals = { { train_stop = stop } },
    steps_limit = PATH_STEPS,
  })
  known = result.found_path == true
  by_stop[unit] = known
  return known
end

return Reach
