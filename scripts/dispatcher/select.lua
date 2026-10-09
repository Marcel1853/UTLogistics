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
local Warn = require("scripts.dispatcher.no-train-alerts")
local Elevators = require("scripts.compat.se-elevators")
local ActivePush = require("scripts.dispatcher.active-push")
local TrainFilter = require("scripts.api.train-filter")

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
  local mode = provider.config.mode
  if mode ~= "cleanup" and mode ~= "storage" then return false end -- Lager nimmt ebenfalls Restladung an
  if mode == "cleanup" and not storage.cfg.cleanup_offer then return true end -- Kartenschalter
  local by_key = storage.dispatch.return_block[requester_unit]
  local since = by_key and by_key[key]
  if not since then return false end
  if game.tick - since < RETURN_BLOCK then return true end
  by_key[key] = nil -- abgelaufen
  if next(by_key) == nil then storage.dispatch.return_block[requester_unit] = nil end
  return false
end

--- Offene Anfragen einsammeln (reihum über die Abnehmer).
--- `peek` = true: Reihum-Zeiger nicht weiterschieben (Anschlussfahrt, sonst überspränge der
--- nächste Dispatcher-Lauf diese Abnehmer).
local function collect_requests(peek)
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
        -- Lager: Mindest/Höchst sind seine Schwellen – eine Fahrt bis Höchst lohnt immer
        if cfg.roles.storage and need > 0 and need < minimum then minimum = need end
        if need >= minimum then
          list[#list + 1] = { station = station, key = key, need = need, minimum = minimum,
            priority = cfg.request_priority, storage = cfg.roles.storage,
            -- seit wann offen (dieselbe Uhr wie die Warnung „kein Zug“; beim Beliefern zurückgesetzt)
            since = Warn.waiting_since(unit, key), tier = ActivePush.TIER_REQUEST }
        end
      end
      -- Lager über dem Mindest: bis Höchst auffüllen, aber nur aus aktiven Anbietern
      if cfg.roles.storage and station.fill and next(dispatch.active) ~= nil then
        for key, amount in pairs(station.fill) do
          local need = amount - Deliveries.incoming(unit, key)
          if need > 0 then
            list[#list + 1] = { station = station, key = key, need = need, minimum = need,
              priority = cfg.request_priority, storage = true, only_active = true,
              tier = ActivePush.TIER_FILL, since = game.tick }
          end
        end
      end
    end
  end
  if not peek then dispatch.cursor = unit end
  ActivePush.collect(list, peek) -- Rest aktiver Anbieter ins Cleanup
  -- echte Anfragen vor „Auffüllen“ und „ab ins Cleanup“ (aktive Anbieter); dann höhere Priorität;
  -- bei gleicher Priorität echte Abnehmer vor Lagern (Lager sind Puffer),
  -- dann die älteste Anfrage (sonst gewinnt bei knappen Zügen immer derselbe – Reihenfolge von pairs)
  table.sort(list, function(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end
    if a.priority ~= b.priority then return a.priority > b.priority end
    if (a.storage == true) ~= (b.storage == true) then return not a.storage end
    if a.since ~= b.since then return a.since < b.since end
    if a.station.unit ~= b.station.unit then return a.station.unit < b.station.unit end
    return a.key < b.key
  end)
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
  -- Space Exploration: Orte hinter einem Weltraumaufzug (gleichnamiges Netz, Schalter an)
  local linked = Elevators.linked_places(place, network)
  local found = {}
  -- Reihum je Ware höchstens PROVIDER_SCAN Anbieter (die Menge gilt für die ganze Karte): mit festem
  -- Anfang kämen Anbieter ab Platz 51 nie dran, auch nicht die nächsten oder vollsten.
  local cursors = storage.dispatch.provider_cursor or {}
  storage.dispatch.provider_cursor = cursors
  local unit = cursors[request.key]
  if unit ~= nil and set[unit] == nil then unit = nil end
  local first = nil
  for _ = 1, PROVIDER_SCAN do
    unit = next(set, unit)
    if unit == nil then unit = next(set) end -- am Ende vorne weiter
    if unit == nil or unit == first then break end
    first = first or unit
    local provider = Registry.get(unit)
    if not provider then
      set[unit] = nil
    elseif unit ~= requester.unit and usable(provider) and provider.config.roles.provider
      and (not request.only_active or Fields.is_active(provider.config))
      and has_room(provider) and not blocked(provider, requester.unit, request.key) then
      local p_stop = provider.stop
      local via = nil
      local ok = p_stop.surface_index == surface and p_stop.force_index == force
        and Networks.related(place, provider.config.network, network)
      if not ok and linked and provider.config.network == network then
        local p_place = Networks.place(p_stop.surface_index, p_stop.force_index)
        via = linked[p_place] and Elevators.route(p_place, place, network, p_stop.position) or nil
        ok = via ~= nil
      end
      local available = ok and (provider.provide[request.key] or 0) - Deliveries.outgoing(unit, request.key) or 0
      if available > 0 then
        found[#found + 1] = {
          via = via, -- über den Aufzug: { here = Aufzug-Halt beim Anbieter, there = beim Abnehmer }
          station = provider,
          amount = math.min(available, request.need),
          -- Rang: Cleanup „Reserve“/„zuerst leeren“; Lager normal, nur Restladung ohne Grenzen Reserve
          rank = provider.provide_rank and provider.provide_rank[request.key] or Fields.provider_rank(provider.config),
          storage = provider.config.roles.storage == true,
          priority = provider.config.provide_priority,
          -- über den Aufzug: hinter allen Anbietern auf derselben Seite
          distance = via and math.huge or dist2(p_stop.position, position),
        }
      end
    end
  end
  cursors[request.key] = unit
  table.sort(found, function(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.priority ~= b.priority then return a.priority > b.priority end
    if a.amount ~= b.amount then return a.amount > b.amount end
    if a.distance ~= b.distance then return a.distance < b.distance end
    return b.storage and not a.storage -- gleich weit: normaler Anbieter vor Lager
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

--- Weitere Waren, die ein aktiver Anbieter gleich mitgeben darf: beim Lager das, was es auffüllen
--- will, beim Cleanup alles, was es annimmt (soviel der Anbieter hat).
local function extra_for_active(request, provider)
  local r = request.station
  if r.config.roles.storage then return r.fill or {} end
  local extra = {}
  for key, amount in pairs(provider.provide) do
    local kind, name = Util.split_key(key)
    if Fields.cleanup_accepts(r.config, kind, name) then extra[key] = amount end
  end
  return extra
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
  local wanted_list = r.request
  if request.only_active then wanted_list = extra_for_active(request, p) end
  for key, wanted in pairs(wanted_list) do
    if free <= 0 then break end
    local size2 = stack_size(key)
    local offered = p.provide[key]
    if key ~= request.key and size2 and offered and not blocked(p, r.unit, key) then
      -- Cleanup nimmt alles an: was schon unterwegs ist, zählt dort nicht gegen
      local push = request.only_active and not r_cfg.roles.storage
      local need = push and wanted or wanted - Deliveries.incoming(r.unit, key)
      local available = offered - Deliveries.outgoing(p.unit, key)
      -- Lager: Mindest und Höchst sind die Schwellen, die allgemeine Bedarfs-Schwelle gilt nicht
      -- (sonst käme eine zweite Ware nie mit, solange sie unter 1000 liegt); ebenso beim Leeren
      local minimum = (r_cfg.roles.storage or push) and 1
        or Reader.threshold(r_cfg.request_threshold, r_cfg.request_stack_threshold, key)
      local take = math.min(need, available, free * size2)
      if take > 0 and (take >= minimum or take == free * size2) and need >= minimum then
        manifest[key] = take
        free = free - math.ceil(take / size2)
      end
    end
  end
  return manifest
end

--- Lohnt die Fahrt? Mindestens die Abnehmer-Schwelle oder ein voller Zug. (Die „Mindestladung je
--- Fahrt“ prüft `Select.full_enough` erst mit der fertigen Ladeliste – andere Waren zählen mit.)
local function worth(amount, capacity, request)
  return amount >= request.minimum or amount == capacity
end
Select.worth = worth

--- Map-Einstellung „Mindestladung je Fahrt“: Ist die ganze Ladeliste (alle Waren, die der Anbieter
--- mitgibt) mindestens so viel Prozent des Laderaums? Items nach Slots, Flüssigkeit nach Tankinhalt.
function Select.full_enough(record, manifest, locked)
  local percent = storage.cfg.min_load_percent or 0
  if percent <= 0 then return true end
  local slots_used, fluid_used = 0, 0
  for key, amount in pairs(manifest) do
    local size = stack_size(key)
    if size then slots_used = slots_used + math.ceil(amount / size) else fluid_used = fluid_used + amount end
  end
  local slots = math.max(0, record.slots - record.wagons * (locked or 0))
  local share = 0
  if slots > 0 then share = slots_used / slots end
  if record.fluid and record.fluid > 0 then share = math.max(share, fluid_used / record.fluid) end
  return share * 100 >= percent
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
  -- Züge hinter einem Weltraumaufzug (sie holen beim Anbieter auf ihrer Seite ab)
  for other in pairs(Elevators.linked_places(place, station.config.network) or {}) do
    local pool = idle[other .. "|" .. station.config.network]
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
          -- Keine Kleinstfahrten (Schwelle, voller Zug, Mindestladung)
          if worth(amount, capacity, request) then
            keep_best(best, record, amount, dist2(record.position, position))
          end
        end
      end
    end
  end
  -- Add-ons dürfen bei Fahrten von/zu ihren Rollen mitreden (nur dann ein remote.call)
  best = TrainFilter.apply(best, provider.station, request.station, request.key)
  for i = 1, #best do
    local record = best[i].record
    if not Depot.is_ready(record) then
      Depot.remove(record.id)
    else
      -- Knapp an Treibstoff und eine Tankstelle erreichbar: mit Tankhalt losschicken; ist gerade
      -- keine frei, fährt er trotzdem. Unter dem Mindest-Treibstoff fährt er nur mit Tankhalt –
      -- sonst bleibt er im Depot (Warnung aus depot.lua).
      local fuel_stop = nil
      local usable = true
      if Fuel.needs_station(record.train, record.network, record.stop) then
        fuel_stop = Fuel.stop_if_low(record.train, record.network)
        usable = fuel_stop ~= nil or not Fuel.is_empty(record.train)
      elseif Fuel.is_empty(record.train) then
        usable = false
      end
      if usable then
        -- Anbieter UND Abnehmer müssen erreichbar sein: In einem Netz können getrennte Gleis-
        -- bzw. Wassernetze liegen (Cargo Ships: Häfen und Haltestellen im selben UTL-Netz)
        -- Über den Aufzug: statt des Abnehmers (andere Oberfläche) den Aufzug-Halt dieser Seite prüfen
        local reachable = Reach.check(record.train, record.stop, p_stop)
        local target = provider.via and provider.via.here or request.station.stop
        if reachable then reachable = Reach.check(record.train, record.stop, target) end
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
