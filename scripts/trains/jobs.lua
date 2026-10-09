--- Aufträge von Add-ons (Schnittstelle send_job): Ein anderer Mod schickt einen Zug über eine Liste
--- von Halten. UTL schreibt sie als temporäre Halte in den Fahrplan, hält den Zug so lange fest
--- (kein Dispatcher, keine Dienstfahrt) und meldet das Ende mit on_job_finished. Danach fährt der
--- Zug mit seinem eigenen Fahrplan weiter (in der Regel ins Depot). Planen tut das Add-on.
local Schedule = require("scripts.trains.schedule")
local ExtraStops = require("scripts.deliveries.extra-stops")
local Depot = require("scripts.trains.depot")
local Held = require("scripts.trains.held")
local PublicEvents = require("scripts.api.public-events")
local Log = require("scripts.lib.log")

local Jobs = {}

function Jobs.of_train(train_id)
  local id = storage.jobs.by_train[train_id]
  return id and storage.jobs.active[id]
end

function Jobs.get(id)
  return storage.jobs.active[id]
end

--- Öffentliche Sicht auf einen Auftrag.
function Jobs.info(job)
  return { id = job.id, mod = job.mod, train_id = job.train_id, stops = job.stops, started = job.started }
end

--- Zug `train_id` für `mod` über `stops` schicken. `stops` = Liste { station = unit | stop =
--- Haltestelle | rail + rail_direction, wait = Wartebedingungen }. Liefert die Auftrags-ID oder nil
--- und einen Grund („unknown-train“, „busy“, „held-by-other“, „no-stops“, „bad-target“, „no-schedule“).
function Jobs.send(train_id, mod, stops)
  local train = type(train_id) == "number" and game.train_manager.get_train_by_id(train_id) or nil
  if not train then return nil, "unknown-train" end
  if type(mod) ~= "string" then return nil, "bad-mod" end
  if storage.deliveries.by_train[train_id] or storage.jobs.by_train[train_id] then return nil, "busy" end
  local owner = Held.owner(train_id)
  if owner and owner ~= mod then return nil, "held-by-other" end
  if type(stops) ~= "table" or not stops[1] then return nil, "no-stops" end
  local targets = {}
  for i, spec in ipairs(stops) do
    local target = type(spec) == "table" and ExtraStops.target_of(spec)
    if not target then return nil, "bad-target", i end
    targets[i] = { target = target, wait = spec.wait }
  end
  local schedule = train.get_schedule()
  if not schedule then return nil, "no-schedule" end
  -- erst die alten UTL-Halte weg (z. B. Wegpunkt ins Depot), dann die des Auftrags
  Schedule.clear(train)
  local first = (schedule.current or 0) + 1
  local index = first
  for _, t in ipairs(targets) do index = Schedule.insert(schedule, index, t.target, t.wait) end
  schedule.go_to_station(first)
  train.manual_mode = false

  local jobs = storage.jobs
  local id = jobs.next_id
  jobs.next_id = id + 1
  jobs.active[id] = { id = id, mod = mod, train_id = train_id, train = train, stops = #targets, started = game.tick }
  jobs.by_train[train_id] = id
  storage.trains.held[train_id] = mod
  Depot.remove(train_id)
  storage.trains.service[train_id] = nil
  storage.trains.cargo_waiting[train_id] = nil
  Log.debug("Auftrag " .. id .. " von „" .. mod .. "“: Zug " .. train_id .. " über " .. #targets .. " Halte.")
  return id
end

--- Auftrag beenden: Zug freigeben, Ereignis on_job_finished.
function Jobs.finish(job, canceled, reason)
  local jobs = storage.jobs
  jobs.active[job.id] = nil
  if jobs.by_train[job.train_id] == job.id then jobs.by_train[job.train_id] = nil end
  if Held.owner(job.train_id) == job.mod then storage.trains.held[job.train_id] = nil end
  local train = job.train
  Log.debug("Auftrag " .. job.id .. (canceled and (" abgebrochen: " .. tostring(reason)) or " fertig") .. ".")
  PublicEvents.raise_data("on_job_finished", { job_id = job.id, mod = job.mod, train = train and train.valid and train or nil,
    train_id = job.train_id, canceled = canceled == true, reason = reason })
end

--- Auftrag abbrechen: Halte weg, Zug fährt mit seinem eigenen Fahrplan weiter.
function Jobs.cancel(job, reason)
  if job.train and job.train.valid then Schedule.clear(job.train) end
  Jobs.finish(job, true, reason or "remote")
end

--- Nach jedem Zustandswechsel eines Zugs: Ist der Auftrag abgefahren (keine temporären Halte mehr)?
function Jobs.state_changed(train)
  local job = Jobs.of_train(train.id)
  if not job then return end
  if train.state == defines.train_state.wait_station then return end -- wartet noch an einem Halt
  local schedule = train.get_schedule()
  for _, record in pairs(schedule and schedule.get_records() or {}) do
    if record.temporary and not record.created_by_interrupt then return end
  end
  Jobs.finish(job, false)
end

--- Heartbeat: Aufträge, deren Zug verschwunden ist, abbrechen.
function Jobs.sweep()
  for _, job in pairs(storage.jobs.active) do
    if not (job.train and job.train.valid) and not (storage.trains.transfer or {})[job.train_id] then
      Jobs.finish(job, true, "train-lost")
    end
  end
end

return Jobs
