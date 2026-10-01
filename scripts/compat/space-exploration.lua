--- Space Exploration: Züge fahren durch den Weltraumaufzug auf eine andere Oberfläche. SE baut sie
--- dort Wagen für Wagen neu – mit neuer Zug-ID. UTL merkt sich den Beginn (die alte ID darf dann
--- nicht als „Zug umgebaut“ zählen) und zieht am Ende alle Einträge auf die neue ID um.
--- Schnittstelle laut SE 0.7.62 (scripts/remote-interface.lua): Ereignis-IDs per remote.call,
--- Daten { train, old_train_id_1, old_surface_index, teleporter, stranded? }.
local Events = require("scripts.core.events")
local Rekey = require("scripts.trains.rekey")
local Elevators = require("scripts.compat.se-elevators")
local Deliveries = require("scripts.deliveries.deliveries")
local Schedule = require("scripts.trains.schedule")
local DepotRoute = require("scripts.trains.depot-route")

local SE = {}

local INTERFACE = "space-exploration"

--- Ereignis-IDs von SE oder nil (SE nicht aktiv oder zu alt).
local function event_ids()
  local interface = remote.interfaces[INTERFACE]
  if not (interface and interface.get_on_train_teleport_started_event and interface.get_on_train_teleport_finished_event) then
    return nil
  end
  return remote.call(INTERFACE, "get_on_train_teleport_started_event"),
    remote.call(INTERFACE, "get_on_train_teleport_finished_event")
end

local function on_started(event)
  if event.old_train_id_1 then Rekey.start(event.old_train_id_1) end
end

--- Nach dem Aufzug: den Schienen-Wegpunkt vor dem Abnehmer wieder einsetzen (SE löscht Schienen-
--- Einträge beim Durchfahren, UTL plant hinter dem Aufzug nur Stations-Einträge).
local function waypoint_to_requester(train, delivery)
  local requester = storage.stations.by_unit[delivery.requester]
  local stop = requester and requester.stop
  local front = train.front_stock
  if not (stop and stop.valid and front and stop.surface_index == front.surface_index) then return end
  local schedule = train.get_schedule()
  local current = schedule and schedule.current
  local record = current and schedule.get_record({ schedule_index = current })
  if record and record.temporary and record.station == stop.backer_name then
    Schedule.waypoint_before(train, stop, current)
  end
end

local function on_finished(event)
  local train = event.train
  if not (event.old_train_id_1 and train and train.valid) then return end
  Rekey.move(event.old_train_id_1, train)
  local delivery = Deliveries.of_train(train.id)
  if event.stranded then
    -- Zug im Aufzug zerrissen (z. B. Strom weg): SE schaltet beide Teile auf Handbetrieb
    if delivery then Deliveries.cancel(delivery, "rebuilt") end
    return
  end
  if delivery then
    if delivery.state == "to_requester" then waypoint_to_requester(train, delivery) end
  else
    DepotRoute.send_home(train) -- zurück auf der Depot-Seite: freies Depot wie sonst auch
  end
end

--- Aufzug fertig gebaut, kaputt, mit/ohne Strom: beide Seiten neu einlesen.
local function on_elevator_changed(event)
  Elevators.refresh(event.primary)
end

-- Abriss eines Aufzugs (register_on_object_destroyed in se-elevators.lua)
Events.on(defines.events.on_object_destroyed, function(event)
  if event.useful_id and storage.elevators then Elevators.forget(event.useful_id) end
end)

-- Mod neu, SE neu oder aktualisiert: alle Aufzüge neu einlesen
Events.on_configuration_changed(function() Elevators.scan() end)

Events.on_start(function()
  local started, finished = event_ids()
  if not (started and finished) then return end
  script.on_event(started, on_started)
  script.on_event(finished, on_finished)
  local interface = remote.interfaces[INTERFACE]
  if interface.get_on_space_elevator_changed_state_event then
    script.on_event(remote.call(INTERFACE, "get_on_space_elevator_changed_state_event"), on_elevator_changed)
  end
  log("UTL: Space Exploration erkannt – Zugfahrten durch den Weltraumaufzug werden verfolgt")
end)

return SE
