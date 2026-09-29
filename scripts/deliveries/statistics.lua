--- Statistik für den Manager-Reiter „Statistik“: Durchsatz je Ware und Auslastung je Zug.
--- Erfasst nur, wenn eine Lieferung endet (fertig oder abgebrochen) – kein Takt (Regel 5).
---
--- storage.statistics = {
---   since  = Tick des Beginns (oder des letzten Zurücksetzens),
---   places = { [ort] = { [slot 0..59] = { minute, goods = { [key] = Menge }, deliveries = n } } },
---   trains = { [zug] = { deliveries = n, busy = Ticks mit Auftrag, first = Tick, surface, force } },
---   stations = { [station] = { [slot 0..59] = { minute, sent = Menge, received = Menge } } },
--- }
--- Je Station nur Summen (keine Waren), damit der Speicher auch bei vielen Stationen klein bleibt.
--- Ort = Oberfläche + Team (Networks.place). Je Ort 60 Minuten-Eimer: der Eimer einer Minute wird
--- beim ersten Eintrag einer neuen Minute geleert – so bleibt der Speicher fest begrenzt.
local Networks = require("scripts.stations.networks")
local Registry = require("scripts.stations.registry")

local Statistics = {}

local MINUTE = 3600
local SLOTS = 60

function Statistics.data()
  local stats = storage.statistics
  if not stats then
    stats = { since = game.tick, places = {}, trains = {}, stations = {} }
    storage.statistics = stats
  end
  stats.stations = stats.stations or {} -- Spielstände vor der Statistik je Station
  return stats
end

--- Alles verwerfen (Knopf im Reiter).
function Statistics.reset()
  storage.statistics = { since = game.tick, places = {}, trains = {}, stations = {} }
end

--- Menge in den Eimer der laufenden Minute einer Station (`field` = "sent" | "received").
local function add_station(stats, unit, field, amount, minute)
  if not unit then return end
  local slots = stats.stations[unit]
  if not slots then
    slots = {}
    stats.stations[unit] = slots
  end
  local slot = minute % SLOTS
  local bucket = slots[slot]
  if not bucket or bucket.minute ~= minute then
    bucket = { minute = minute, sent = 0, received = 0 }
    slots[slot] = bucket
  end
  bucket[field] = bucket[field] + amount
end

--- Eine Lieferung ist zu Ende. `delivered` = { [key] = Menge } beim Abnehmer angekommen (nil bei Abbruch).
function Statistics.record(delivery, canceled, delivered)
  local stats = Statistics.data()
  local train = delivery.train
  local front = train and train.valid and train.front_stock
  -- Zug: Zeit mit Auftrag, Zahl der fertigen Lieferungen
  local entry = stats.trains[delivery.train_id]
  if not entry then
    entry = { deliveries = 0, busy = 0, first = delivery.started or game.tick }
    stats.trains[delivery.train_id] = entry
  end
  if front then entry.surface, entry.force = front.surface_index, front.force_index end
  entry.busy = entry.busy + math.max(0, game.tick - (delivery.started or game.tick))
  if not canceled then entry.deliveries = entry.deliveries + 1 end
  if canceled or not delivered or not front then return end
  -- Ware: in den Eimer der laufenden Minute
  local place = Networks.place_of(front)
  local slots = stats.places[place]
  if not slots then
    slots = {}
    stats.places[place] = slots
  end
  local minute = math.floor(game.tick / MINUTE)
  local slot = minute % SLOTS
  local bucket = slots[slot]
  if not bucket or bucket.minute ~= minute then
    bucket = { minute = minute, goods = {}, deliveries = 0 }
    slots[slot] = bucket
  end
  bucket.deliveries = bucket.deliveries + 1
  local sum = 0
  for key, amount in pairs(delivered) do
    if amount > 0 then
      bucket.goods[key] = (bucket.goods[key] or 0) + amount
      sum = sum + amount
    end
  end
  if sum > 0 then
    add_station(stats, delivery.provider, "sent", sum, minute)
    add_station(stats, delivery.requester, "received", sum, minute)
  end
end

--- Durchsatz einer Station: { sent_ten, sent_hour, received_ten, received_hour } oder nil, wenn
--- sie in der letzten Stunde nichts abgegeben oder bekommen hat.
function Statistics.station(unit)
  local slots = Statistics.data().stations[unit]
  if not slots then return nil end
  local now = math.floor(game.tick / MINUTE)
  local result = { sent_ten = 0, sent_hour = 0, received_ten = 0, received_hour = 0 }
  local any = false
  for _, bucket in pairs(slots) do
    local age = now - bucket.minute
    if age >= 0 and age < SLOTS then
      any = true
      result.sent_hour = result.sent_hour + bucket.sent
      result.received_hour = result.received_hour + bucket.received
      if age < 10 then
        result.sent_ten = result.sent_ten + bucket.sent
        result.received_ten = result.received_ten + bucket.received
      end
    end
  end
  return any and result or nil
end

--- Durchsatz eines Orts: { [key] = { ten = Menge letzte 10 min, hour = letzte Stunde } } und die
--- Zahl der Lieferungen in der letzten Stunde.
function Statistics.goods(place)
  local stats = Statistics.data()
  local now = math.floor(game.tick / MINUTE)
  local result, deliveries = {}, 0
  for _, bucket in pairs(stats.places[place] or {}) do
    local age = now - bucket.minute
    if age >= 0 and age < SLOTS then
      deliveries = deliveries + bucket.deliveries
      for key, amount in pairs(bucket.goods) do
        local entry = result[key]
        if not entry then
          entry = { ten = 0, hour = 0 }
          result[key] = entry
        end
        entry.hour = entry.hour + amount
        if age < 10 then entry.ten = entry.ten + amount end
      end
    end
  end
  return result, deliveries
end

--- Auslastung eines Zugs (0 … 1): Zeit mit Auftrag / Zeit seit der ersten Lieferung; eine laufende
--- Lieferung zählt bis jetzt mit.
function Statistics.utilization(train_id, running_since)
  local entry = Statistics.data().trains[train_id]
  local busy = entry and entry.busy or 0
  local first = entry and entry.first or running_since
  if running_since then busy = busy + (game.tick - running_since) end
  if not first then return 0, entry end
  local span = game.tick - first
  if span <= 0 then return 0, entry end
  return math.min(1, busy / span), entry
end

-- Station abgerissen: ihre Zahlen verwerfen
Registry.on_lost(function(station)
  local stats = storage.statistics
  if stats and stats.stations and not (station.entity and station.entity.valid) then stats.stations[station.unit] = nil end
end)

return Statistics
