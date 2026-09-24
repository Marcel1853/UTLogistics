--- Dienst-Stationen (Tankstelle, Cleanup): Mengen pflegen und die passende finden.
--- Passend = Rolle, gleiches Netzwerk, gleiche Oberfläche, Zuglänge im Bereich der Station;
--- unter den passenden wählt eine einzige Pfadsuche die nächste erreichbare.
local Registry = require("scripts.stations.registry")
local Networks = require("scripts.stations.networks")
local Pending = require("scripts.trains.pending")

local ServiceStops = {}

local ROLES = { "fuel", "cleanup" }
local MAX_CANDIDATES = 20 -- Stationen pro Pfadsuche
local PATH_STEPS = 20000

local function set_of(role)
  return storage.service_stations[role]
end

--- Mengen nach Rollenwechsel, Kopieren usw. anpassen. Liefert die Rollen, die neu dazukamen.
function ServiceStops.update_station(station)
  local added = {}
  for _, role in ipairs(ROLES) do
    local set = set_of(role)
    local has = station.config.roles[role] or nil
    if has and not set[station.unit] then added[#added + 1] = role end
    set[station.unit] = has
  end
  return added
end

function ServiceStops.forget_station(unit)
  for _, role in ipairs(ROLES) do set_of(role)[unit] = nil end
end

local function length_ok(cfg, length)
  return (cfg.min_train_length <= 0 or length >= cfg.min_train_length)
    and (cfg.max_train_length <= 0 or length <= cfg.max_train_length)
end

--- Gibt es für diesen Zug überhaupt eine Station mit dieser Rolle (egal ob frei)? `front` = Lok:
--- nur Stationen derselben Oberfläche und desselben Teams zählen – sonst gilt eine Tankstelle auf
--- Nauvis auch für Vulcanus, und der Zug dort wartet ewig auf eine Fahrt, die nie kommt.
function ServiceStops.exists(network, role, front)
  local surface = front and front.surface_index
  local force = front and front.force_index
  for unit in pairs(set_of(role)) do
    local station = Registry.get(unit)
    local stop = station and station.stop
    if station and station.config.roles[role] and stop and stop.valid
      and (surface == nil or stop.surface_index == surface)
      and (force == nil or stop.force_index == force)
      and Networks.related(Networks.place_of(stop), station.config.network, network) then
      return true
    end
  end
  return false
end

--- Alle passenden Stationen mit Rolle `role` für diesen Zug: Liste von { stop, config }.
function ServiceStops.candidates(train, network, role)
  local list = {}
  local front = train.front_stock
  if not front then return list end
  local surface, force = front.surface_index, front.force_index
  local place = Networks.place_of(front)
  local length = #train.carriages
  local set = set_of(role)
  local heading = Pending.counts()
  for unit in pairs(set) do
    local station = Registry.get(unit)
    if not station then
      set[unit] = nil
    else
      local stop, cfg = station.stop, station.config
      -- Zuglimit der Haltestelle beachten: UTL fährt per Schienen-Wegpunkt direkt davor, da
      -- greift das Vanilla-Limit nicht – ein Stau würde sonst die Hauptstrecke blockieren.
      if stop and stop.valid and cfg.roles[role] and stop.surface_index == surface and stop.force_index == force
        and Networks.related(place, cfg.network, network) and length_ok(cfg, length)
        and stop.trains_count + (heading[stop.unit_number] or 0) < (stop.trains_limit or math.huge) then
        list[#list + 1] = { stop = stop, config = cfg }
      end
    end
  end
  return list
end

--- Nächste erreichbare Station aus `candidates` (eine Pfadsuche über höchstens 20 Ziele) oder nil.
function ServiceStops.nearest(train, candidates)
  local goals = {}
  for i = 1, math.min(#candidates, MAX_CANDIDATES) do goals[i] = { train_stop = candidates[i].stop } end
  if #goals == 0 then return nil end
  local result = game.train_manager.request_train_path({ train = train, goals = goals, steps_limit = PATH_STEPS })
  return result.found_path and candidates[result.goal_index] or nil
end

--- Nächste erreichbare passende Station mit Rolle `role` („fuel“/„cleanup“) oder nil.
function ServiceStops.find(train, network, role)
  local found = ServiceStops.nearest(train, ServiceStops.candidates(train, network, role))
  return found and found.stop or nil
end

return ServiceStops
