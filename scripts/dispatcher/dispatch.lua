--- Dispatcher: verbindet Bedarf mit Angebot und einem freien Zug.
---
--- Pro Lauf fest gedeckelt (UPS): höchstens `max_deliveries` neue Lieferungen, und pro Anfrage
--- nur wenige Anbieter/Züge – die Auswahl selbst steht in `select.lua`, die Warnungen in
--- `no-train-alerts.lua`.
---
--- Auswahl (Ziel: wenige Züge, volle Ladungen):
---   Anfragen:  höhere Abnehmer-Priorität zuerst.
---   Anbieter:  höhere Anbieter-Priorität, dann mehr lieferbare Menge, dann näher am Abnehmer.
---   Zug:       mehr Ladung pro Fahrt zuerst, dann näher am Anbieter; erreichbar laut Pfadsuche.
local Deliveries = require("scripts.deliveries.deliveries")
local Networks = require("scripts.stations.networks")
local Depot = require("scripts.trains.depot")
local Index = require("scripts.dispatcher.index")
local Util = require("scripts.lib.util")
local Reach = require("scripts.dispatcher.reach")
local Fuel = require("scripts.trains.fuel")
local Select = require("scripts.dispatcher.select")
local Warn = require("scripts.dispatcher.no-train-alerts")

local Dispatch = {}

local dist2 = Util.dist2

--- Sammelwarnung je Netz (Heartbeat-Aufgabe).
Dispatch.starving_alerts = Warn.starving_alerts

local function try_request(request)
  -- Kein einziger freier Zug im Netzwerk: nicht nach Anbietern suchen (spart im Dauerbetrieb den
  -- Großteil der Zeit). Nur die Wartezeit für die Warnung mitführen; erst wenn gewarnt würde,
  -- wird ein Anbieter für den Text gesucht.
  if #Select.pools_for(request.station) == 0 then
    local unit, key = request.station.unit, request.key
    if Deliveries.incoming(unit, key) > 0 then
      Warn.waiting_since(unit, key, true)
      return false
    end
    if game.tick - Warn.waiting_since(unit, key) < storage.cfg.alert_no_train_minutes * 3600 then return false end
    local providers = Select.providers(request)
    if providers and #providers > 0 then Warn.no_train(request, providers[1], false) end
    return false
  end
  local providers = Select.providers(request)
  if not providers or #providers == 0 then return false end
  for i = 1, math.min(#providers, Select.PROVIDER_TRIES) do
    local provider = providers[i]
    local record, amount, later, fuel_stop = Select.train(request, provider, provider.amount)
    if later then return false, true end -- im nächsten Lauf weiter, keine Warnung
    if record then
      local manifest = Select.manifest(request, provider, record, amount)
      local created = Deliveries.create(record, provider.station, request.station, manifest, fuel_stop) ~= nil
      if created then Warn.waiting_since(request.station.unit, request.key, true) end
      return created
    end
  end
  Warn.no_train(request, providers[1], true)
  return false
end

--- Direkt der nächste Auftrag (Wunsch Marcel): Ein Zug, der gerade entladen hat oder vom
--- Cleanup/Tanken kommt, übernimmt sofort eine passende Lieferung – bevorzugt mit einem Anbieter
--- in seiner Nähe – statt erst ins Depot zu fahren. `from_stop` = Haltestelle, die er gerade
--- verlässt (Schlüssel für den Erreichbarkeits-Cache). Liefert die Lieferung oder nil.
function Dispatch.chain(train, network, from_stop, depot_name)
  if not (storage.cfg.chaining and train.valid and from_stop and from_stop.valid) then return nil end
  if Depot.has_cargo(train) or Fuel.needs_station(train, network) then return nil end -- erst Cleanup/Tanken
  local front = train.front_stock
  if not front then return nil end
  local slots, wagons, fluid = Depot.measure(train)
  local record = {
    train = train, id = train.id, network = network, surface_index = front.surface_index,
    force_index = front.force_index,
    position = front.position, length = #train.carriages, slots = slots, wagons = wagons, fluid = fluid,
    stop = from_stop, depot_name = depot_name,
  }
  Index.update()
  local best
  for _, request in ipairs(Select.requests()) do
    local r_stop = request.station.stop
    if r_stop.surface_index == record.surface_index and r_stop.force_index == record.force_index
      and Networks.related(Networks.place(record.surface_index, record.force_index), request.station.config.network, network) then
      local providers = Select.providers(request) or {}
      for i = 1, math.min(#providers, Select.PROVIDER_TRIES) do
        local provider = providers[i]
        local p_cfg, r_cfg = provider.station.config, request.station.config
        local capacity = Select.capacity_of(record, request.key, p_cfg.locked_slots)
        if capacity > 0 and Select.length_ok(p_cfg, record.length) and Select.length_ok(r_cfg, record.length) then
          local amount = math.min(provider.amount, capacity)
          if amount >= request.minimum or amount == capacity then
            local distance = dist2(record.position, provider.station.stop.position)
            -- Priorität zuerst, dann volle Ladung, dann kurzer Weg zum Anbieter
            local better = not best
              or request.priority > best.request.priority
              or (request.priority == best.request.priority and (amount > best.amount
                or (amount == best.amount and distance < best.distance)))
            if better then best = { request = request, provider = provider, amount = amount, distance = distance } end
          end
        end
      end
    end
  end
  if not best then return nil end
  if not Reach.check(train, from_stop, best.provider.station.stop, true) then return nil end
  local manifest = Select.manifest(best.request, best.provider, record, best.amount)
  local delivery = Deliveries.create(record, best.provider.station, best.request.station, manifest, nil)
  if delivery then
    delivery.chained = true
    storage.deliveries.chained = (storage.deliveries.chained or 0) + 1
    Warn.waiting_since(best.request.station.unit, best.request.key, true)
  end
  return delivery
end

--- Heartbeat-Aufgabe.
function Dispatch.run()
  Index.update()
  Reach.begin_run()
  -- Auch ohne freie Züge weiterlaufen (gedeckelt), damit „kein freier Zug“ gewarnt werden kann.
  local requests = Select.requests()
  local budget = storage.cfg.max_deliveries
  local created = 0
  local busy = {} -- pro Lauf nur eine neue Lieferung je Abnehmer
  for i = 1, #requests do
    if created >= budget then break end
    local request = requests[i]
    local unit = request.station.unit
    if not busy[unit] and Select.has_room(request.station) then
      local ok, later = try_request(request)
      if ok then
        busy[unit] = true
        created = created + 1
      elseif later then
        break -- Budget für neue Pfadsuchen aufgebraucht: Rest im nächsten Lauf
      end
    end
  end
end

return Dispatch
