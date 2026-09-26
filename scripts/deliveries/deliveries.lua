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
local Filters = require("scripts.trains.wagon-filters")
local Unlocks = require("scripts.core.unlocks")
local TeamConfig = require("scripts.core.team-config")
local Pending = require("scripts.trains.pending")
local Output = require("scripts.stations.output")

local Deliveries = {}

local HISTORY_SIZE = 100

local function add(map, unit, key, amount)
  Output.mark(unit) -- Auftrags-Ausgabe dieser Station neu schreiben
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
  -- Zeitlimits des Teams, dem der Zug gehört (sonst Kartenwert)
  local force = train.front_stock and train.front_stock.force
  local timeouts = { load = TeamConfig.get(force, "load_timeout"), unload = TeamConfig.get(force, "unload_timeout"),
    mode = TeamConfig.get(force, "timeout_mode") }
  if not Schedule.send(train, provider.stop, requester.stop, manifest, fuel_stop, timeouts) then return nil end
  -- Tankhalt vormerken: bis zur Ankunft zählt ihn das Zuglimit der Tankstelle sonst nicht mit
  if fuel_stop then Pending.reserve(train.id, { fuel_stop }) end
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
  local of_requester = deliveries.by_requester[requester.unit]
  if not of_requester then
    of_requester = {}
    deliveries.by_requester[requester.unit] = of_requester
  end
  of_requester[id] = true
  deliveries.count = deliveries.count + 1
  for key, amount in pairs(manifest) do
    add(deliveries.outgoing, provider.unit, key, amount)
    add(deliveries.incoming, requester.unit, key, amount)
  end
  count_train(provider.unit, 1)
  count_train(requester.unit, 1)
  -- Ladefilter: nur die Waren des Auftrags dürfen in die Wagen (Anbieter kann es abschalten).
  if provider.config.filter_load and Unlocks.loading(Unlocks.force_of(provider)) then
    Filters.apply(delivery, provider.config.locked_slots)
  end
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
  local front = delivery.train and delivery.train.valid and delivery.train.front_stock
  table.insert(history, 1, {
    surface = front and front.surface_index or nil, -- für die Planeten-Auswahl im Manager
    force = front and front.force_index or nil, -- jedes Team sieht nur seinen Verlauf
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
  Filters.clear(delivery)
  Pending.release(delivery.train_id) -- ein vorgemerkter Tankhalt dieser Fahrt fällt weg
  -- Abbruch mitten im Laden: den Zug auch aus der Ausgabe nehmen.
  local at = storage.deliveries.at_station
  for _, unit in ipairs({ delivery.provider, delivery.requester }) do
    if at[unit] and at[unit].id == delivery.train_id then
      at[unit] = nil
      Output.mark(unit)
    end
  end
  local deliveries = storage.deliveries
  release_provider(delivery)
  for key, amount in pairs(delivery.manifest) do add(deliveries.incoming, delivery.requester, key, -amount) end
  count_train(delivery.requester, -1)
  deliveries.active[delivery.id] = nil
  if deliveries.by_train[delivery.train_id] == delivery.id then deliveries.by_train[delivery.train_id] = nil end
  local of_requester = deliveries.by_requester[delivery.requester]
  if of_requester then
    of_requester[delivery.id] = nil
    if next(of_requester) == nil then deliveries.by_requester[delivery.requester] = nil end
  end
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

--- Zug an einer Station vermerken (für die Auftrags-Ausgabe) bzw. wieder löschen.
local function train_at(unit, train)
  local at = storage.deliveries.at_station
  if train and train.valid then
    local wagons = #train.cargo_wagons + #train.fluid_wagons
    at[unit] = {
      id = train.id,
      length = #train.carriages,
      locos = #train.locomotives.front_movers + #train.locomotives.back_movers,
      wagons = wagons,
    }
  else
    at[unit] = nil
  end
  Output.mark(unit)
end

--- Zug wartet an einer Haltestelle.
function Deliveries.on_arrive(delivery, stop)
  local unit = stop.unit_number
  if delivery.state == "to_provider" and unit == stop_unit_of(delivery.provider) then
    delivery.state = "loading"
    Filters.repair(delivery) -- Slots, die beim Losschicken noch belegt waren
    train_at(delivery.provider, delivery.train)
  elseif delivery.state == "to_requester" and unit == stop_unit_of(delivery.requester) then
    delivery.state = "unloading"
    train_at(delivery.requester, delivery.train)
  end
end

--- Zug fährt von einer Haltestelle ab. Liefert true, wenn die Lieferung damit fertig ist und
--- der Zug leer und ausreichend betankt ist (dann kann er direkt den nächsten Auftrag bekommen).
function Deliveries.on_depart(delivery)
  if delivery.state == "loading" then
    delivery.state = "to_requester"
    train_at(delivery.provider, nil)
    release_provider(delivery)
    reread(delivery.provider)
    -- Weniger geladen als bestellt (Zeitlimit, Wartebedingung von Hand/Interrupt beendet)?
    -- Dann Ladeliste und „unterwegs“ beim Abnehmer auf das tatsächlich Geladene setzen – sonst
    -- bestellt der Abnehmer bis zum Entladen zu wenig nach.
    local train = delivery.train
    if train.valid then
      local total, short = 0, nil
      for key, amount in pairs(delivery.manifest) do
        local loaded = Deliveries.loaded(train, key)
        -- Flüssigkeiten: winzige Reste (999,999 statt 1000) sind keine Fehlmenge
        if loaded < amount and amount - loaded <= 1 and Util.split_key(key) == "fluid" then loaded = amount end
        if loaded ~= amount then
          -- „unterwegs“ beim Abnehmer auf das tatsächlich Geladene setzen (auch bei Überladung),
          -- sonst bestellt er bis zum Entladen zu wenig oder zu viel nach.
          if loaded < amount then short = short or { loaded = loaded, amount = amount } end
          add(storage.deliveries.incoming, delivery.requester, key, loaded - amount)
          delivery.manifest[key] = loaded > 0 and loaded or nil
        end
        total = total + math.min(loaded, amount)
      end
      if total == 0 then
        -- Nichts geladen (Anbieter leer, Zeitlimit abgelaufen): Fahrt zum Abnehmer lohnt nicht.
        Deliveries.cancel(delivery, "provider-empty")
        return false
      end
      if short then
        local provider = Registry.get(delivery.provider)
        local stop = provider and provider.stop
        Alerts.raise("cargo", "missing", stop and stop.valid and stop or train.front_stock,
          { "utl-alert.provider-missing", Alerts.train_name(train), delivery.from or "?", short.loaded, short.amount },
          "missing:" .. delivery.id)
      end
    end
  elseif delivery.state == "unloading" then
    train_at(delivery.requester, nil)
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

--- Nachladen: eine Menge auf die Ladeliste einer laufenden Lieferung setzen und die
--- Reservierungen mitziehen (beim Anbieter reserviert, beim Abnehmer unterwegs). Der Fahrplan
--- wird dabei **nicht** angefasst – das macht der Aufrufer (`dispatcher/top-up.lua`), damit er
--- bei einem Fehlschlag nichts gebucht hat.
function Deliveries.book_top_up(delivery, key, amount)
  if amount <= 0 then return end
  delivery.manifest[key] = (delivery.manifest[key] or 0) + amount
  add(storage.deliveries.outgoing, delivery.provider, key, amount)
  add(storage.deliveries.incoming, delivery.requester, key, amount)
  delivery.topped_up = (delivery.topped_up or 0) + 1
end

--- Nachladen zurücknehmen (Fahrplan ließ sich nicht ändern).
function Deliveries.undo_top_up(delivery, key, amount)
  if amount <= 0 then return end
  local left = (delivery.manifest[key] or 0) - amount
  delivery.manifest[key] = left > 0 and left or nil
  add(storage.deliveries.outgoing, delivery.provider, key, -amount)
  add(storage.deliveries.incoming, delivery.requester, key, -amount)
  delivery.topped_up = (delivery.topped_up or 1) - 1
end

--- Lieferungen zu diesem Abnehmer (Index für das Nachladen).
function Deliveries.to_requester(unit)
  return storage.deliveries.by_requester[unit]
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
