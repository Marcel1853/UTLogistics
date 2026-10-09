--- Weitere Funktionen der Schnittstelle „utl“ (seit 0.0.10), eingebunden in api/remote.lua.
--- Alles liefert Kopien, keine Tabellen aus storage. Stationen und Züge über `unit_number` bzw.
--- `train.id`, Teams über den Namen der Force.
local Registry = require("scripts.stations.registry")
local Networks = require("scripts.stations.networks")
local Deliveries = require("scripts.deliveries.deliveries")
local PublicEvents = require("scripts.api.public-events")
local Stuck = require("scripts.deliveries.stuck")
local util = require("util")

local function force_index(name)
  local force = name and game.forces[name]
  return force and force.index or nil
end

local More = {}

--- IDs der UTL-Ereignisse: { on_delivery_created, on_delivery_state_changed, on_delivery_completed,
--- on_delivery_canceled, on_train_arrived, on_train_departed, on_train_idle, on_train_rebuilt }
--- (Felder siehe api/public-events.lua). Daten wie bei get_delivery, dazu `train` (LuaTrain) und bei
--- on_delivery_canceled `reason` („station-lost“, „manual“, „rebuilt“, „provider-empty“, „remote“).
function More.get_event_ids()
  return util.table.deepcopy(PublicEvents.ids)
end

--- Eine laufende Lieferung (wie ein Eintrag aus get_deliveries) oder nil.
function More.get_delivery(id)
  local delivery = storage.deliveries.active[id]
  if not delivery then return nil end
  local info = PublicEvents.info(delivery)
  info.train = nil -- wie get_deliveries: ohne Entity-Referenz
  return info
end

--- Laufende Lieferung abbrechen: Die UTL-Halte verschwinden, der Zug fährt mit seinem eigenen
--- Fahrplan weiter (Cleanup/Tanken, sonst ins Depot). Liefert true, wenn es sie gab.
function More.cancel_delivery(id)
  local delivery = storage.deliveries.active[id]
  if not delivery then return false end
  Deliveries.cancel(delivery, "remote")
  return true
end

--- Was UTL über einen Zug weiß, oder nil, wenn UTL ihn nicht kennt:
--- { id, idle (frei im Depot), network, depot (Name des Heimatdepots), depot_stop (unit),
---   delivery (id), service ("fuel" | "cleanup" | "both" | "relocate" …), stuck_minutes }.
function More.get_train(train_id)
  local trains = storage.trains
  local record = trains.by_id[train_id]
  local home = trains.home[train_id]
  local delivery = Deliveries.of_train(train_id)
  local service = trains.service[train_id]
  if not (record or home or delivery or service or trains.held[train_id]) then return nil end
  local depot_stop = home and home.stop and home.stop.valid and home.stop or nil
  local depot_unit = depot_stop and storage.stations.by_stop[depot_stop.unit_number]
  local depot = depot_unit and Registry.get(depot_unit)
  return {
    id = train_id,
    idle = record ~= nil,
    network = record and record.network or (depot and depot.config.network) or nil,
    depot = home and home.depot or nil,
    depot_stop = depot_stop and depot_stop.unit_number or nil,
    delivery = delivery and delivery.id or nil,
    service = service,
    stuck_minutes = delivery and Stuck.minutes(delivery) or nil,
    held_by = trains.held[train_id], -- Mod, der ihn festhält (hold_train)
  }
end

--- Freie Züge in Depots: Liste { id, network, depot, length, surface, force }.
--- `filter` (optional): { surface = Index, force = Name, network = Name }.
function More.get_idle_trains(filter)
  filter = filter or {}
  -- Depot eines Add-ons mit eigenen Zügen: { role = "mod/name" }
  if filter.role then
    local list = {}
    for id, entry in pairs(storage.trains.addon_idle) do
      local stop = entry.stop
      if entry.role == filter.role and entry.train.valid and stop and stop.valid then
        list[#list + 1] = { id = id, station = entry.station, depot = stop.backer_name, length = #entry.train.carriages,
          surface = stop.surface_index, force = stop.force.name, role = entry.role }
      end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
  end
  local wanted_force = filter.force and force_index(filter.force)
  if filter.force and not wanted_force then return {} end
  local list = {}
  for id, record in pairs(storage.trains.by_id) do
    if (not filter.surface or record.surface_index == filter.surface)
      and (not wanted_force or record.force_index == wanted_force)
      and (not filter.network or record.network == filter.network) then
      local stop = record.stop
      list[#list + 1] = { id = id, network = record.network, depot = stop and stop.valid and stop.backer_name or nil,
        length = record.length, surface = record.surface_index, force = game.forces[record.force_index].name }
    end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

--- UTL-Stationen: Liste { unit, stop (unit_number der Haltestelle), stop_name, network, roles,
--- surface, force }. `filter` (optional): { surface = Index, force = Name, network = Name,
--- role = "provider" | "requester" | "depot" | "fuel" | "cleanup" | "storage", addon_role = "mod/name" }.
function More.get_stations(filter)
  filter = filter or {}
  local wanted_force = filter.force and force_index(filter.force)
  if filter.force and not wanted_force then return {} end
  local list = {}
  for unit, station in pairs(storage.stations.by_unit) do
    local stop, cfg = station.stop, station.config
    local entity = stop and stop.valid and stop or station.entity
    if entity and entity.valid
      and (not filter.surface or entity.surface_index == filter.surface)
      and (not wanted_force or entity.force_index == wanted_force)
      and (not filter.network or cfg.network == filter.network)
      and (not filter.role or cfg.roles[filter.role])
      and (not filter.addon_role or cfg.addon_role == filter.addon_role) then
      list[#list + 1] = {
        unit = unit,
        stop = stop and stop.valid and stop.unit_number or nil,
        stop_name = stop and stop.valid and stop.backer_name or nil,
        network = cfg.network,
        roles = util.table.deepcopy(cfg.roles),
        addon_role = cfg.addon_role,
        surface = entity.surface_index,
        force = entity.force.name,
      }
    end
  end
  table.sort(list, function(a, b) return a.unit < b.unit end)
  return list
end

--- Netznamen, die auf einer Oberfläche für ein Team vorkommen (Heimatnetze der Stationen und
--- verbundene Netze), sortiert. `force` = Name, Standard „player“.
function More.get_networks(surface_index, force)
  local index = force_index(force or "player")
  if not index then return {} end
  local place = Networks.place(surface_index, index)
  local set = {}
  for _, station in pairs(storage.stations.by_unit) do
    local stop = station.stop
    if stop and stop.valid and stop.surface_index == surface_index and stop.force_index == index then
      set[station.config.network] = true
      for _, name in ipairs(Networks.related_list(place, station.config.network)) do set[name] = true end
    end
  end
  local list = {}
  for name in pairs(set) do list[#list + 1] = name end
  table.sort(list)
  return list
end

return More
