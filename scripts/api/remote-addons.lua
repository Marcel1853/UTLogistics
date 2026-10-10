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
local Jobs = require("scripts.trains.jobs")
local AddonRegistry = require("scripts.api.addons")
local CreateDelivery = require("scripts.api.create-delivery")
local Roles = require("scripts.stations.roles")
local util = require("util")

-- Stand der Schnittstelle: steigt, wenn Funktionen oder Ereignisse dazukommen.
-- 1: Umbau, Festhalten, Halte einfügen, Zug-Ereignisse · 2: Rollen, Aufträge, Daten, Fenster, Manager
-- 3: Zugfilter, remeasure_train · 4: Wegpunkte per Position, eigene temporäre Einträge bleiben
-- 5: Ereignisse für Stationen, Warnungen und Anfragen ohne Zug
local API_VERSION = 5

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
  local owner = Held.belongs_to(train_id) -- festgehalten oder im Depot eines anderen Add-ons
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

-- ── Eigene Rollen, Fenster, Manager ──────────────────────────────────────────────────────────

--- Eigene Rolle für Bahnhöfe: { mod, name, caption, tooltip, base, own_trains }.
---   base nil = eigene Rolle, UTL vermittelt dort nichts (nur Ereignisse); sonst verhält sich die
---   Station für den Dispatcher wie "provider" | "requester" | "provider_requester" | "depot" |
---   "fuel" | "cleanup" | "storage". own_trains = true (nur mit base "depot"): Züge dort gehören dem
---   Add-on, UTL nimmt sie nie (frei: get_idle_trains{ role = "mod/name" }, Ereignis on_train_idle).
--- In on_init und on_configuration_changed aufrufen. Liefert true oder false und einen Grund.
function Addons.register_role(spec)
  return AddonRegistry.register_role(spec)
end

--- Station auf eine Add-on-Rolle setzen ("mod/name") oder mit nil zurück auf „ohne Aufgabe“.
function Addons.set_station_role(unit, key)
  local station = Registry.get(unit)
  if not station then return false end
  local role = key and AddonRegistry.role(key)
  if key and not role then return false end
  Roles.apply_addon(station.config, role)
  Registry.config_changed(station)
  return true
end

--- Abschnitt im Stationsfenster: { mod, interface, build }. UTL ruft
--- remote.call(interface, build, flow, station_unit, player_index) mit einem leeren Flow; bleibt er
--- leer, verschwindet er wieder. Eigene GUI-Ereignisse behandelt das Add-on selbst.
function Addons.register_gui_section(spec)
  return AddonRegistry.register_section(spec)
end

--- Reiter im UTL-Manager: { mod, interface, build, caption }. Wird der Reiter gewählt (oder ⟲),
--- ruft UTL remote.call(interface, build, flow, player_index) mit dem geleerten Inhalt.
function Addons.register_manager_tab(spec)
  return AddonRegistry.register_tab(spec)
end

--- Bei der Zugwahl mitreden: { mod, interface, filter }. Nur wenn Anbieter oder Abnehmer einer
--- Fahrt eine Add-on-Rolle haben, ruft UTL einmal je Vermittlung
--- remote.call(interface, filter, train_ids, { provider, requester, key, provider_role, requester_role })
--- auf; Rückgabe = erlaubte Zug-IDs in Wunschreihenfolge (nil = alle wie bisher).
function Addons.register_train_filter(spec)
  return AddonRegistry.register_filter(spec)
end

--- Laderaum eines freien Zugs neu messen (z. B. nachdem das Add-on ihn im Depot umgebaut hat,
--- ohne dass sich die Zug-ID geändert hat). Liefert true, wenn UTL den Zug als frei kennt.
function Addons.remeasure_train(train_id)
  local record = Depot.get(train_id)
  if not (record and record.train.valid) then return false end
  record.slots, record.wagons, record.fluid = Depot.measure(record.train)
  record.length = #record.train.carriages
  return true
end

-- ── Daten je Station ────────────────────────────────────────────────────────────────────────

--- Eigener Wert an einer Station (reist in Blaupausen und beim Einstellungen-Kopieren mit).
--- `value` = Zahl, Text, Wahrheitswert, Tabelle daraus oder nil (löschen).
function Addons.set_station_data(unit, mod, key, value)
  local station = Registry.get(unit)
  if not (station and type(mod) == "string" and key ~= nil) then return false end
  local cfg = station.config
  cfg.ext = cfg.ext or {}
  local data = cfg.ext[mod] or {}
  data[key] = util.table.deepcopy(value)
  cfg.ext[mod] = next(data) and data or nil
  if not next(cfg.ext) then cfg.ext = nil end
  return true
end

--- Alle Werte eines Mods an einer Station (Kopie) oder nil.
function Addons.get_station_data(unit, mod)
  local station = Registry.get(unit)
  local ext = station and station.config.ext
  return ext and ext[mod] and util.table.deepcopy(ext[mod]) or nil
end

-- ── Aufträge ────────────────────────────────────────────────────────────────────────────────

--- Zug über eigene Halte schicken: stops = { { station = unit | stop = Haltestelle | rail +
--- rail_direction, wait = Wartebedingungen }, … }. Der Zug ist so lange festgehalten; am Ende kommt
--- on_job_finished und er fährt mit seinem Fahrplan weiter. Liefert die Auftrags-ID oder nil + Grund.
function Addons.send_job(train_id, mod, stops)
  return Jobs.send(train_id, mod, stops)
end

function Addons.cancel_job(id)
  local job = Jobs.get(id)
  if not job then return false end
  Jobs.cancel(job, "remote")
  return true
end

--- { id, mod, train_id, stops, started } oder nil.
function Addons.get_job(id)
  local job = Jobs.get(id)
  return job and Jobs.info(job) or nil
end

--- Normale UTL-Lieferung anstoßen: { provider = unit, requester = unit, type, name, quality, amount,
--- train = Zug-ID (optional, sonst der nächste freie) }. Liefert die Lieferungs-ID oder nil + Grund.
function Addons.create_delivery(spec)
  return CreateDelivery.create(spec)
end

return Addons
