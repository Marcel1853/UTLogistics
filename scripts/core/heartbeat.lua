--- Der einzige periodische Takt des Mods (kein on_tick).
--- Aufgaben melden sich beim Laden mit eigenem Takt an und bekommen ihr
--- Arbeitsbudget selbst mit. Registriert wird nur, wenn es Arbeit gibt.
local Config = require("scripts.core.config")
local Perf = require("scripts.core.perf")

local Heartbeat = {}

local tasks = {}
local registered_interval = nil -- nur lokal, wird aus storage abgeleitet

--- Meldet eine Aufgabe an. `every` = alle wie viele Heartbeats sie läuft.
function Heartbeat.add_task(name, every, fn)
  tasks[#tasks + 1] = { name = name, every = every, fn = fn }
end

local function tick()
  local hb = storage.heartbeat
  local count = hb.count + 1
  hb.count = count
  for i = 1, #tasks do
    local task = tasks[i]
    if count % task.every == 0 then
      Perf.measure(task.name, task.fn)
    end
  end
end

--- Gibt es gerade etwas zu tun? Ohne Stationen und Lieferungen schläft der Takt.
function Heartbeat.is_needed()
  return storage.stations.count > 0 or storage.deliveries.count > 0
end

--- Registriert den Takt passend zu storage. Darf auch in on_load laufen.
function Heartbeat.update_registration()
  local cfg = Config.get()
  local wanted = (cfg and Heartbeat.is_needed()) and cfg.heartbeat_interval or nil
  if wanted == registered_interval then return end
  if registered_interval then
    script.on_nth_tick(registered_interval, nil)
  end
  if wanted then
    script.on_nth_tick(wanted, tick)
  end
  registered_interval = wanted
end

function Heartbeat.registered_interval()
  return registered_interval
end

return Heartbeat
