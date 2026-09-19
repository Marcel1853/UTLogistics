--- Lieferungen und Reservierungen.
--- Ablauf: to_provider → loading → to_requester → unloading → fertig.
--- Der Fortschritt kommt ausschließlich aus on_train_changed_state (kein Polling).
---
--- Reservierungen verhindern Doppelbuchung: Beim Anbieter ist die Menge bis zur Abfahrt
--- reserviert (outgoing), beim Abnehmer bis zum Entladen unterwegs (incoming).
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Heartbeat = require("scripts.core.heartbeat")
local Depot = require("scripts.trains.depot")
local Schedule = require("scripts.trains.schedule")
local Fuel = require("scripts.trains.fuel")
local Log = require("scripts.lib.log")
local Alerts = require("scripts.alerts.alerts")
local Util = require("scripts.lib.util")

local Deliveries = {}

local HISTORY_SIZE = 100

local function add(map, unit, key, amount)
  local by_key = map[unit]
  if not by_key then
    by_key = {}
    map[unit] = by_key
  end
  local value = (by_key[key] or 0) + amount
  if value <= 0 then
    by_key[key] = nil
    if next(by_key) == nil then map[unit] = nil end
  else
    by_key[key] = value
  end
end

local function count_train(unit, delta)
  local trains_at = storage.deliveries.trains_at
  local value = (trains_at[unit] or 0) + delta
  trains_at[unit] = value > 0 and value or nil
end

--- Reservierte Menge beim Anbieter.
function Deliveries.outgoing(unit, key)
  local by_key = storage.deliveries.outgoing[unit]
  return by_key and by_key[key] or 0
end

--- Menge, die zum Abnehmer unterwegs ist.
function Deliveries.incoming(unit, key)
  local by_key = storage.deliveries.incoming[unit]
  return by_key and by_key[key] or 0
end

--- Züge, die gerade zu dieser Station unterwegs sind oder dort stehen.
function Deliveries.trains_at(unit)
  return storage.deliveries.trains_at[unit] or 0
end

function Deliveries.of_train(train_id)
  local id = storage.deliveries.by_train[train_id]
  return id and storage.deliveries.active[id]
end

--- Neue Lieferung anlegen und den Zug losschicken. `record` = freier Zug (aus dem Depot oder
--- direkt nach der letzten Lieferung). `manifest` = Ladeliste { [key] = Menge } – mehrere Waren
--- möglich (Items), bei Flüssigkeiten genau eine.
--- `fuel_stop` (optional): auf dem Weg zum Anbieter zuerst tanken (für den Ablauf unsichtbar,
--- die Lieferung bleibt bis zum Anbieter im Zustand to_provider). Der Dispatcher sucht sie aus.
function Deliveries.create(record, provider, requester, manifest, fuel_stop)
  local train = record.train
  if not Schedule.send(train, provider.stop, requester.stop, manifest, fuel_stop) then return nil end
  Depot.remove(record.id)

  local deliveries = storage.deliveries
  local id = deliveries.next_id
  deliveries.next_id = id + 1
  local delivery = {
    id = id,
    train = train,
    train_id = train.id,
    network = record.network,
    provider = provider.unit,
    requester = requester.unit,
    manifest = manifest,
    state = "to_provider",
    started = game.tick,
    -- Namen für Manager und Verlauf (Haltestellen können später umbenannt/abgerissen werden)
    depot = record.depot_name or (record.stop and record.stop.valid and record.stop.backer_name) or "",
    from = provider.stop.backer_name,
    to = requester.stop.backer_name,
  }
  deliveries.active[id] = delivery
  deliveries.by_train[train.id] = id
  deliveries.count = deliveries.count + 1
  for key, amount in pairs(manifest) do
    add(deliveries.outgoing, provider.unit, key, amount)
    add(deliveries.incoming, requester.unit, key, amount)
  end
  count_train(provider.unit, 1)
  count_train(requester.unit, 1)
  Heartbeat.update_registration()
  Log.debug("Lieferung " .. id .. " mit Zug " .. train.id .. ": " .. serpent.line(manifest))
  return delivery
end

--- Reservierung beim Anbieter freigeben (einmalig).
local function release_provider(delivery)
  if delivery.provider_released then return end
  delivery.provider_released = true
  for key, amount in pairs(delivery.manifest) do add(storage.deliveries.outgoing, delivery.provider, key, -amount) end
  count_train(delivery.provider, -1)
end

--- Eintrag im Verlauf (neueste zuerst, höchstens HISTORY_SIZE).
local function record_history(delivery, canceled)
  local history = storage.history
  table.insert(history, 1, {
    depot = delivery.depot,
    from = delivery.from,
    to = delivery.to,
    manifest = delivery.manifest,
    started = delivery.started,
    finished = game.tick,
    train_id = delivery.train_id,
    canceled = canceled,
  })
  history[HISTORY_SIZE + 1] = nil
end

local function remove(delivery, canceled)
  record_history(delivery, canceled)
  local deliveries = storage.deliveries
  release_provider(delivery)
  for key, amount in pairs(delivery.manifest) do add(deliveries.incoming, delivery.requester, key, -amount) end
  count_train(delivery.requester, -1)
  deliveries.active[delivery.id] = nil
  if deliveries.by_train[delivery.train_id] == delivery.id then deliveries.by_train[delivery.train_id] = nil end
  deliveries.count = deliveries.count - 1
  Heartbeat.update_registration()
end

--- Station sofort neu lesen, damit der nächste Dispatch-Lauf echte Bestände sieht.
local function reread(unit)
  local station = Registry.get(unit)
  if station then Reader.read(station) end
end

local function stop_unit_of(unit)
  local station = Registry.get(unit)
  return station and station.stop_unit
end

--- Zug wartet an einer Haltestelle.
function Deliveries.on_arrive(delivery, stop)
  local unit = stop.unit_number
  if delivery.state == "to_provider" and unit == stop_unit_of(delivery.provider) then
    delivery.state = "loading"
  elseif delivery.state == "to_requester" and unit == stop_unit_of(delivery.requester) then
    delivery.state = "unloading"
  end
end

--- Zug fährt von einer Haltestelle ab. Liefert true, wenn die Lieferung damit fertig ist und
--- der Zug leer und ausreichend betankt ist (dann kann er direkt den nächsten Auftrag bekommen).
function Deliveries.on_depart(delivery)
  if delivery.state == "loading" then
    delivery.state = "to_requester"
    release_provider(delivery)
    reread(delivery.provider)
    -- Weniger geladen als bestellt (Wartebedingung von Hand/Interrupt beendet)?
    local train = delivery.train
    if train.valid then
      for key, amount in pairs(delivery.manifest) do
        local loaded = Deliveries.loaded(train, key)
        if loaded < amount then
          local provider = Registry.get(delivery.provider)
          local stop = provider and provider.stop
          Alerts.raise("cargo", "missing", stop and stop.valid and stop or train.front_stock,
            { "utl-alert.provider-missing", Alerts.train_name(train), delivery.from or "?", loaded, amount },
            "missing:" .. delivery.id)
          break
        end
      end
    end
  elseif delivery.state == "unloading" then
    remove(delivery)
    reread(delivery.requester)
    Log.debug("Lieferung " .. delivery.id .. " fertig")
    -- Nicht alles losgeworden (z. B. Interrupt, Wartebedingung geändert): zur Cleanup-Station.
    local train = delivery.train
    -- Nach dem Entladen knapp an Treibstoff: gleich tanken statt erst ins Depot.
    if train.valid and not Depot.has_cargo(train) and Fuel.is_low(train) then
      Depot.send_service(train, delivery.network or "default")
    end
    if train.valid and Depot.has_cargo(train) then
      local requester = Registry.get(delivery.requester)
      local stop = requester and requester.stop
      Alerts.raise("cargo", "cargo", stop and stop.valid and stop or train.front_stock,
        { "utl-alert.requester-cargo", Alerts.train_name(train), delivery.to or "?" }, "leftover:" .. delivery.id)
      Depot.send_service(train, delivery.network or "default")
    end
    return train.valid and not storage.trains.service[train.id]
  end
  return false
end

--- Menge einer Ware (Key) im Zug.
function Deliveries.loaded(train, key)
  local kind, name, quality = Util.split_key(key)
  if kind == "fluid" then return math.floor(train.get_fluid_count(name)) end
  local count = 0
  for _, stack in pairs(train.get_contents()) do
    if stack.name == name and (stack.quality or "normal") == quality then count = count + stack.count end
  end
  return count
end

--- Lieferung abbrechen (Station weg, Zug manuell/zerlegt). Entfernt die UTL-Halte, der Zug
--- fährt mit seinem eigenen Fahrplan weiter (in der Regel ins Depot).
--- `reason` = „station-lost“ | „manual“ | „rebuilt“ (Locale utl-alert.reason-…).
function Deliveries.cancel(delivery, reason)
  local train = delivery.train
  if train.valid then Schedule.clear(train) end
  local text = { "utl-alert.reason-" .. reason }
  remove(delivery, text)
  Log.info("Lieferung " .. delivery.id .. " abgebrochen: " .. reason)
  if train.valid and reason ~= "manual" then
    Alerts.raise("train", "canceled", train.front_stock,
      { "utl-alert.canceled", Alerts.train_name(train), delivery.from or "?", delivery.to or "?", text },
      "canceled:" .. delivery.id)
  end
  -- Mit Ladung (bzw. knapp an Treibstoff) direkt zur Cleanup-/Tankstelle statt ins Depot.
  if train.valid and not train.manual_mode then Depot.send_service(train, delivery.network or "default") end
end

--- Station entfernt oder ohne Haltestelle: alle Lieferungen von/zu ihr abbrechen.
function Deliveries.cancel_for_station(unit)
  for _, delivery in pairs(storage.deliveries.active) do
    -- Anbieter nach der Abfahrt ist egal, die Ware ist schon im Zug.
    if delivery.requester == unit or (delivery.provider == unit and not delivery.provider_released) then
      Deliveries.cancel(delivery, "station-lost")
    end
  end
end

return Deliveries
