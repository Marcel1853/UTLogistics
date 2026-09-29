--- Zugzahlen je Netz für den Netz-Kombinator (Modus „Züge“).
---
--- Ein Zug zählt zu dem Netz seines Heimatdepots (storage.trains.home – Züge, die schon einmal in
--- einem UTL-Depot standen). Frei = wartet im Depot (Pool des Dispatchers), unterwegs = hat eine
--- Lieferung. Lieferungen zählen nach dem Netz des Abnehmers. Fährt ein Zug für ein anderes
--- (verbundenes) Netz, zählt er dort als „ausgeholfen“ (borrowed) und daheim als „verliehen“ (lent).
---
--- Regel 5: gezählt wird in Häppchen (BATCH Züge je Heartbeat, Round-Robin wie Reader.step), eine
--- volle Runde, dann Pause bis EVERY Ticks nach dem letzten Start. Die Kombinatoren geben den
--- letzten vollständigen Stand aus. Nur solange ein Kombinator im Modus „Züge“ danach fragt.
--- Zwischenstand in storage (nicht in Lua-Variablen): Ein Spieler, der beitritt, muss dieselben
--- Werte sehen wie der Server – sonst Desynchronisation.
local Networks = require("scripts.stations.networks")
local Fuel = require("scripts.trains.fuel")

local Census = {}

--- Netz, für das eine Lieferung fährt: das des Abnehmers (delivery.network ist das Netz des Zuges).
function Census.job_network(delivery)
  local requester = storage.stations.by_unit[delivery.requester]
  return requester and requester.config.network or delivery.network or "default"
end

local BATCH = 40    -- Züge je Heartbeat
local EVERY = 300   -- Ticks von Rundenstart zu Rundenstart (mindestens)
local IDLE = 600    -- so lange nach der letzten Abfrage wird weitergezählt

local function data()
  local census = storage.readout_census
  if not census or not census.building then
    census = { counts = {}, building = {}, cursor = nil, started = nil, asked = nil }
    storage.readout_census = census
  end
  return census
end

local function bump(counts, key, field)
  local entry = counts[key]
  if not entry then
    entry = { total = 0, free = 0, busy = 0, deliveries = 0, low_fuel = 0, no_fuel = 0, no_path = 0, borrowed = 0, lent = 0 }
    counts[key] = entry
  end
  entry[field] = (entry[field] or 0) + 1 -- „or 0“: Zählungen aus älteren Spielständen
end

local function count_train(counts, id, home)
  local train, stop = home.train, home.stop
  if not (train and train.valid and stop and stop.valid) then return end
  local stations = storage.stations
  local unit = stations.by_stop[stop.unit_number]
  local station = unit and stations.by_unit[unit]
  if not station then return end
  local place, home_net = Networks.place_of(stop), station.config.network or "default"
  local key = place .. "|" .. home_net
  bump(counts, key, "total")
  if storage.trains.by_id[id] then bump(counts, key, "free") end
  local delivery_id = storage.deliveries.by_train[id]
  if delivery_id then
    bump(counts, key, "busy")
    -- Fährt der Zug für ein anderes (verbundenes) Netz? Dann hilft sein Netz dort aus.
    local delivery = storage.deliveries.active[delivery_id]
    local job_net = delivery and Census.job_network(delivery)
    if job_net and job_net ~= home_net then
      bump(counts, key, "lent")
      bump(counts, place .. "|" .. job_net, "borrowed")
    end
  end
  if Fuel.is_low(train) then bump(counts, key, "low_fuel") end
  if Fuel.is_empty(train) then bump(counts, key, "no_fuel") end
  if train.state == defines.train_state.no_path then bump(counts, key, "no_path") end
end

--- Runde abschließen: Lieferungen dazu, Stand übernehmen.
local function finish(census)
  local counts = census.building
  for _, delivery in pairs(storage.deliveries.active) do
    local train = delivery.train
    local front = train and train.valid and train.front_stock
    if front then bump(counts, Networks.place_of(front) .. "|" .. Census.job_network(delivery), "deliveries") end
  end
  census.counts, census.building, census.cursor = counts, {}, nil
end

--- Heartbeat: nächstes Häppchen zählen (nur, wenn jemand nach Zugzahlen fragt).
function Census.step()
  local census = data()
  local now = game.tick
  if not census.asked or now - census.asked > IDLE then return end
  local home = storage.trains.home
  local id = census.cursor
  if id == nil then
    if census.started and now - census.started < EVERY then return end -- Pause zwischen den Runden
    census.started, census.building = now, {}
  elseif home[id] == nil then
    -- Merkpunkt ist weg (Zug umgebaut/zerstört): Runde neu beginnen
    census.cursor, census.started, census.building = nil, now, {}
    id = nil
  end
  local entry
  for _ = 1, BATCH do
    id, entry = next(home, id)
    if id == nil then
      finish(census)
      return
    end
    count_train(census.building, id, entry)
  end
  census.cursor = id
end

local ZERO = { total = 0, free = 0, busy = 0, deliveries = 0, low_fuel = 0, no_fuel = 0, no_path = 0, borrowed = 0, lent = 0 }

--- Zugzahlen eines Netzes aus der letzten vollständigen Runde (nie nil).
function Census.net(place, name)
  local census = data()
  census.asked = game.tick
  return census.counts[place .. "|" .. name] or ZERO
end

return Census
