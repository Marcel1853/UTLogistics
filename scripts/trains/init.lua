--- Zug-Events: Depot-Pool und Lieferfortschritt, rein ereignisgetrieben.
local Events = require("scripts.core.events")
local Registry = require("scripts.stations.registry")
local Depot = require("scripts.trains.depot")
local Deliveries = require("scripts.deliveries.deliveries")
local Dispatch = require("scripts.dispatcher.dispatch")
local ServiceStops = require("scripts.trains.service-stops")
local Alerts = require("scripts.alerts.alerts")
local Heartbeat = require("scripts.core.heartbeat")
local Perf = require("scripts.core.perf")
local State = require("scripts.core.state")

local S = defines.train_state

local MANUAL = {
  [S.manual_control] = true,
  [S.manual_control_stop] = true,
}

local function on_state(event)
  local train = event.train
  local id = train.id
  local delivery = Deliveries.of_train(id)
  local state = train.state

  if MANUAL[state] then
    Depot.remove(id)
    storage.trains.service[id] = nil
    if delivery then Deliveries.cancel(delivery, "manual") end
    return
  end

  -- Lieferzug findet keinen Weg (Gleis abgerissen, Signal falsch …): warnen.
  if state == S.no_path and delivery then
    local target = delivery.state == "to_provider" and delivery.from or delivery.to
    Alerts.raise("train", "no_path", train.front_stock, { "utl-alert.no-path", Alerts.train_name(train), target or "?" },
      "no-path:" .. id)
    return
  end

  if state == S.wait_station then
    local stop = train.station -- nil am Schienen-Wegpunkt
    if not stop then return end
    if delivery then
      Deliveries.on_arrive(delivery, stop)
    else
      local unit = storage.stations.by_stop[stop.unit_number]
      local station = unit and Registry.get(unit)
      if station and station.config.roles.depot then
        Depot.arrive(train, stop, station)
      else
        if station and (station.config.roles.fuel or station.config.roles.cleanup) then
          storage.trains.visiting[id] = stop -- für „direkt der nächste Auftrag“ bei der Abfahrt
        end
        Depot.stray(train, stop) -- gleichnamige Haltestelle ohne Depot-Rolle?
      end
    end
  elseif event.old_state == S.wait_station then
    if delivery then
      -- Lieferung fertig, Zug leer und betankt: direkt der nächste Auftrag statt ins Depot
      if Deliveries.on_depart(delivery) then
        local requester = Registry.get(delivery.requester)
        Dispatch.chain(train, delivery.network or "default", requester and requester.stop, delivery.depot)
      end
    else
      Depot.remove(id)
      -- Abfahrt von Tankstelle/Cleanup nach einer Dienstfahrt: ebenfalls direkt weiter
      local stop = storage.trains.visiting[id]
      storage.trains.visiting[id] = nil
      if stop and storage.trains.service[id] then
        local home = storage.trains.home[id]
        local depot_unit = home and home.stop.valid and storage.stations.by_stop[home.stop.unit_number]
        local depot = depot_unit and Registry.get(depot_unit)
        local network = depot and depot.config.network or "default"
        if Dispatch.chain(train, network, stop, home and home.depot) then storage.trains.service[id] = nil end
      end
    end
  end
end

Events.on(defines.events.on_train_changed_state, function(event)
  State.ensure() -- Züge eines Szenario-Scripts können vor UTLs on_init entstehen
  Perf.measure("zug-event", on_state, event)
end)

-- Zug umgebaut (Wagen an-/abgekoppelt): alte Zug-IDs sind ungültig.
Events.on(defines.events.on_train_created, function(event)
  State.ensure()
  local function retire(old)
    if not old then return end
    Depot.remove(old)
    storage.trains.service[old] = nil
    storage.trains.visiting[old] = nil
    storage.trains.cargo_waiting[old] = nil
    storage.trains.home[old] = nil
    local delivery = Deliveries.of_train(old)
    if delivery then Deliveries.cancel(delivery, "rebuilt") end
  end
  retire(event.old_train_id_1)
  retire(event.old_train_id_2)
end)

-- Umbenannte Haltestelle: Depot-Namen neu ermitteln.
Events.on(defines.events.on_entity_renamed, function(event)
  if event.entity.valid and event.entity.type == "train-stop" then Depot.invalidate_names() end
end)

Registry.on_lost(function(station)
  Depot.invalidate_names()
  Deliveries.cancel_for_station(station.unit)
  ServiceStops.forget_station(station.unit)
  if station.stop_unit then Depot.forget(station.stop_unit) end
end)

Registry.on_config_changed(function(station)
  Depot.refresh_station(station)
  -- Neue Tank-/Cleanup-Station: wartende Züge, die sie brauchen, gleich hinschicken.
  if #ServiceStops.update_station(station) > 0 then
    Depot.refuel_idle()
    Depot.rescan_all()
  end
end)

-- Wiederholsperren der Warnungen gelegentlich aufräumen (alle 60 Heartbeats).
Heartbeat.add_task("alerts-cleanup", 60, Alerts.cleanup)

-- Freie Züge, die knapp an Treibstoff sind, alle 60 Heartbeats (Standard 10 s) zum Tanken
-- schicken – z. B. wenn beim Einparken gerade keine Tankstelle frei war.
Heartbeat.add_task("refuel-idle", 60, function() Depot.refuel_idle(3) end)

-- Züge mit Restladung, für die kein Cleanup frei war: alle 60 Heartbeats erneut versuchen.
Heartbeat.add_task("cleanup-retry", 60, function() Depot.retry_cargo(3) end)
