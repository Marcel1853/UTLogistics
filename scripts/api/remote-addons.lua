--- Schnittstelle „utl“ für Add-ons (seit 0.0.16), eingebunden in api/remote.lua: Züge umbauen,
--- festhalten, Halte in Lieferungen einfügen, Züge an einer Station. UTL kuppelt selbst nie und
--- plant nichts für das Add-on – es führt nur Fahrpläne aus und meldet, was passiert.
--- Rückgaben sind Kopien; Züge über `train.id`, Stationen über die `unit_number` des Kombinators.
local Deliveries = require("scripts.deliveries.deliveries")
local ExtraStops = require("scripts.deliveries.extra-stops")
local Registry = require("scripts.stations.registry")
local Depot = require("scripts.trains.depot")
local Held = require("scripts.trains.held")
local TrainChange = require("scripts.trains.train-change")

-- Stand der Schnittstelle: steigt, wenn Funktionen oder Ereignisse dazukommen.
local API_VERSION = 1

local Addons = {}

local function train_by_id(id)
  return type(id) == "number" and game.train_manager.get_train_by_id(id) or nil
end

--- Stand der Schnittstelle (Zahl). Add-ons prüfen damit, ob es eine Funktion schon gibt.
function Addons.api_version()
  return API_VERSION
end

--- Umbau beginnt (Wagen an- oder abkuppeln): `ids` = Zug-ID oder Liste der IDs, die gleich
--- verschwinden. Bis end_train_change bricht UTL deren Lieferungen nicht ab.
function Addons.begin_train_change(ids)
  TrainChange.begin(ids)
  return true
end

--- Umbau fertig: Die Einträge (Lieferung, Depot, festgehalten …) der alten IDs ziehen auf `train`
--- (LuaTrain) um. Fehlen die UTL-Halte danach im Fahrplan, setzt UTL sie neu.
function Addons.end_train_change(old_ids, train)
  return TrainChange.finish(old_ids, train)
end

--- Zug für UTL vergessen (z. B. abgekuppelter Teil). Eine Lieferung daran wird abgebrochen.
function Addons.forget_train(train_id)
  return TrainChange.forget(train_id)
end

--- Zug festhalten: UTL schickt ihn nirgendwohin, verkettet ihn nicht, nimmt ihn nicht in den
--- Depot-Pool und bricht nichts ab (auch nicht im Handbetrieb). Eine laufende Lieferung bleibt und
--- geht nach release_train weiter. Liefert false, wenn ein anderer Mod ihn schon festhält.
function Addons.hold_train(train_id, mod)
  if type(mod) ~= "string" or not train_by_id(train_id) then return false end
  local owner = Held.owner(train_id)
  if owner and owner ~= mod then return false end
  storage.trains.held[train_id] = mod
  Depot.remove(train_id)
  storage.trains.cargo_waiting[train_id] = nil
  return true
end

--- Zug wieder freigeben. Steht er ohne Lieferung in einem Depot, ist er sofort wieder frei;
--- sonst fährt er nach seinem Fahrplan weiter.
function Addons.release_train(train_id)
  if not Held.is(train_id) then return false end
  storage.trains.held[train_id] = nil
  local train = train_by_id(train_id)
  if train and not Deliveries.of_train(train_id) and train.state == defines.train_state.wait_station and train.station then
    local unit = storage.stations.by_stop[train.station.unit_number]
    local station = unit and Registry.get(unit)
    if station then Depot.arrive(train, train.station, station) end
  end
  return true
end

--- Name des Mods, der den Zug festhält, sonst nil.
function Addons.is_held(train_id)
  return Held.owner(train_id)
end

--- Halt in eine laufende Lieferung einfügen. `spec`:
---   where = "before_provider" | "after_provider" (Standard) | "after_requester"
---   station = UTL-Station (unit) oder stop = Haltestelle (LuaEntity/unit_number) oder
---   rail = Gleis (LuaEntity) + rail_direction
---   wait = Wartebedingungen (wie in LuaSchedule; leer = durchfahren)
--- Liefert true oder false und einen Grund.
function Addons.add_delivery_stop(delivery_id, spec)
  return ExtraStops.add(storage.deliveries.active[delivery_id], spec)
end

--- Züge an einer UTL-Station: { here = { Zug-IDs, die dort warten }, coming = { Zug-IDs mit einer
--- Lieferung, die als Nächstes dorthin fährt } }. nil, wenn es die Station nicht gibt.
function Addons.get_trains_at_station(unit)
  local station = Registry.get(unit)
  if not station then return nil end
  local here, coming = {}, {}
  for id, at in pairs(storage.trains.waiting_at) do
    if at == unit then here[#here + 1] = id end
  end
  for _, delivery in pairs(storage.deliveries.active) do
    local state = delivery.state
    local target = nil
    if state == "to_provider" then
      target = (delivery.leg == 2 and delivery.second) and delivery.second.unit or delivery.provider
    elseif state == "to_requester" then
      target = delivery.requester
    end
    if target == unit then coming[#coming + 1] = delivery.train_id end
  end
  table.sort(here)
  table.sort(coming)
  return { here = here, coming = coming }
end

return Addons
