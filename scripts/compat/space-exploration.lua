--- Space Exploration: Züge fahren durch den Weltraumaufzug auf eine andere Oberfläche. SE baut sie
--- dort Wagen für Wagen neu – mit neuer Zug-ID. UTL merkt sich den Beginn (die alte ID darf dann
--- nicht als „Zug umgebaut“ zählen) und zieht am Ende alle Einträge auf die neue ID um.
--- Schnittstelle laut SE 0.7.62 (scripts/remote-interface.lua): Ereignis-IDs per remote.call,
--- Daten { train, old_train_id_1, old_surface_index, teleporter, stranded? }.
local Events = require("scripts.core.events")
local Rekey = require("scripts.trains.rekey")
local Elevators = require("scripts.compat.se-elevators")

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

local function on_finished(event)
  if event.old_train_id_1 then Rekey.move(event.old_train_id_1, event.train) end
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
