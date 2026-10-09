--- Zug umgebaut: Wagen an- oder abgekuppelt. UTL kuppelt selbst nie – das macht ein anderer Mod und
--- meldet es über die Schnittstelle (begin_train_change / end_train_change), damit die Lieferung den
--- Umbau übersteht. Ohne Meldung gilt der alte Zug als zerlegt (trains/init.lua: retire).
local Registry = require("scripts.stations.registry")
local Deliveries = require("scripts.deliveries.deliveries")
local Reservations = require("scripts.deliveries.reservations")
local Depot = require("scripts.trains.depot")
local Schedule = require("scripts.trains.schedule")
local Filters = require("scripts.trains.wagon-filters")
local Pending = require("scripts.trains.pending")
local Rekey = require("scripts.trains.rekey")
local Held = require("scripts.trains.held")
local TeamConfig = require("scripts.core.team-config")
local Jobs = require("scripts.trains.jobs")

local TrainChange = {}

--- Alle UTL-Einträge der alten Zug-ID wegwerfen; eine Lieferung wird abgebrochen („rebuilt“).
--- Liefert true, wenn eine Lieferung abgebrochen wurde.
function TrainChange.retire(old)
  local trains = storage.trains
  Filters.reset(old) -- die Wagen gehören jetzt zu einer anderen Zug-ID
  Depot.remove(old)
  trains.service[old] = nil
  trains.visiting[old] = nil
  trains.cargo_waiting[old] = nil
  trains.home[old] = nil
  trains.waiting_at[old] = nil
  trains.held[old] = nil
  if trains.transfer then trains.transfer[old] = nil end
  Pending.release(old) -- vorgemerkte Fahrten der alten Zug-ID
  local job_id = storage.jobs.by_train[old]
  local job = job_id and storage.jobs.active[job_id]
  if job then Jobs.finish(job, true, "rebuilt") end
  local delivery = Deliveries.of_train(old)
  if delivery then
    Deliveries.cancel(delivery, "rebuilt")
    return true, delivery.id
  end
  return false
end

--- Umbau beginnt: `ids` = Zug-ID oder Liste der Zug-IDs, die gleich verschwinden. Der eigene
--- Fahrplan wird gesichert: Steht der neue Zug ohne Fahrplan da, bekommt er ihn zurück.
function TrainChange.begin(ids)
  if type(ids) ~= "table" then ids = { ids } end
  local saved = storage.trains.change_records
  for _, id in pairs(ids) do
    if type(id) == "number" then
      Rekey.start(id)
      local train = game.train_manager.get_train_by_id(id)
      local schedule = train and train.get_schedule()
      if schedule then
        local own = {}
        for _, record in pairs(schedule.get_records() or {}) do
          if not record.temporary then own[#own + 1] = record end
        end
        saved[id] = { group = schedule.group, records = own }
      end
    end
  end
end

--- Neuer Zug ganz ohne Fahrplan: den gesicherten eigenen Fahrplan (Gruppe oder Halte) zurückgeben.
local function restore_own(train, old_ids)
  local saved = storage.trains.change_records
  local schedule = train.get_schedule()
  for _, old in pairs(old_ids) do
    local entry = saved[old]
    saved[old] = nil
    if entry and schedule and (schedule.get_record_count() or 0) == 0 and not schedule.group then
      if entry.group and entry.group ~= "" then
        schedule.group = entry.group
      elseif entry.records[1] then
        schedule.set_records(entry.records)
      end
    end
  end
end

local function timeouts_of(train)
  local force = train.front_stock and train.front_stock.force
  return { load = TeamConfig.get(force, "load_timeout"), unload = TeamConfig.get(force, "unload_timeout"),
    mode = TeamConfig.get(force, "timeout_mode") }
end

local function stop_of(unit)
  local station = unit and Registry.get(unit)
  local stop = station and station.stop
  return stop and stop.valid and stop or nil
end

--- Steht der nächste Halt der Lieferung noch im Fahrplan? Je nach Mod behält beim Kuppeln nur ein
--- Teil die temporären Halte. Fehlen sie, setzt UTL die restlichen Halte neu (ohne Halte, die ein
--- Add-on eingefügt hatte, und ohne Weltraumaufzug).
local function restore(delivery)
  local train = delivery.train
  if delivery.via or not (train and train.valid) then return end
  local loading = delivery.state == "to_provider" or delivery.state == "loading"
  local target = stop_of(loading and Reservations.pickup_unit(delivery) or delivery.requester)
  local requester = stop_of(delivery.requester)
  if not (target and requester) then return end
  local schedule = train.get_schedule()
  if not schedule then return end
  local records = schedule.get_records() or {}
  for i, record in ipairs(records) do
    if record.temporary and record.station == target.backer_name then
      -- Halte noch da: Zeigt der Fahrplan nach dem Umbau woandershin (kein Halt, eigener Halt),
      -- wieder zum Halt der Lieferung schicken (mit dem Schienen-Wegpunkt davor).
      local current = schedule.current
      if not (current and records[current] and records[current].temporary) then
        local before = records[i - 1]
        schedule.go_to_station((before and before.temporary and before.rail) and i - 1 or i)
      end
      return
    end
  end
  local timeouts = timeouts_of(train)
  local legs = {}
  if loading then
    local first = delivery.second and delivery.leg ~= 2
    legs[#legs + 1] = { stop = target,
      wait = Schedule.loading_wait(first and Reservations.first_share(delivery) or delivery.manifest, timeouts) }
    local second = first and stop_of(delivery.second.unit)
    if second then legs[#legs + 1] = { stop = second, wait = Schedule.loading_wait(delivery.manifest, timeouts) } end
  end
  legs[#legs + 1] = { stop = requester, wait = Schedule.unloading_wait(timeouts) }
  Schedule.clear(train)
  Schedule.send_legs(train, legs)
  delivery.extra_stops = nil
end

--- Umbau fertig: Die Einträge der alten Zug-IDs `old_ids` ziehen auf `train` um. Hatten mehrere
--- alte Züge eine Lieferung, behält `train` die erste, die anderen werden abgebrochen. Ein Teil, der
--- nicht weitermachen soll, wird mit `forget` vergessen. Liefert true bei Erfolg.
function TrainChange.finish(old_ids, train)
  if type(old_ids) ~= "table" then old_ids = { old_ids } end
  if not (train and train.valid) then
    for _, old in pairs(old_ids) do TrainChange.retire(old) end
    return false
  end
  restore_own(train, old_ids)
  local kept = Deliveries.of_train(train.id)
  for _, old in pairs(old_ids) do
    if type(old) == "number" and old ~= train.id then
      local delivery = Deliveries.of_train(old)
      if delivery and kept then
        TrainChange.retire(old)
      else
        Rekey.move(old, train)
        kept = kept or delivery
      end
    elseif storage.trains.transfer then
      storage.trains.transfer[old] = nil
    end
  end
  if kept then
    restore(kept)
  elseif not Held.is(train.id) and train.state == defines.train_state.wait_station and train.station then
    -- im Depot umgebaut: neu einparken (misst den Laderaum neu)
    local unit = storage.stations.by_stop[train.station.unit_number]
    local station = unit and Registry.get(unit)
    if station then
      Depot.remove(train.id)
      Depot.arrive(train, train.station, station)
    end
  end
  return true
end

--- Zug (alte oder aktuelle ID) für UTL vergessen, z. B. den abgekuppelten Teil, der nicht
--- weiterfahren soll. Eine Lieferung daran wird abgebrochen.
function TrainChange.forget(train_id)
  return (TrainChange.retire(train_id))
end

return TrainChange
