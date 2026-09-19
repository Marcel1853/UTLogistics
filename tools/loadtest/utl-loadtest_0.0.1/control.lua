--- Headless-Lasttest: nutzt den Code des Szenarios „UTL-Lasttest“ (scenarios/UTL-Lasttest/).
--- Gebaut wird in on_init (beim Erstellen des Spielstands), gemessen wird der Betrieb danach.
local Lasttest = require("__UTLogistics__/scenarios/UTL-Lasttest/lasttest")

-- Zeitmessung der UTL-Aufgaben: für die ersten N Heartbeats …
local PROFILE = nil
-- … oder ab diesem Tick für 1200 Heartbeats (Dauerbetrieb). nil = aus.
local PROFILE_AT = nil

script.on_init(function()
  Lasttest.setup()
  if PROFILE then remote.call("utl", "perf", PROFILE) end
end)

script.on_event(defines.events.on_train_changed_state, Lasttest.on_train_changed_state)

script.on_nth_tick(60, function(event)
  if PROFILE_AT and event.tick == PROFILE_AT then remote.call("utl", "perf", 1200) end
  Lasttest.on_nth_tick_60(event)
end)
