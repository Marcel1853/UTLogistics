--- Warnungen „kein Zug“ für den Dispatcher: Wartezeiten je Anfrage, die Einzelwarnung „kein
--- passender Zug“ und die Sammelwarnung „N Anfragen warten“ je Netz und Ort.
local Deliveries = require("scripts.deliveries.deliveries")
local Networks = require("scripts.stations.networks")
local Util = require("scripts.lib.util")
local Alerts = require("scripts.alerts.alerts")
local Depot = require("scripts.trains.depot")
local Log = require("scripts.lib.log")

local Warn = {}

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
function Warn.waiting_since(unit, key, reset)
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

local FIT_CACHE = 600 -- so lange gilt „ein passender Zug ist unterwegs“ je Anfrage (Ticks)

local function length_ok(cfg, length)
  return (cfg.min_train_length <= 0 or length >= cfg.min_train_length)
    and (cfg.max_train_length <= 0 or length <= cfg.max_train_length)
end

--- Laderaum eines Zugs, einmal gemessen und am Heimat-Eintrag gemerkt (ändert sich nur mit neuer
--- Zug-ID – dann gibt es einen neuen Eintrag).
local function measured(home, train)
  local m = home.measured
  if not m or m.id ~= train.id then
    local slots, wagons, fluid = Depot.measure(train)
    m = { id = train.id, slots = slots, wagons = wagons, fluid = fluid, length = #train.carriages }
    home.measured = m
  end
  return m
end

--- Gibt es im Netz der Anfrage einen UTL-Zug, der die Ware fahren könnte – frei, mit Lieferung oder
--- auf dem Heimweg? Dann ist „kein passender Zug“ falsch, es ist nur gerade keiner frei
--- (Sammelwarnung statt Einstellungsfehler). Gezählt werden Züge mit Heimatdepot (storage.trains.home)
--- in einem Netz, das der Anfrage helfen darf. Läuft nur, wenn sonst gewarnt würde; Ergebnis kurz
--- gemerkt (Regel 5).
local function fitting_train_exists(request, provider)
  local requester = request.station
  local cache = storage.dispatch.fit_cache
  local cache_key = requester.unit .. "|" .. request.key
  local entry = cache[cache_key]
  if entry and game.tick - entry.tick < FIT_CACHE then return entry.fits end
  local kind = Util.split_key(request.key)
  local place = Networks.place_of(requester.stop)
  local stations = storage.stations
  local r_cfg, p_cfg = requester.config, provider.station.config
  local locked = p_cfg.locked_slots or 0
  local fits = false
  for _, home in pairs(storage.trains.home) do
    local train, stop = home.train, home.stop
    if train and train.valid and stop and stop.valid and Networks.place_of(stop) == place then
      local unit = stations.by_stop[stop.unit_number]
      local depot = unit and stations.by_unit[unit]
      if depot and Networks.related(place, r_cfg.network, depot.config.network or "default") then
        local m = measured(home, train)
        local capacity = kind == "fluid" and m.fluid or (m.slots - m.wagons * locked)
        if capacity > 0 and length_ok(p_cfg, m.length) and length_ok(r_cfg, m.length) then
          fits = true
          break
        end
      end
    end
  end
  if Log.on() then Log.debug("fitting_train_exists " .. cache_key .. " = " .. tostring(fits) .. " (Netz " .. r_cfg.network .. ")") end
  cache[cache_key] = { tick = game.tick, fits = fits }
  return fits
end

--- Anbieter da, aber kein Zug: warnen – erst wenn die Anfrage länger als die eingestellte
--- Wartezeit unbedient ist und gerade kein Zug mit dieser Ware zu ihr unterwegs ist.
--- `has_pools` = es stehen freie Züge im Netz (der Aufrufer weiß das schon).
function Warn.no_train(request, provider, has_pools)
  local requester = request.station
  local unit, key = requester.unit, request.key
  if Deliveries.incoming(unit, key) > 0 then
    Warn.waiting_since(unit, key, true) -- ein Zug bringt die Ware schon: gilt als bedient
    return
  end
  local since = Warn.waiting_since(unit, key)
  if game.tick - since < storage.cfg.alert_no_train_minutes * 3600 then return end
  local cfg = requester.config
  -- Freie Züge passen nicht, aber ein passender ist gerade unterwegs: wie „kein freier Zug“ sammeln
  if not has_pools or fitting_train_exists(request, provider) then
    -- Kein freier Zug im ganzen Netzwerk: nicht je Abnehmer warnen (sonst blinkt die halbe Karte),
    -- sondern sammeln – Dispatch.starving_alerts meldet eine Warnung je Netzwerk.
    -- Schlüssel mit Ort: sonst unterdrückt die Warnung eines Teams die eines anderen
    local starving = storage.dispatch.starving
    local net_key = Networks.place_of(requester.stop) .. "|" .. cfg.network
    local by_net = starving[net_key]
    if not by_net then
      by_net = { network = cfg.network }
      starving[net_key] = by_net
    end
    by_net[unit .. "|" .. key] = { seen = game.tick, since = since, stop = requester.stop }
    return
  end
  if Log.on() then
    Log.debug("Kein passender Zug für " .. request.key .. " an " .. Log.stop_name(requester.stop) .. " (Netz „"
      .. cfg.network .. "“, " .. table_size(storage.deliveries.active) .. " Lieferungen laufen).")
  end
  -- Züge frei, aber keiner im Netz passt (Länge/Laderaum), auch kein beschäftigter oder heimfahrender:
  -- Einstellungsfehler an dieser Station.
  local message = { "utl-alert.no-fitting-train", ware_icon(request.key), provider.station.stop.backer_name,
    requester.stop.backer_name, cfg.network }
  Alerts.raise("no_train", "no_train", requester.stop, message, "no-train:" .. requester.unit .. ":" .. request.key)
end

--- Heartbeat-Aufgabe (selten): je Netzwerk eine Sammelwarnung „N Anfragen warten auf einen Zug“,
--- angeheftet an den Abnehmer, der am längsten wartet. Einträge, die länger nicht mehr gesehen
--- wurden (Anfrage bedient/weg), fallen heraus.
function Warn.starving_alerts()
  local now = game.tick
  for net_key, by_net in pairs(storage.dispatch.starving) do
    local network = by_net.network or net_key
    local count = 0
    local oldest ---@type { stop: LuaEntity, since: integer, seen: integer }?
    for id, entry in pairs(by_net) do
      if id == "network" then -- Name des Netzes, kein Eintrag: überspringen
      elseif now - entry.seen > 7200 or not entry.stop.valid then
        by_net[id] = nil
      else
        count = count + 1
        if not oldest or entry.since < oldest.since then oldest = entry end
      end
    end
    if count == 0 or not oldest then
      storage.dispatch.starving[net_key] = nil
    else
      Alerts.raise("no_train", "no_train", oldest.stop,
        { "utl-alert.no-free-trains", network, count, math.floor((now - oldest.since) / 3600) },
        "no-train-net:" .. net_key)
    end
  end
end

return Warn
