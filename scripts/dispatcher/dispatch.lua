--- Dispatcher: verbindet Bedarf mit Angebot und einem freien Zug.
---
--- Pro Lauf fest gedeckelt (UPS):
---   * höchstens REQUESTER_SCAN Abnehmer ansehen (reihum, fair),
---   * höchstens `max_deliveries` neue Lieferungen,
---   * pro Anfrage höchstens PROVIDER_TRIES Anbieter und TRAIN_TRIES Pfadsuchen – und die meist
---     gar nicht, weil die Erreichbarkeit je Depot und Anbieter gecacht ist (reach.lua).
---
--- Auswahl (Ziel: wenige Züge, volle Ladungen):
---   Anfragen:  höhere Abnehmer-Priorität zuerst.
---   Anbieter:  höhere Anbieter-Priorität, dann mehr lieferbare Menge, dann näher am Abnehmer.
---   Zug:       mehr Ladung pro Fahrt zuerst, dann näher am Anbieter; erreichbar laut Pfadsuche.
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Deliveries = require("scripts.deliveries.deliveries")
local Networks = require("scripts.stations.networks")
local Depot = require("scripts.trains.depot")
local Index = require("scripts.dispatcher.index")
local Util = require("scripts.lib.util")
local Alerts = require("scripts.alerts.alerts")
local Reach = require("scripts.dispatcher.reach")
local Fuel = require("scripts.trains.fuel")

local Dispatch = {}

local REQUESTER_SCAN = 20
local PROVIDER_SCAN = 50
local PROVIDER_TRIES = 3
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
    elseif usable(station) and station.config.roles.requester and has_room(station) then
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
  local surface = requester.stop.surface_index
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
      and provider.stop.surface_index == surface and Networks.related(surface, provider.config.network, network)
      and has_room(provider) then
      local available = (provider.provide[request.key] or 0) - Deliveries.outgoing(unit, request.key)
      if available > 0 then
        found[#found + 1] = {
          station = provider,
          amount = math.min(available, request.need),
          priority = provider.config.provide_priority,
          distance = dist2(provider.stop.position, position),
        }
      end
    end
  end
  table.sort(found, function(a, b)
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
    if key ~= request.key and size2 and offered then
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
  local surface = stop and stop.valid and stop.surface_index
  for _, name in ipairs(surface and Networks.related_list(surface, station.config.network)
      or { station.config.network }) do
    local pool = idle[name]
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
  local surface, position = p_stop.surface_index, p_stop.position
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
      elseif record.surface_index == surface
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

--- Rich-Text-Symbol einer Ware für Warnungen, z. B. „[item=iron-plate]“.
local function ware_icon(key)
  local kind, name, quality = Util.split_key(key)
  if kind == "item" and quality ~= "normal" then return "[item=" .. name .. ",quality=" .. quality .. "]" end
  return "[" .. kind .. "=" .. name .. "]"
end

-- War eine Anfrage länger nicht mehr offen (Bedarf zwischendurch gedeckt), beginnt die
-- Wartezeit neu. Großzügig, weil Abnehmer nur reihum (20 pro Lauf) angesehen werden.
local WAITING_GAP = 3600

--- Seit wann wartet diese Anfrage unbedient? storage.dispatch.waiting[station][key] =
--- { since = tick, seen = tick }. `reset` = Anfrage bedient (Wartezeit verwerfen).
local function waiting_since(unit, key, reset)
  local waiting = storage.dispatch.waiting
  local by_key = waiting[unit]
  if reset then
    if by_key then by_key[key] = nil end
    return nil
  end
  if not by_key then
    by_key = {}
    waiting[unit] = by_key
  end
  local now = game.tick
  local entry = by_key[key]
  if not entry or now - entry.seen > WAITING_GAP then
    entry = { since = now, seen = now }
    by_key[key] = entry
  end
  entry.seen = now
  return entry.since
end

--- Anbieter da, aber kein Zug: warnen – erst wenn die Anfrage länger als die eingestellte
--- Wartezeit unbedient ist und gerade kein Zug mit dieser Ware zu ihr unterwegs ist.
local function warn_no_train(request, provider)
  local requester = request.station
  local unit, key = requester.unit, request.key
  if Deliveries.incoming(unit, key) > 0 then
    waiting_since(unit, key, true) -- ein Zug bringt die Ware schon: gilt als bedient
    return
  end
  local since = waiting_since(unit, key)
  if game.tick - since < storage.cfg.alert_no_train_minutes * 3600 then return end
  local cfg = requester.config
  if #pools_for(requester) == 0 then
    -- Kein freier Zug im ganzen Netzwerk: nicht je Abnehmer warnen (sonst blinkt die halbe Karte),
    -- sondern sammeln – Dispatch.starving_alerts meldet eine Warnung je Netzwerk.
    local starving = storage.dispatch.starving
    local by_net = starving[cfg.network]
    if not by_net then
      by_net = {}
      starving[cfg.network] = by_net
    end
    by_net[unit .. "|" .. key] = { seen = game.tick, since = since, stop = requester.stop }
    return
  end
  -- Züge frei, aber keiner passt (Länge/Laderaum): Einstellungsfehler an dieser Station.
  local message = { "utl-alert.no-fitting-train", ware_icon(request.key), provider.station.stop.backer_name,
    requester.stop.backer_name, cfg.network }
  Alerts.raise("no_train", "no_train", requester.stop, message, "no-train:" .. requester.unit .. ":" .. request.key)
end

--- Heartbeat-Aufgabe (selten): je Netzwerk eine Sammelwarnung „N Anfragen warten auf einen Zug“,
--- angeheftet an den Abnehmer, der am längsten wartet. Einträge, die länger nicht mehr gesehen
--- wurden (Anfrage bedient/weg), fallen heraus.
function Dispatch.starving_alerts()
  local now = game.tick
  for network, by_net in pairs(storage.dispatch.starving) do
    local count = 0
    local oldest ---@type { stop: LuaEntity, since: integer, seen: integer }?
    for id, entry in pairs(by_net) do
      if now - entry.seen > 7200 or not entry.stop.valid then
        by_net[id] = nil
      else
        count = count + 1
        if not oldest or entry.since < oldest.since then oldest = entry end
      end
    end
    if count == 0 or not oldest then
      storage.dispatch.starving[network] = nil
    else
      Alerts.raise("no_train", "no_train", oldest.stop,
        { "utl-alert.no-free-trains", network, count, math.floor((now - oldest.since) / 3600) },
        "no-train-net:" .. network)
    end
  end
end

local function try_request(request)
  -- Kein einziger freier Zug im Netzwerk: nicht nach Anbietern suchen (spart im Dauerbetrieb den
  -- Großteil der Zeit). Nur die Wartezeit für die Warnung mitführen; erst wenn gewarnt würde,
  -- wird ein Anbieter für den Text gesucht.
  if #pools_for(request.station) == 0 then
    local unit, key = request.station.unit, request.key
    if Deliveries.incoming(unit, key) > 0 then
      waiting_since(unit, key, true)
      return false
    end
    if game.tick - waiting_since(unit, key) < storage.cfg.alert_no_train_minutes * 3600 then return false end
    local providers = find_providers(request)
    if providers and #providers > 0 then warn_no_train(request, providers[1]) end
    return false
  end
  local providers = find_providers(request)
  if not providers or #providers == 0 then return false end
  for i = 1, math.min(#providers, PROVIDER_TRIES) do
    local provider = providers[i]
    local record, amount, later, fuel_stop = find_train(request, provider, provider.amount)
    if later then return false, true end -- im nächsten Lauf weiter, keine Warnung
    if record then
      local manifest = build_manifest(request, provider, record, amount)
      local created = Deliveries.create(record, provider.station, request.station, manifest, fuel_stop) ~= nil
      if created then waiting_since(request.station.unit, request.key, true) end
      return created
    end
  end
  warn_no_train(request, providers[1])
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
    position = front.position, length = #train.carriages, slots = slots, wagons = wagons, fluid = fluid,
    stop = from_stop, depot_name = depot_name,
  }
  Index.update()
  local best
  for _, request in ipairs(collect_requests()) do
    if Networks.related(record.surface_index, request.station.config.network, network) then
      local providers = find_providers(request) or {}
      for i = 1, math.min(#providers, PROVIDER_TRIES) do
        local provider = providers[i]
        local p_cfg, r_cfg = provider.station.config, request.station.config
        local capacity = capacity_of(record, request.key, p_cfg.locked_slots)
        if capacity > 0 and length_ok(p_cfg, record.length) and length_ok(r_cfg, record.length) then
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
  local manifest = build_manifest(best.request, best.provider, record, best.amount)
  local delivery = Deliveries.create(record, best.provider.station, best.request.station, manifest, nil)
  if delivery then
    delivery.chained = true
    storage.deliveries.chained = (storage.deliveries.chained or 0) + 1
    waiting_since(best.request.station.unit, best.request.key, true)
  end
  return delivery
end

--- Heartbeat-Aufgabe.
function Dispatch.run()
  Index.update()
  Reach.begin_run()
  -- Auch ohne freie Züge weiterlaufen (gedeckelt), damit „kein freier Zug“ gewarnt werden kann.
  local requests = collect_requests()
  local budget = storage.cfg.max_deliveries
  local created = 0
  local busy = {} -- pro Lauf nur eine neue Lieferung je Abnehmer
  for i = 1, #requests do
    if created >= budget then break end
    local request = requests[i]
    local unit = request.station.unit
    if not busy[unit] and has_room(request.station) then
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
