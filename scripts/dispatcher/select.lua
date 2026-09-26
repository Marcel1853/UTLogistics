--- Auswahl für den Dispatcher: offene Anfragen, passende Anbieter und ein freier Zug dazu.
--- Alles fest gedeckelt (UPS): höchstens REQUESTER_SCAN Abnehmer je Lauf, PROVIDER_SCAN Anbieter
--- je Anfrage, TRAIN_SCAN Züge je Anfrage – und nur die besten Kandidaten werden beim Spiel
--- nachgefragt (Pfadsuche, Treibstoff). Die Vorauswahl nutzt nur gespeicherte Werte.
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Deliveries = require("scripts.deliveries.deliveries")
local Networks = require("scripts.stations.networks")
local Depot = require("scripts.trains.depot")
local Util = require("scripts.lib.util")
local Index = require("scripts.dispatcher.index")
local Reach = require("scripts.dispatcher.reach")
local Fuel = require("scripts.trains.fuel")
local Fields = require("scripts.stations.fields")

local Select = {}

local REQUESTER_SCAN = 20
local PROVIDER_SCAN = 50
Select.PROVIDER_TRIES = 3
local PROVIDER_TRIES = Select.PROVIDER_TRIES
local TRAIN_SCAN = 100
local TRAIN_TRIES = 3

local dist2 = Util.dist2
local stack_size = Util.stack_size

--- Platz für einen weiteren Zug? UTL-Wert „max. Züge“ und Vanilla-Zuglimit der Haltestelle
--- (das greift wegen des Schienen-Wegpunkts sonst nicht).
local function has_room(station)
  local limit = station.config.max_trains
  if limit > 0 and Deliveries.trains_at(station.unit) >= limit then return false end
  local stop = station.stop
  return not (stop and stop.valid) or stop.trains_count < stop.trains_limit
end

local function usable(station)
  local stop = station and station.stop
  return stop and stop.valid and station.entity.valid
end

local function length_ok(cfg, length)
  return (cfg.min_train_length <= 0 or length >= cfg.min_train_length)
    and (cfg.max_train_length <= 0 or length <= cfg.max_train_length)
end

--- Rückweg-Sperre: Blieb Ware an diesem Abnehmer als Rest übrig, liefert kein Cleanup sie ihm
--- eine Weile zurück – sonst pendelt dieselbe Ware Abnehmer → Cleanup → Abnehmer.
local RETURN_BLOCK = 5 * 60 * 60
local function blocked(provider, requester_unit, key)
  if provider.config.mode ~= "cleanup" then return false end
  if not storage.cfg.cleanup_offer then return true end -- Kartenschalter: Cleanups bieten nichts an
  local by_key = storage.dispatch.return_block[requester_unit]
  local since = by_key and by_key[key]
  if not since then return false end
  if game.tick - since < RETURN_BLOCK then return true end
  by_key[key] = nil -- abgelaufen
  if next(by_key) == nil then storage.dispatch.return_block[requester_unit] = nil end
  return false
end

--- Offene Anfragen einsammeln (reihum über die Abnehmer).
local function collect_requests()
  local dispatch = storage.dispatch
  local requesters = dispatch.requesters
  local unit = dispatch.cursor
  if unit and not requesters[unit] then unit = nil end
  local list = {}
  for _ = 1, REQUESTER_SCAN do
    unit = next(requesters, unit)
    if not unit then break end
    local station = Registry.get(unit)
    if not station then
      Index.remove(unit)
    -- `has_room` wird hier **nicht** geprüft: beim Nachladen geht der Bedarf auf einen Zug, der
    -- ohnehin schon unterwegs ist. Für neue Lieferungen prüft es `Dispatch.run`.
    elseif usable(station) and station.config.roles.requester then
      local cfg = station.config
      for key, amount in pairs(station.request) do -- Items und Flüssigkeiten
        local need = amount - Deliveries.incoming(unit, key)
        local minimum = Reader.threshold(cfg.request_threshold, cfg.request_stack_threshold, key)
        if need >= minimum then
          list[#list + 1] = { station = station, key = key, need = need, minimum = minimum,
            priority = cfg.request_priority }
        end
      end
    end
  end
  dispatch.cursor = unit
  table.sort(list, function(a, b) return a.priority > b.priority end)
  return list
end

--- Beste Anbieter für eine Anfrage (höchstens PROVIDER_TRIES, sortiert).
local function find_providers(request)
  local set = storage.dispatch.providers[request.key]
  if not set then return nil end
  local requester = request.station
  local network = requester.config.network
  local surface, force = requester.stop.surface_index, requester.stop.force_index
  local place = Networks.place(surface, force)
  local position = requester.stop.position
  local found = {}
  local scanned = 0
  for unit in pairs(set) do
    scanned = scanned + 1
    if scanned > PROVIDER_SCAN then break end
    local provider = Registry.get(unit)
    if not provider then
      set[unit] = nil
    elseif unit ~= requester.unit and usable(provider) and provider.config.roles.provider
      and provider.stop.surface_index == surface and provider.stop.force_index == force
      and Networks.related(place, provider.config.network, network)
      and has_room(provider) and not blocked(provider, requester.unit, request.key) then
      local available = (provider.provide[request.key] or 0) - Deliveries.outgoing(unit, request.key)
      if available > 0 then
        found[#found + 1] = {
          station = provider,
          amount = math.min(available, request.need),
          rank = Fields.provider_rank(provider.config), -- Cleanup „Reserve“/„zuerst leeren“
          priority = provider.config.provide_priority,
          distance = dist2(provider.stop.position, position),
        }
      end
    end
  end
  table.sort(found, function(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.priority ~= b.priority then return a.priority > b.priority end
    if a.amount ~= b.amount then return a.amount > b.amount end
    return a.distance < b.distance
  end)
  return found
end

--- Laderaum eines Zugs für eine Ware: Items in Slots × Stackgröße (ohne gesperrte Slots),
--- Flüssigkeiten in der Summe der Tanks. 0 = passt nicht (Güterzug ↔ Flüssigkeitszug).
local function capacity_of(record, key, locked)
  local size = stack_size(key)
  if size then return math.max(0, record.slots - record.wagons * locked) * size end
  return record.fluid
end

--- Ladeliste: die angefragte Ware plus – bei Items – weitere Waren, die derselbe Anbieter hat und
--- derselbe Abnehmer braucht, solange Slots frei sind (wenige Züge, volle Ladungen).
local function build_manifest(request, provider, record, amount)
  local manifest = { [request.key] = amount }
  local size = stack_size(request.key)
  if not size then return manifest end -- Flüssigkeit: ein Wagen je Sorte, keine Mischung
  local p, r = provider.station, request.station
  local free = (record.slots - record.wagons * p.config.locked_slots) - math.ceil(amount / size)
  local r_cfg = r.config
  for key, wanted in pairs(r.request) do
    if free <= 0 then break end
    local size2 = stack_size(key)
    local offered = p.provide[key]
    if key ~= request.key and size2 and offered and not blocked(p, r.unit, key) then
      local need = wanted - Deliveries.incoming(r.unit, key)
      local available = offered - Deliveries.outgoing(p.unit, key)
      local minimum = Reader.threshold(r_cfg.request_threshold, r_cfg.request_stack_threshold, key)
      local take = math.min(need, available, free * size2)
      if take > 0 and (take >= minimum or take == free * size2) and need >= minimum then
        manifest[key] = take
        free = free - math.ceil(take / size2)
      end
    end
  end
  return manifest
end

--- Gehört (amount, distance) in die Bestenliste `best` (höchstens TRAIN_TRIES)?
--- Mehr Ladung zuerst, dann näher am Anbieter.
local function better(amount, distance, other)
  return amount > other.amount or (amount == other.amount and distance < other.distance)
end

--- In die sortierte Bestenliste einfügen. Neue Tabellen nur für Züge, die hineinkommen.
local function keep_best(best, record, amount, distance)
  local n = #best
  if n >= TRAIN_TRIES then
    if not better(amount, distance, best[n]) then return end
    best[n] = nil
    n = n - 1
  end
  local i = n + 1
  while i > 1 and better(amount, distance, best[i - 1]) do
    best[i] = best[i - 1]
    i = i - 1
  end
  best[i] = { record = record, amount = amount, distance = distance }
end

--- Zug-Pools, die einem Abnehmer helfen dürfen: sein eigenes Netz und – im Stern – das Zentrum
--- bzw. die Partner. Liefert eine Liste (leer, wenn nirgends ein freier Zug steht).
local function pools_for(station)
  local pools = {}
  local idle = storage.trains.idle
  local stop = station.stop
  local place = stop and stop.valid and Networks.place_of(stop)
  if not place then return pools end
  for _, name in ipairs(Networks.related_list(place, station.config.network)) do
    local pool = idle[place .. "|" .. name]
    if pool and next(pool) ~= nil then pools[#pools + 1] = pool end
  end
  return pools
end

--- Freier Zug für Anbieter → Abnehmer. Liefert Zug-Eintrag und Menge.
--- Die Vorauswahl nutzt nur gespeicherte Werte (Position, Länge, Laderaum) – keine
--- API-Aufrufe je Zug. Erst die besten Kandidaten werden beim Spiel geprüft.
local function find_train(request, provider, wanted)
  local pools = pools_for(request.station)
  if #pools == 0 then return nil end
  local p_cfg, r_cfg = provider.station.config, request.station.config
  local p_stop = provider.station.stop
  local surface, force, position = p_stop.surface_index, p_stop.force_index, p_stop.position
  local locked = p_cfg.locked_slots
  local by_id = storage.trains.by_id
  local best = {}
  local scanned = 0
  for _, pool in ipairs(pools) do
    for id in pairs(pool) do
      scanned = scanned + 1
      if scanned > TRAIN_SCAN then break end
      local record = by_id[id]
      if not record then
        pool[id] = nil
      elseif record.surface_index == surface and record.force_index == force -- gleiches Team
        and length_ok(p_cfg, record.length) and length_ok(r_cfg, record.length) then
        local capacity = capacity_of(record, request.key, locked)
        if capacity > 0 then
          local amount = wanted < capacity and wanted or capacity
          -- Keine Kleinstfahrten: mindestens die Abnehmer-Schwelle oder ein voller Zug.
          if amount >= request.minimum or amount == capacity then
            keep_best(best, record, amount, dist2(record.position, position))
          end
        end
      end
    end
  end
  for i = 1, #best do
    local record = best[i].record
    if not Depot.is_ready(record) then
      Depot.remove(record.id)
    else
      -- Knapp an Treibstoff (und es gibt Tankstellen): nur mit Tankhalt losschicken. Ist gerade
      -- keine frei, bleibt der Zug im Depot (regelmäßig neuer Versuch). Ohne Tankstellen im
      -- Netzwerk fährt er normal.
      local fuel_stop = nil
      local usable = true
      if Fuel.needs_station(record.train, record.network) then
        fuel_stop = Fuel.stop_if_low(record.train, record.network)
        usable = fuel_stop ~= nil
      end
      if usable then
        local reachable = Reach.check(record.train, record.stop, p_stop)
        if reachable then return record, best[i].amount, nil, fuel_stop end
        if reachable == nil then return nil, nil, true end -- Such-Budget aufgebraucht: später
      end
    end
  end
  return nil
end

Select.has_room = has_room
Select.length_ok = length_ok
Select.requests = collect_requests
Select.providers = find_providers
Select.capacity_of = capacity_of
Select.manifest = build_manifest
Select.pools_for = pools_for
Select.train = find_train

return Select
