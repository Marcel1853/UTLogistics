--- Wege ins Depot, die UTL selbst lenkt: freien Depot-Platz gleichen Namens finden (mit „max.
--- Züge“ und Zuglimit, siehe capacity.lua) und den Zug per Schienen-Wegpunkt davor schicken; sein
--- Depot-Halt im Fahrplan führt ihn dann genau dorthin.
---   * relocate: Zug steht an einer gleichnamigen Haltestelle ohne Depot-Rolle bzw. im falschen Team.
---   * send_home: Zug fährt nach einer Fahrt ohne Anschlussauftrag zurück. Ohne diese Lenkung wählt
---     das Spiel das Depot nach Namen – „max. Züge“ am Depot gälte dann nicht.
local Schedule = require("scripts.trains.schedule")
local Networks = require("scripts.stations.networks")
local Pending = require("scripts.trains.pending")
local Capacity = require("scripts.trains.capacity")

local DepotRoute = {}

local MAX_DEPOT_CANDIDATES = 20
local DEPOT_DEFAULT = 1 -- ohne „max. Züge“ und Zuglimit: ein Zug je Depot-Haltestelle (wie bisher)

local function length_ok(cfg, length)
  return (cfg.min_train_length <= 0 or length >= cfg.min_train_length)
    and (cfg.max_train_length <= 0 or length <= cfg.max_train_length)
end

--- Nächstes erreichbares Depot namens `name` mit Platz, oder nil. `network` = nil: Netz egal;
--- `exclude` = Haltestelle, an der der Zug gerade steht.
local function find_free(train, name, surface, network, exclude)
  local length = #train.carriages
  local front = train.front_stock
  if not front then return nil end
  -- Team des Zuges (nicht der Haltestelle: die kann einem anderen Team gehören)
  local force = front.force_index
  local place = Networks.place(surface, force)
  local goals, stops = {}, {}
  -- Züge, die schon per Wegpunkt zu einem Depot unterwegs sind, zählen mit: sonst schickt UTL
  -- mehrere zum selben freien Depot, und die übrigen stauen sich davor.
  local heading = Pending.counts()
  for _, station in pairs(storage.stations.by_unit) do
    local stop, cfg = station.stop, station.config
    if cfg.roles.depot and stop and stop.valid and stop ~= exclude and stop.backer_name == name
      and stop.surface_index == surface and stop.force_index == force
      and (network == nil or Networks.related(place, cfg.network, network))
      and length_ok(cfg, length)
      and Capacity.has_room(stop, cfg, heading, DEPOT_DEFAULT) then
      stops[#stops + 1] = stop
      goals[#goals + 1] = { train_stop = stop }
      if #goals >= MAX_DEPOT_CANDIDATES then break end
    end
  end
  if #goals == 0 then return nil end
  local result = game.train_manager.request_train_path({ train = train, goals = goals, steps_limit = 20000 })
  return result.found_path and stops[result.goal_index] or nil
end

--- Zug steht an `current` (gleicher Name wie ein Depot, aber keins bzw. fremdes Team): in ein
--- freies echtes Depot umsetzen.
function DepotRoute.relocate(train, current, network, after_service)
  local target = find_free(train, current.backer_name, current.surface_index, network, current)
  if not target then return false end
  if not Schedule.send_waypoint(train, target) then return false end
  Pending.reserve(train.id, { target })
  storage.trains.service[train.id] = after_service and "relocate-serviced" or "relocate"
  return true
end

--- Zug ist gerade ohne Anschlussauftrag abgefahren: zu einem Depot seines Namens mit Platz lenken.
--- Nur wenn sein nächster Halt wirklich dieses Depot ist (kein Interrupt, keine weitere
--- Dienststation dazwischen). Findet sich kein Platz, fährt er wie bisher nach Fahrplan.
function DepotRoute.send_home(train)
  if not train.valid then return false end
  local home = storage.trains.home[train.id]
  if not (home and home.stop and home.stop.valid) then return false end
  local schedule = train.get_schedule()
  local current = schedule and schedule.current
  local record = current and schedule.get_record({ schedule_index = current })
  if not (record and record.station == home.depot and not record.temporary) then return false end
  local unit = storage.stations.by_stop[home.stop.unit_number]
  local station = unit and storage.stations.by_unit[unit]
  local network = station and station.config.network or nil
  local target = find_free(train, home.depot, home.stop.surface_index, network, nil)
  if not target then return false end
  if not Schedule.waypoint_before(train, target, current) then return false end
  Pending.reserve(train.id, { target })
  return true
end

return DepotRoute
