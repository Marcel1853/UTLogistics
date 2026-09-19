--- Cleanup-Route (Idee aus LTN Cleanup, dort über Haltestellennamen – bei UTL im Fenster):
--- Jede Restware braucht eine Cleanup-Station, die sie annimmt. Stationen, die die Ware
--- ausdrücklich eingetragen haben, kommen vor „Alle Items“/„Alle Flüssigkeiten“; reicht eine
--- Station nicht, fährt der Zug mehrere nacheinander an. Unter den passenden nimmt eine
--- Pfadsuche jeweils die nächste erreichbare.
local Fields = require("scripts.stations.fields")
local ServiceStops = require("scripts.trains.service-stops")

local CleanupRoute = {}

local MAX_STOPS = 4 -- mehr Halte (und Pfadsuchen) pro Zug nicht

--- Restladung als Liste { kind, name, quality }.
local function wares_of(train)
  local wares = {}
  for _, item in pairs(train.get_contents()) do
    wares[#wares + 1] = { kind = "item", name = item.name, quality = item.quality }
  end
  for name in pairs(train.get_fluid_contents()) do
    wares[#wares + 1] = { kind = "fluid", name = name }
  end
  return wares
end

--- Stationen aus `candidates` (ohne bereits genutzte), die `ware` annehmen; `specific` = nur
--- ausdrücklich eingetragene.
local function accepting(candidates, used, ware, specific)
  local list = {}
  for _, candidate in ipairs(candidates) do
    if not used[candidate.stop.unit_number] then
      local ok, explicit = Fields.cleanup_accepts(candidate.config, ware.kind, ware.name)
      if ok and (explicit or not specific) then list[#list + 1] = candidate end
    end
  end
  return list
end

--- Route für die Restladung des Zugs. Liefert eine Liste { stop, wares } oder nil und die erste
--- Ware, für die keine passende, freie und erreichbare Cleanup-Station da ist.
function CleanupRoute.plan(train, network)
  local remaining = wares_of(train)
  if #remaining == 0 then return nil, nil end
  local candidates = ServiceStops.candidates(train, network, "cleanup")
  local route, used = {}, {}
  while #remaining > 0 do
    if #route >= MAX_STOPS then return nil, remaining[1] end
    -- zuerst eine Ware mit ausdrücklich passender Station, sonst die erste über „Alle …“
    local target, pool
    for _, ware in ipairs(remaining) do
      local specific = accepting(candidates, used, ware, true)
      if #specific > 0 then
        target, pool = ware, specific
        break
      end
    end
    if not target then
      target = remaining[1]
      pool = accepting(candidates, used, target, false)
    end
    local chosen = #pool > 0 and ServiceStops.nearest(train, pool) or nil
    if not chosen then return nil, target end
    used[chosen.stop.unit_number] = true
    local take, rest = {}, {}
    for _, ware in ipairs(remaining) do
      if Fields.cleanup_accepts(chosen.config, ware.kind, ware.name) then take[#take + 1] = ware else rest[#rest + 1] = ware end
    end
    route[#route + 1] = { stop = chosen.stop, wares = take }
    remaining = rest
  end
  return route, nil
end

--- Ware als Rich-Text für Warnungen.
function CleanupRoute.rich(ware)
  if not ware then return "?" end
  return "[" .. ware.kind .. "=" .. ware.name .. "]"
end

return CleanupRoute
