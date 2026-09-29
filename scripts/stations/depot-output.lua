--- Auftrags-Ausgabe am Depot (Wunsch Marcel): Lieferungen gibt es dort nicht, dafür
---   * der Zug, der hier steht: Zug-Nummer, Länge, Loks, Wagen, „knapp an Treibstoff“ und „ohne
---     Treibstoff“ (unter dem Mindest-Treibstoff, fährt nicht mehr los; je 1/0) –
---     z. B. damit ein Kohle-Greifarm im Depot nur bei Bedarf läuft,
---   * „Züge frei im Depot“: freie Züge aller Depots mit diesem Namen (Oberfläche + Team),
---   * „Züge unterwegs hierher“: Züge auf dem Weg zu dieser Haltestelle.
--- Neu geschrieben bei Ankunft/Abfahrt (trains/init.lua) und sonst reihum höchstens alle EVERY
--- Ticks (DepotOutput.scan, festes Budget je Heartbeat – Regel 5).
local Fuel = require("scripts.trains.fuel")
local Pending = require("scripts.trains.pending")

local DepotOutput = {}

local SCAN = 50    -- Stationen je Heartbeat durchsehen
local EVERY = 120  -- ein Depot höchstens so oft neu schreiben

local function group_key(stop, name)
  return stop.surface_index .. "|" .. stop.force_index .. "|" .. name
end

--- Einmal je Heartbeat für alle Depots: freie Züge je Depot-Name und vorgemerkte Fahrten je
--- Haltestelle (UTL schickt Züge per Schienen-Wegpunkt heim – die zählt das Spiel nicht mit).
function DepotOutput.cache()
  local free = {}
  local trains = storage.trains
  for id in pairs(trains.by_id) do
    local home = trains.home[id]
    local stop = home and home.stop
    if stop and stop.valid then
      local key = group_key(stop, home.depot)
      free[key] = (free[key] or 0) + 1
    end
  end
  return { free = free, pending = Pending.counts() }
end

--- Signale eines Depots über `put_signal(name, menge)` setzen.
function DepotOutput.write(station, put_signal, cache)
  local stop = station.stop
  if not (stop and stop.valid) then return end
  cache = cache or DepotOutput.cache()
  local train = stop.get_stopped_train()
  if train then
    put_signal("utl-train-id", train.id)
    put_signal("utl-train-length", #train.carriages)
    put_signal("utl-train-locos", #train.locomotives.front_movers + #train.locomotives.back_movers)
    put_signal("utl-train-wagons", #train.cargo_wagons + #train.fluid_wagons)
    put_signal("utl-trains-low-fuel", Fuel.is_low(train) and 1 or 0)
    put_signal("utl-trains-no-fuel", Fuel.is_empty(train) and 1 or 0)
  end
  put_signal("utl-trains-free", cache.free[group_key(stop, stop.backer_name)] or 0)
  -- trains_count zählt den Zug, der hier steht, mit
  local coming = stop.trains_count - (train and 1 or 0) + (cache.pending[stop.unit_number] or 0)
  put_signal("utl-trains-incoming", math.max(0, coming))
end

--- Reihum Depots zum Neuschreiben vormerken (`mark(unit)`), höchstens SCAN Stationen je Aufruf.
function DepotOutput.scan(mark)
  local stations = storage.stations
  local by_unit = stations.by_unit
  local deliveries = storage.deliveries
  local unit = deliveries.depot_cursor
  if unit and not by_unit[unit] then unit = nil end
  local now = game.tick
  local station
  for _ = 1, SCAN do
    unit, station = next(by_unit, unit)
    if not unit then break end
    if station.config.roles.depot and now >= (station.output_due or 0) then
      station.output_due = now + EVERY
      mark(unit)
    end
  end
  deliveries.depot_cursor = unit
end

return DepotOutput
