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
local TopUp = require("scripts.dispatcher.top-up")
local Log = require("scripts.lib.log")

local Dispatch = {}

local dist2 = Util.dist2

--- Sammelwarnung je Netz (Heartbeat-Aufgabe).
Dispatch.starving_alerts = Warn.starving_alerts

--- Umweg über `b` in Prozent der direkten Strecke a → r (Luftlinie, keine Pfadsuche).
local function detour_percent(a, b, r)
  local direct = math.sqrt(dist2(a, r))
  local via = math.sqrt(dist2(a, b)) + math.sqrt(dist2(b, r))
  if direct < 1 then return via < 1 and 0 or math.huge end
  return (via - direct) * 100 / direct
end

--- Zweiter Anbieter (Kartenwert „utl-multi-pickup“): Reicht `first` nicht für den Bedarf, den
--- nächstbesten Anbieter auf derselben Seite (nicht hinter einem Aufzug) für den Rest nehmen – nur
--- wenn der Umweg höchstens „utl-multi-pickup-detour“ Prozent ausmacht (0 = egal).
local function second_provider(request, providers, first)
  if not storage.cfg.multi_pickup or first.via or first.amount >= request.need then return nil end
  local limit = storage.cfg.multi_pickup_detour or 50
  local a, r = first.station.stop.position, request.station.stop.position
  for _, other in ipairs(providers) do
    if other ~= first and not other.via
      and (limit <= 0 or detour_percent(a, other.station.stop.position, r) <= limit) then
      return other
    end
  end
  return nil
end

local function try_request(request)
  -- Kein einziger freier Zug im Netzwerk: nicht nach Anbietern suchen (spart im Dauerbetrieb den
  -- Großteil der Zeit). Nur die Wartezeit für die Warnung mitführen; erst wenn gewarnt würde,
  -- wird ein Anbieter für den Text gesucht.
  if #Select.pools_for(request.station) == 0 then
    if request.only_active then return false end -- Leeren aktiver Anbieter: keine Warnung
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
    local second = second_provider(request, providers, provider)
    local wanted = provider.amount + (second and math.min(second.amount, request.need - provider.amount) or 0)
    local record, amount, later, fuel_stop = Select.train(request, provider, wanted)
    if later then return false, true end -- im nächsten Lauf weiter, keine Warnung
    local pickup = nil
    if record and second and amount > provider.amount then
      -- Rest beim zweiten Anbieter, wenn der Zug ihn erreicht; sonst nur der erste (falls das lohnt)
      -- Weg Depot → zweiter Anbieter, erster → zweiter und zweiter → Abnehmer (je gecacht)
      local p2 = second.station.stop
      local ok ---@type boolean?
      ok = Select.length_ok(second.station.config, record.length) -- Zuglänge auch am zweiten Halt
      if ok then ok = Reach.check(record.train, record.stop, p2) end
      if ok then ok = Reach.between(record.train, provider.station.stop, p2) end
      if ok then ok = Reach.between(record.train, p2, request.station.stop) end
      if ok == nil then return false, true end -- Such-Budget aufgebraucht: im nächsten Lauf weiter
      if ok then
        pickup = { station = second.station, manifest = { [request.key] = amount - provider.amount } }
      elseif provider.amount >= request.minimum then
        amount = provider.amount
      else
        record = nil
      end
    end
    if record then
      local manifest = Select.manifest(request, provider, record, amount)
      -- Mindestladung je Fahrt (Map-Einstellung): zu wenig für diesen Zug → noch warten
      if not Select.full_enough(record, manifest, provider.station.config.locked_slots) then return false end
      local created = Deliveries.create(record, provider.station, request.station, manifest, fuel_stop, provider.via,
        pickup) ~= nil
      if created and not request.only_active then Warn.waiting_since(request.station.unit, request.key, true) end
      return created
    end
  end
  if not request.only_active then Warn.no_train(request, providers[1], true) end
  return false
end

--- Reihenfolge der Kandidaten wie bei der normalen Auswahl (select.lua): Bedarfs-Priorität, Rang
--- des Anbieters (Cleanup „zuerst leeren“ / „nur Reserve“, Lager-Restladung), Angebots-Priorität,
--- volle Ladung, zuletzt kurzer Weg vom Zug zum Anbieter.
local function better(a, b)
  if a.request.tier ~= b.request.tier then return a.request.tier < b.request.tier end -- echte Anfragen zuerst
  if a.request.priority ~= b.request.priority then return a.request.priority > b.request.priority end
  if a.provider.rank ~= b.provider.rank then return a.provider.rank > b.provider.rank end
  if a.provider.priority ~= b.provider.priority then return a.provider.priority > b.provider.priority end
  if a.amount ~= b.amount then return a.amount > b.amount end
  return a.distance < b.distance
end

--- Direkt der nächste Auftrag (Wunsch Marcel): Ein Zug, der gerade entladen hat oder vom
--- Cleanup/Tanken kommt, übernimmt sofort eine passende Lieferung – bevorzugt mit einem Anbieter
--- in seiner Nähe – statt erst ins Depot zu fahren. `from_stop` = Haltestelle, die er gerade
--- verlässt (Schlüssel für den Erreichbarkeits-Cache). Liefert die Lieferung oder nil.
function Dispatch.chain(train, network, from_stop, depot_name)
  if not (storage.cfg.chaining and train.valid and from_stop and from_stop.valid) then return nil end
  -- erst Cleanup/Tanken; fast leer (unter dem Mindest-Treibstoff): ins Depot, keine weitere Fahrt
  if Depot.has_cargo(train) or Fuel.needs_station(train, network, from_stop) or Fuel.is_empty(train) then return nil end
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
  for _, request in ipairs(Select.requests(true)) do
    local r_stop = request.station.stop
    if Select.has_room(request.station) -- Anfragen kommen jetzt auch ohne freien Platz herein
      and r_stop.surface_index == record.surface_index and r_stop.force_index == record.force_index
      and Networks.related(Networks.place(record.surface_index, record.force_index), request.station.config.network, network) then
      local providers = Select.providers(request) or {}
      for i = 1, math.min(#providers, Select.PROVIDER_TRIES) do
        local provider = providers[i]
        local p_cfg, r_cfg = provider.station.config, request.station.config
        local capacity = Select.capacity_of(record, request.key, p_cfg.locked_slots)
        if capacity > 0 and not provider.via and Select.length_ok(p_cfg, record.length) and Select.length_ok(r_cfg, record.length) then
          local amount = math.min(provider.amount, capacity)
          if Select.worth(amount, capacity, request) then
            local distance = dist2(record.position, provider.station.stop.position)
            local candidate = { request = request, provider = provider, amount = amount, distance = distance }
            if not best or better(candidate, best) then best = candidate end
          end
        end
      end
    end
  end
  if not best then return nil end
  if not (Reach.check(train, from_stop, best.provider.station.stop, true)
      and Reach.check(train, from_stop, best.request.station.stop, true)) then return nil end
  local manifest = Select.manifest(best.request, best.provider, record, best.amount)
  if not Select.full_enough(record, manifest, best.provider.station.config.locked_slots) then return nil end
  local delivery = Deliveries.create(record, best.provider.station, best.request.station, manifest, nil)
  if delivery then
    Log.debug("Anschlussfahrt: Zug " .. train.id .. " übernimmt Lieferung " .. delivery.id .. " direkt ab "
      .. Log.stop_name(from_stop) .. ".")
    delivery.chained = true
    storage.deliveries.chained = (storage.deliveries.chained or 0) + 1
    if not best.request.only_active then Warn.waiting_since(best.request.station.unit, best.request.key, true) end
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
    -- Nachladen zuerst: der Bedarf kann auf eine laufende Lieferung gehen, auch wenn der
    -- Abnehmer sein Zuglimit schon ausgeschöpft hat (der Zug fährt ja ohnehin dorthin).
    if not busy[unit] and not request.only_active and TopUp.try(request) then
      busy[unit] = true
      created = created + 1
    elseif not busy[unit] and Select.has_room(request.station) then
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
