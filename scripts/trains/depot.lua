--- Freie Züge im Depot. Ein Zug ist frei, wenn er leer an einer Depot-Station wartet und
--- keine Lieferung hat. Nur diese Züge kennt der Dispatcher; Züge unterwegs werden über
--- ihre Lieferung verfolgt.
local Log = require("scripts.lib.log")
local Fuel = require("scripts.trains.fuel")
local Schedule = require("scripts.trains.schedule")
local CleanupRoute = require("scripts.trains.cleanup-route")
local Alerts = require("scripts.alerts.alerts")

local Depot = {}

local CARGO = defines.inventory.cargo_wagon

local function length_ok(cfg, length)
  return (cfg.min_train_length <= 0 or length >= cfg.min_train_length)
    and (cfg.max_train_length <= 0 or length <= cfg.max_train_length)
end

--- Laderaum eines Zugs (ändert sich nur mit neuer Zug-ID, daher einmal beim Parken).
local function measure(train)
  local slots, wagons, fluid = 0, 0, 0
  for _, wagon in pairs(train.cargo_wagons) do
    local inventory = wagon.get_inventory(CARGO)
    if inventory then
      slots = slots + #inventory
      wagons = wagons + 1
    end
  end
  for _, wagon in pairs(train.fluid_wagons) do
    fluid = fluid + wagon.prototype.fluid_capacity
  end
  return slots, wagons, fluid
end

Depot.measure = measure

function Depot.get(train_id)
  return storage.trains.by_id[train_id]
end

--- Zug aus dem Pool nehmen (abgefahren, losgeschickt, ungültig).
function Depot.remove(train_id)
  local trains = storage.trains
  local record = trains.by_id[train_id]
  if not record then return end
  trains.by_id[train_id] = nil
  trains.count = trains.count - 1
  local pool = trains.idle[record.network]
  if pool then
    pool[train_id] = nil
    if next(pool) == nil then trains.idle[record.network] = nil end
  end
end

--- Zug steht an `stop`. Ist das ein Depot, kommt er in den Pool.
function Depot.arrive(train, stop, station)
  if not (station and station.config.roles.depot and station.stop_unit == stop.unit_number) then return end
  local id = train.id
  if storage.trains.by_id[id] or storage.deliveries.by_train[id] then return end
  storage.trains.home[id] = { train = train, depot = stop.backer_name, stop = stop }
  local network = station.config.network
  -- Dienstfahrt nötig (knapp an Treibstoff und/oder Restladung)? Danach kommt der Zug von
  -- selbst zurück ins Depot. Kam er gerade von einer Dienstfahrt, nicht endlos pendeln.
  local serviced = storage.trains.service[id]
  storage.trains.service[id] = nil
  -- Nach einer Umsetzung („relocate“) darf getankt/aufgeräumt werden, nach einer Dienstfahrt
  -- (auch „relocate-serviced“) nicht gleich wieder.
  local missing = nil
  if not serviced or serviced == "relocate" then
    local sent
    sent, missing = Depot.send_service(train, network)
    if sent then return end
  end
  if Depot.has_cargo(train) then
    if missing then
      -- kein passendes, freies Cleanup: später erneut versuchen (Depot.retry_cargo)
      Log.info("Zug " .. id .. " hat Restladung " .. missing.name .. ", aber kein passendes Cleanup ist frei/erreichbar.")
      Alerts.raise("cargo", "cargo", stop, { "utl-alert.no-cleanup", Alerts.train_name(train), CleanupRoute.rich(missing) },
        "no-cleanup:" .. id)
      storage.trains.cargo_waiting[id] = { train = train, stop = stop, network = network }
    else
      Log.info("Zug " .. id .. " steht nach dem Cleanup noch mit Restladung im Depot " .. stop.backer_name .. ".")
      Alerts.raise("cargo", "cargo", stop, { "utl-alert.depot-cargo", Alerts.train_name(train), stop.backer_name },
        "depot-cargo:" .. id)
    end
    return
  end
  if serviced and serviced ~= "relocate" and serviced ~= "relocate-serviced" and Fuel.is_low(train) then
    Log.info("Zug " .. id .. " konnte nicht volltanken (Tankstelle leer?).")
    Alerts.raise("train", "fuel", train.front_stock or stop, { "utl-alert.fuel-failed", Alerts.train_name(train) },
      "fuel:" .. id)
  end
  -- Zuglänge passt nicht zum Depot: zu einem passenden, freien gleichnamigen Depot umsetzen.
  -- Gibt es keins (oder kam er gerade von einer Umsetzung), bleibt er hier und ist frei.
  if serviced ~= "relocate" and serviced ~= "relocate-serviced" and not length_ok(station.config, #train.carriages)
    and Depot.relocate(train, stop, network) then
    return
  end
  local slots, wagons, fluid = measure(train)
  local trains = storage.trains
  trains.by_id[id] = {
    train = train,
    id = id,
    network = network,
    surface_index = stop.surface_index,
    stop = stop,
    stop_unit = stop.unit_number,
    position = stop.position, -- geparkt: Position ändert sich nicht (Dispatcher ohne API-Aufrufe)
    length = #train.carriages,
    slots = slots,
    wagons = wagons,
    fluid = fluid,
  }
  trains.count = trains.count + 1
  local pool = trains.idle[network]
  if not pool then
    pool = {}
    trains.idle[network] = pool
  end
  pool[id] = true
end

--- Steht der Zug noch wirklich wartend an seinem Depot? (Lazy-Prüfung im Dispatcher.)
function Depot.is_ready(record)
  local train = record.train
  if not (train.valid and record.stop.valid) then return false end
  local station = train.station
  return train.state == defines.train_state.wait_station
    and station ~= nil and station.unit_number == record.stop_unit
end

--- Zug an einer Depot-Haltestelle (neu) erfassen, z. B. nachdem seine Restladung von Hand weg ist.
function Depot.scan_stop(stop)
  local unit = storage.stations.by_stop[stop.unit_number]
  local station = unit and storage.stations.by_unit[unit]
  if station then Depot.scan(station) end
end

--- Bereits geparkten Zug an einer (neu zum Depot gemachten) Station erfassen.
function Depot.scan(station)
  local stop = station.stop
  if not (station.config.roles.depot and stop and stop.valid) then return end
  local train = stop.get_stopped_train()
  if train and train.state == defines.train_state.wait_station then Depot.arrive(train, stop, station) end
end

function Depot.has_cargo(train)
  return train.get_item_count() > 0 or train.get_fluid_count() > 0
end

--- Dienstfahrt: tanken, falls knapp; Restladung über die Cleanup-Route. Liefert true, wenn der
--- Zug losgeschickt wurde, sonst false und ggf. die Ware ohne passendes Cleanup. Der Zug fährt
--- danach mit seinem Fahrplan weiter (ins Depot).
function Depot.send_service(train, network)
  local fuel_stop = Fuel.stop_if_low(train, network)
  local route, missing = nil, nil
  if Depot.has_cargo(train) then route, missing = CleanupRoute.plan(train, network) end
  -- Restladung ohne passendes Cleanup: nicht nur zum Tanken losschicken (sonst pendelt er)
  if missing then return false, missing end
  if not Schedule.send_service(train, fuel_stop, route) then return false, nil end
  storage.trains.service[train.id] = (fuel_stop and route and "both") or (fuel_stop and "fuel") or "cleanup"
  return true, nil
end

--- `network` = nil: Netzwerk egal (Zug steht an einer Haltestelle ohne Depot-Rolle).
--- Passendes freies Depot mit gleichem Namen suchen und den Zug per Schienen-Wegpunkt
--- davor schicken; sein Depot-Halt im Fahrplan führt ihn dann genau dorthin.
local MAX_DEPOT_CANDIDATES = 20
function Depot.relocate(train, current, network, after_service)
  local name, length, surface = current.backer_name, #train.carriages, current.surface_index
  local goals, stops = {}, {}
  for _, station in pairs(storage.stations.by_unit) do
    local stop, cfg = station.stop, station.config
    if cfg.roles.depot and stop and stop.valid and stop ~= current and stop.backer_name == name
      and (network == nil or cfg.network == network) and stop.surface_index == surface
      and length_ok(cfg, length)
      and stop.trains_count == 0 then
      stops[#stops + 1] = stop
      goals[#goals + 1] = { train_stop = stop }
      if #goals >= MAX_DEPOT_CANDIDATES then break end
    end
  end
  if #goals == 0 then return false end
  local result = game.train_manager.request_train_path({ train = train, goals = goals, steps_limit = 20000 })
  if not result.found_path then return false end
  if not Schedule.send_waypoint(train, stops[result.goal_index]) then return false end
  storage.trains.service[train.id] = after_service and "relocate-serviced" or "relocate"
  return true
end

--- Freie Züge, die knapp an Treibstoff sind, zum Tanken schicken (z. B. nach dem Anlegen
--- einer Tankstelle oder dem Ändern der Grenze).
--- `limit` (optional): höchstens so viele Tankstellen-Suchen (je eine Pfadsuche) – für den
--- regelmäßigen Durchlauf, damit viele knappe Züge auf einmal keinen Ruckler auslösen.
function Depot.refuel_idle(limit)
  local tries = 0
  for id, record in pairs(storage.trains.by_id) do
    local train = record.train
    if train.valid and Fuel.is_low(train) then
      if limit and tries >= limit then return end
      tries = tries + 1
      if Depot.send_service(train, record.network) then Depot.remove(id) end
    end
  end
end

--- Züge mit Restladung, für die gerade kein Cleanup frei war, erneut losschicken (höchstens
--- `limit` Versuche). Wer nicht mehr wartend im Depot steht, fällt heraus.
function Depot.retry_cargo(limit)
  local waiting = storage.trains.cargo_waiting
  local tries = 0
  for id, entry in pairs(waiting) do
    local train = entry.train
    if not (train.valid and entry.stop.valid and train.station == entry.stop
      and train.state == defines.train_state.wait_station) then
      waiting[id] = nil
    elseif not Depot.has_cargo(train) then
      waiting[id] = nil
      Depot.scan_stop(entry.stop)
    else
      if tries >= limit then return end
      tries = tries + 1
      if Depot.send_service(train, entry.network) then waiting[id] = nil end
    end
  end
end

--- Alle Depots neu prüfen: wartende Züge mit Restladung/ohne Treibstoff bekommen eine
--- Dienstfahrt (z. B. nachdem eine Cleanup- oder Tankstelle gebaut wurde).
function Depot.rescan_all()
  for _, station in pairs(storage.stations.by_unit) do
    if station.config.roles.depot then Depot.scan(station) end
  end
end

--- Alle Züge einer Depot-Haltestelle aus dem Pool nehmen (Station weg oder umgestellt).
function Depot.forget(stop_unit)
  for id, record in pairs(storage.trains.by_id) do
    if record.stop_unit == stop_unit or not record.stop.valid then Depot.remove(id) end
  end
end

--- Einstellungen geändert (Rolle, Netzwerk): Züge dieser Station neu erfassen.
function Depot.refresh_station(station)
  Depot.invalidate_names()
  if station.stop_unit then Depot.forget(station.stop_unit) end
  if station.config.roles.depot then
    Depot.scan(station)
  elseif station.stop and station.stop.valid then
    -- Depot-Rolle weggenommen: dort wartender Zug zieht in ein echtes Depot gleichen Namens um.
    local train = station.stop.get_stopped_train()
    if train and train.state == defines.train_state.wait_station then Depot.stray(train, station.stop) end
  end
end

-- Namen aller Depots (nur Lua-Zwischenspeicher, aus storage abgeleitet; bei Änderungen verworfen).
local depot_names = nil

function Depot.invalidate_names()
  depot_names = nil
end

local function names()
  if not depot_names then
    depot_names = {}
    for _, station in pairs(storage.stations.by_unit) do
      local stop = station.stop
      if station.config.roles.depot and stop and stop.valid then depot_names[stop.backer_name] = true end
    end
  end
  return depot_names
end

function Depot.no_free_depot(train, stop)
  Log.info("Zug " .. train.id .. " steht an „" .. stop.backer_name .. "“ ohne Depot-Rolle, kein freies Depot gefunden.")
  Alerts.raise("train", "no_path", stop, { "utl-alert.no-depot", Alerts.train_name(train), stop.backer_name },
    "no-depot:" .. train.id)
end

--- Zug ohne Auftrag wartet an einer Haltestelle ohne Depot-Rolle. Heißt sie wie ein Depot
--- (Depot-Halt im Fahrplan hat sie gewählt), in ein freies echtes Depot gleichen Namens umsetzen.
function Depot.stray(train, stop)
  if not names()[stop.backer_name] then return end
  local id = train.id
  local service = storage.trains.service[id]
  if service == "relocate" or service == "relocate-serviced" then
    storage.trains.service[id] = nil -- schon einmal versucht: nicht pendeln
    Depot.no_free_depot(train, stop)
    return
  end
  -- Kommt er von einer Dienstfahrt, im Depot nicht gleich wieder tanken/aufräumen schicken.
  if not Depot.relocate(train, stop, nil, service ~= nil) then Depot.no_free_depot(train, stop) end
end

return Depot
