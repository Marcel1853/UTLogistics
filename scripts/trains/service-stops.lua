--- Dienst-Stationen (Tankstelle, Cleanup): Mengen pflegen und die passende finden.
--- Passend = Rolle, gleiches Netzwerk, gleiche Oberfläche, Zuglänge im Bereich der Station;
--- unter den passenden wählt eine einzige Pfadsuche die nächste erreichbare.
local Registry = require("scripts.stations.registry")
local Networks = require("scripts.stations.networks")
local Pending = require("scripts.trains.pending")
local Capacity = require("scripts.trains.capacity")
local Reach = require("scripts.dispatcher.reach")
local Log = require("scripts.lib.log")

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

--- Wie `exists`, aber nur Stationen, die der Zug von `from_stop` (Depot oder Haltestelle, an der er
--- steht) aus auch erreicht – belegt oder nicht. Nutzt den Erreichbarkeits-Cache (reach.lua), die
--- Pfadsuche läuft also je Depot-Name und Station nur einmal. Beispiel: Mit Cargo Ships liegen Häfen
--- und Haltestellen im selben Netz – eine Hafen-Tankstelle erreicht kein Zug.
function ServiceStops.reachable(train, from_stop, network, role)
  local front = train.front_stock
  if not (front and from_stop and from_stop.valid) then return false end
  for unit in pairs(set_of(role)) do
    local station = Registry.get(unit)
    local stop = station and station.stop
    if station and station.config.roles[role] and stop and stop.valid
      and stop.surface_index == front.surface_index and stop.force_index == front.force_index
      and Networks.related(Networks.place_of(stop), station.config.network, network)
      and Reach.check(train, from_stop, stop, true) then
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
      -- „max. Züge“ und Zuglimit der Haltestelle beachten: UTL fährt per Schienen-Wegpunkt direkt
      -- davor, da greift das Vanilla-Limit nicht von selbst – ein Stau würde sonst die Hauptstrecke
      -- blockieren.
      -- ohne Gleis (Halt aus einer Blaupause, Gleis fehlt noch) kein Ziel: die Pfadsuche bräche ab
      if stop and stop.valid and cfg.roles[role] and not stop.connected_rail then
        Log.debug_once("no-rail:" .. stop.unit_number,
          "Haltestelle " .. Log.stop_name(stop) .. " (" .. role .. ") hat kein Gleis: wird nicht angefahren, bis eins anliegt.")
      elseif stop and stop.valid and cfg.roles[role] and stop.surface_index == surface
        and stop.force_index == force
        and Networks.related(place, cfg.network, network) and length_ok(cfg, length)
        and Capacity.has_room(stop, cfg, heading) then
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
  if not result.found_path then
    Log.debug("Zug " .. train.id .. ": keine der " .. #goals .. " passenden Tank-/Cleanup-Stationen ist erreichbar.")
  end
  return result.found_path and candidates[result.goal_index] or nil
end

--- Nächste erreichbare passende Station mit Rolle `role` („fuel“/„cleanup“) oder nil.
function ServiceStops.find(train, network, role)
  local found = ServiceStops.nearest(train, ServiceStops.candidates(train, network, role))
  return found and found.stop or nil
end

return ServiceStops
