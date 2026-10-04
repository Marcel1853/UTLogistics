--- Lager: Angebot und Bedarf aus dem Bestand und den Grenzen je Ware.
---
---   Bestand:  0 ──── Mindest ════════════════════ ∞
---             fordert an   bietet an (wie ein normaler Anbieter –
---             bis Höchst   liegt das Lager näher am Abnehmer, gewinnt es)
---
--- * Unter Mindest: Anforderung = Höchst − Bestand (auffüllen bis Höchst, nicht nur bis Mindest –
---   sonst füllt es sich in vielen kleinen Fahrten knapp über die Grenze).
--- * Angebot = Bestand − Mindest, gleichrangig mit normalen Anbietern (Entscheidung Marcel): ein
---   Lager ist Puffer für kurze Wege – bei gleicher Menge gewinnt der nähere.
--- * Waren ohne Grenzen (z. B. angenommene Restladung): ganz anbieten, Rang „Reserve“.
--- * Zwischen Mindest und Höchst: „Auffüllen“ = Höchst − Bestand – nur aus aktiven Anbietern
---   (Schalter am Anbieter, wie die aktive Anbieterkiste: der Bahnhof soll leer werden).
--- Kein Hin- und Herschieben zwischen zwei Lagern: angeboten wird nur, was über dem Mindest liegt,
--- angefordert nur unter dem Mindest – Ware wandert höchstens einmal von „zu viel“ nach „zu wenig“.
--- Die allgemeinen Anbieter-/Bedarfs-Schwellen gelten hier nicht: Mindest und Höchst sind die
--- Schwellen, die der Spieler bewusst setzt (mit den Voreinstellungen fiele ein Lager mit Höchst
--- 800 sonst still aus). Kleinstfahrten verhindert weiterhin die Schwelle des Abnehmers.
local Util = require("scripts.lib.util")
local Fields = require("scripts.stations.fields")

local StorageReader = {}

local signal_key = Util.signal_key

--- Neue Tabellen berechnen. `net` = Bestand je Ware (ohne Anforderungs-Slots), `enabled` =
--- Kartenschalter. Liefert Angebot, Bedarf, Rang und Auffüllen (nur aus aktiven Anbietern).
function StorageReader.compute(net, cfg, enabled)
  local provide, request, rank, fill = {}, {}, {}, {}
  if not enabled then return provide, request, rank, fill end
  local limited = {}
  for _, limit in pairs(cfg.storage.limits) do
    local key = limit.signal and signal_key(limit.signal)
    if key then
      limited[key] = true
      local stock = math.max(0, net[key] or 0)
      local min = math.max(0, limit.min or 0)
      local max = math.max(min, limit.max or 0)
      if stock < min and max > stock then
        request[key] = max - stock
      elseif max > stock then
        fill[key] = max - stock
      end
      local spare = stock - min
      if spare > 0 then
        provide[key] = spare
        rank[key] = Fields.RANK_NORMAL
      end
    end
  end
  for key, n in pairs(net) do
    if not limited[key] and n > 0 then
      provide[key] = n
      rank[key] = Fields.RANK_RESERVE
    end
  end
  return provide, request, rank, fill
end

local function same(a, b)
  for key, value in pairs(a) do
    if b[key] ~= value then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

--- Station neu bewerten; nur bei Änderung Tabellen tauschen und für den Dispatcher markieren.
function StorageReader.apply(station, net, cfg)
  local enabled = storage.cfg.storage_enabled ~= false
  local provide, request, rank, fill = StorageReader.compute(net, cfg, enabled)
  -- Bestand merken (für den Netz-Kombinator, Modus „Lagerbestand“)
  local stock = {}
  for key, n in pairs(net) do
    if n > 0 then stock[key] = n end
  end
  if same(provide, station.provide) and same(request, station.request) and same(rank, station.provide_rank or {})
    and same(stock, station.stock or {}) and same(fill, station.fill or {}) then
    return
  end
  station.provide, station.provide_count = provide, count(provide)
  station.request, station.request_count = request, count(request)
  station.provide_rank = rank
  station.fill = fill
  station.stock = stock
  station.version = station.version + 1
  storage.stations.dirty[station.unit] = true
end

return StorageReader
