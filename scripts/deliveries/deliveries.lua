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
local Statistics = require("scripts.deliveries.statistics")
local Home = require("scripts.compat.se-home")
local Reservations = require("scripts.deliveries.reservations")

local Deliveries = {}

local HISTORY_SIZE = 100

local add = Reservations.add
Deliveries.outgoing = Reservations.outgoing
Deliveries.incoming = Reservations.incoming
Deliveries.trains_at = Reservations.trains_at
local release_provider = Reservations.release_provider

function Deliveries.of_train(train_id)
  local id = storage.deliveries.by_train[train_id]
  return id and storage.deliveries.active[id]
end

--- Neue Lieferung anlegen und den Zug losschicken. `record` = freier Zug (aus dem Depot oder
--- direkt nach der letzten Lieferung). `manifest` = Ladeliste { [key] = Menge } – mehrere Waren
--- möglich (Items), bei Flüssigkeiten genau eine.
--- `fuel_stop` (optional): auf dem Weg zum Anbieter zuerst tanken (für den Ablauf unsichtbar,
--- die Lieferung bleibt bis zum Anbieter im Zustand to_provider). Der Dispatcher sucht sie aus.
--- `via` (Space Exploration): { here, there } = Aufzug-Halte, wenn der Abnehmer hinter einem
--- Weltraumaufzug liegt (Anbieter-Seite = Seite des Zugs).
--- `second` (zweiter Anbieter): { station, manifest } – dort lädt der Zug den Rest; `manifest` ist
--- dann die Gesamtmenge beider Halte.
function Deliveries.create(record, provider, requester, manifest, fuel_stop, via, second)
  local train = record.train
  -- Zeitlimits des Teams, dem der Zug gehört (sonst Kartenwert)
  local force = train.front_stock and train.front_stock.force
  local timeouts = { load = TeamConfig.get(force, "load_timeout"), unload = TeamConfig.get(force, "unload_timeout"),
    mode = TeamConfig.get(force, "timeout_mode") }
  local pickup2 = nil
  if second then
    local share = {}
    for key, amount in pairs(manifest) do
      local rest = amount - (second.manifest[key] or 0)
      if rest > 0 then share[key] = rest end
    end
    pickup2 = { stop = second.station.stop, first = share }
  end
  if not Schedule.send(train, provider.stop, requester.stop, manifest, fuel_stop, timeouts, via, pickup2) then return nil end
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
    progress = game.tick, -- Hänger-Erkennung (deliveries/stuck.lua)
    -- Namen für Manager und Verlauf (Haltestellen können später umbenannt/abgerissen werden)
    depot = record.depot_name or (record.stop and record.stop.valid and record.stop.backer_name) or "",
    from = provider.stop.backer_name .. (second and (" + " .. second.station.stop.backer_name) or ""),
    to = requester.stop.backer_name,
    via = via,
    second = second and { unit = second.station.unit, manifest = second.manifest,
      name = second.station.stop.backer_name } or nil,
    leg = 1,
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
  Reservations.book(delivery)
  -- Ladefilter: nur die Waren des Auftrags dürfen in die Wagen (Anbieter kann es abschalten).
  if provider.config.filter_load and Unlocks.loading(Unlocks.force_of(provider)) then
    Filters.apply(delivery, provider.config.locked_slots)
  end
  Heartbeat.update_registration()
  Log.debug("Lieferung " .. id .. " mit Zug " .. train.id .. ": " .. serpent.line(manifest))
  return delivery
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
  -- Statistik: was kam beim Abnehmer an? (Rest, der noch im Zug ist, zählt nicht)
  local delivered = nil
  if not canceled and delivery.state == "unloading" then
    delivered = {}
    local train = delivery.train
    for key, amount in pairs(delivery.manifest) do
      local left = train.valid and Deliveries.loaded(train, key) or 0
      delivered[key] = math.max(0, amount - left)
    end
  end
  Statistics.record(delivery, canceled, delivered)
  Filters.clear(delivery)
  Pending.release(delivery.train_id) -- ein vorgemerkter Tankhalt dieser Fahrt fällt weg
  -- Abbruch mitten im Laden: den Zug auch aus der Ausgabe nehmen.
  local at = storage.deliveries.at_station
  for _, unit in ipairs({ delivery.provider, delivery.requester, delivery.second and delivery.second.unit }) do
    if unit and at[unit] and at[unit].id == delivery.train_id then
      at[unit] = nil
      Output.mark(unit)
    end
  end
  local deliveries = storage.deliveries
  release_provider(delivery)
  Reservations.release_second(delivery)
  Reservations.release_requester(delivery)
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
--- `mode` = "load" | "unload": wird dort geladen oder entladen (Signale utl-loading/utl-unloading).
local function train_at(unit, train, mode)
  local at = storage.deliveries.at_station
  if train and train.valid then
    local wagons = #train.cargo_wagons + #train.fluid_wagons
    at[unit] = {
      id = train.id,
      length = #train.carriages,
      locos = #train.locomotives.front_movers + #train.locomotives.back_movers,
      wagons = wagons,
      mode = mode,
    }
  else
    at[unit] = nil
  end
  Output.mark(unit)
end

--- Zug wartet an einer Haltestelle.
function Deliveries.on_arrive(delivery, stop)
  local unit = stop.unit_number
  local pickup = Reservations.pickup_unit(delivery)
  if delivery.state == "to_provider" and unit == stop_unit_of(pickup) then
    delivery.state = "loading"
    Filters.repair(delivery) -- Slots, die beim Losschicken noch belegt waren
    train_at(pickup, delivery.train, "load")
  elseif delivery.state == "to_requester" and unit == stop_unit_of(delivery.requester) then
    delivery.state = "unloading"
    train_at(delivery.requester, delivery.train, "unload")
  end
end

--- Zug fährt von einer Haltestelle ab. Liefert true, wenn die Lieferung damit fertig ist und
--- der Zug leer und ausreichend betankt ist (dann kann er direkt den nächsten Auftrag bekommen).
function Deliveries.on_depart(delivery)
  if delivery.state == "loading" and delivery.second and delivery.leg ~= 2 then
    -- erster von zwei Anbietern fertig: weiter zum zweiten
    delivery.state = "to_provider"
    delivery.leg = 2
    train_at(delivery.provider, nil)
    release_provider(delivery)
    reread(delivery.provider)
    Output.mark(delivery.second.unit)
  elseif delivery.state == "loading" then
    delivery.state = "to_requester"
    train_at(Reservations.pickup_unit(delivery), nil)
    Output.mark(delivery.requester) -- „Züge unterwegs hierher“ am Abnehmer
    release_provider(delivery)
    Reservations.release_second(delivery)
    reread(Reservations.pickup_unit(delivery))
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
      -- Rückweg-Sperre: diese Waren liefert ein Cleanup dem Abnehmer vorerst nicht zurück
      local block = storage.dispatch.return_block[delivery.requester] or {}
      for _, stack in pairs(train.get_contents()) do
        block[Util.signal_key({ type = "item", name = stack.name, quality = stack.quality })] = game.tick
      end
      for name in pairs(train.get_fluid_contents()) do block[Util.signal_key({ type = "fluid", name = name })] = game.tick end
      storage.dispatch.return_block[delivery.requester] = block
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
  -- über den Aufzug und schon drüben: zurück durch den Aufzug (dort steht sein Depot)
  if delivery.via then Home.ensure(train) end
end

--- Station entfernt oder ohne Haltestelle: alle Lieferungen von/zu ihr abbrechen.
function Deliveries.cancel_for_station(unit)
  for _, delivery in pairs(storage.deliveries.active) do
    -- Anbieter nach der Abfahrt ist egal, die Ware ist schon im Zug.
    local second = delivery.second
    if delivery.requester == unit or (delivery.provider == unit and not delivery.provider_released)
      or (second and second.unit == unit and not second.released) then
      Deliveries.cancel(delivery, "station-lost")
    end
  end
end

return Deliveries
