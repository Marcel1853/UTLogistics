--- Space Exploration: Züge fahren durch den Weltraumaufzug auf eine andere Oberfläche. SE baut sie
--- dort Wagen für Wagen neu – mit neuer Zug-ID. UTL merkt sich den Beginn (die alte ID darf dann
--- nicht als „Zug umgebaut“ zählen) und zieht am Ende alle Einträge auf die neue ID um.
--- Schnittstelle laut SE 0.7.62 (scripts/remote-interface.lua): Ereignis-IDs per remote.call,
--- Daten { train, old_train_id_1, old_surface_index, teleporter, stranded? }.
local Events = require("scripts.core.events")
local Rekey = require("scripts.trains.rekey")

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

Events.on_start(function()
  local started, finished = event_ids()
  if not (started and finished) then return end
  script.on_event(started, on_started)
  script.on_event(finished, on_finished)
  log("UTL: Space Exploration erkannt – Zugfahrten durch den Weltraumaufzug werden verfolgt")
end)

return SE
