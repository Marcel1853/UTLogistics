--- Warnungen „kein Zug“ für den Dispatcher: Wartezeiten je Anfrage, die Einzelwarnung „kein
--- passender Zug“ und die Sammelwarnung „N Anfragen warten“ je Netz und Ort.
local Deliveries = require("scripts.deliveries.deliveries")
local Networks = require("scripts.stations.networks")
local Util = require("scripts.lib.util")
local Alerts = require("scripts.alerts.alerts")

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
  if not has_pools then
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
  -- Züge frei, aber keiner passt (Länge/Laderaum): Einstellungsfehler an dieser Station.
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
      if id == "network" then -- Name des Netzes, kein Eintrag
        count = count
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
