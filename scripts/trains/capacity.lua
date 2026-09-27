--- Platz an einer Haltestelle für einen weiteren Zug (Tankstelle, Cleanup, Depot).
--- Es gelten beide Grenzen, soweit gesetzt: „max. Züge“ der Station (UTL) und das Zuglimit der
--- Haltestelle (Vanilla). Gezählt werden Züge dort bzw. auf dem Weg dorthin (`trains_count`) und
--- Züge, die UTL per Schienen-Wegpunkt hinschickt – die zählt das Spiel nicht mit (Pending).
local Capacity = {}

local NO_LIMIT = 4294967295 -- trains_limit bei abgeschaltetem Zuglimit (höchster uint32)

--- `heading` = Pending.counts(); `default` = Grenze, wenn weder „max. Züge“ noch Zuglimit gesetzt
--- sind (nil = unbegrenzt; Depots: 1, ein Zug je Depot-Haltestelle wie bisher).
function Capacity.has_room(stop, cfg, heading, default)
  local limit = stop.trains_limit
  if not limit or limit >= NO_LIMIT then limit = nil end
  local max_trains = cfg.max_trains or 0
  if max_trains > 0 then limit = limit and math.min(limit, max_trains) or max_trains end
  limit = limit or default
  if not limit then return true end
  return stop.trains_count + (heading[stop.unit_number] or 0) < limit
end

return Capacity
