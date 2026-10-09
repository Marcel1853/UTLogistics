--- Rangier-Vorführung für den Add-on-Test: Die Rangierlok holt einen abgestellten Wagen, kuppelt an,
--- bringt ihn zum Ladegleis (Script belädt ihn), schiebt ihn zurück aufs Abstellgleis, kuppelt ab und
--- fährt ins Rangierdepot. Alles über die UTL-Schnittstelle – so, wie es ein echtes Add-on täte:
---   send_job (Fahrten), hold_train (während des Rangierens), begin/end_train_change (Kuppeln),
---   forget_train (abgestellter Wagen), cancel_job, release_train.
--- UTL selbst kuppelt nie; das Heranschieben und Kuppeln macht dieses Script.
local Shunting = {}

local MOD = "utl-addontest"
local SPEED = 0.04 -- Schrittgeschwindigkeit beim Heranschieben (Kacheln je Tick)

local function note(text) Shunting.note(text) end

--- Von der Testkarte: Wagen und die drei Halte (unit_number der UTL-Haltestellen).
function Shunting.setup(spec)
  storage.shunt = { wagon = spec.wagon, access = spec.access, load = spec.load, siding = spec.siding, phase = "idle" }
end

local function state() return storage.shunt end

local function send(train, stops, phase)
  local s = state()
  local id, why = remote.call("utl", "send_job", train.id, MOD, stops)
  if not id then
    note("Rangieren: Auftrag abgelehnt (" .. tostring(why) .. ")")
    return
  end
  storage.jobs = storage.jobs or {}
  storage.jobs[id] = true
  s.job, s.phase = id, phase
end

--- Rangierlok frei im Rangierdepot: Wagen holen.
function Shunting.idle(train)
  local s = state()
  if not (s and s.wagon and s.wagon.valid) or s.phase ~= "idle" then return end
  s.loco = train.front_stock
  note("Rangieren: Lok holt den Wagen")
  send(train, { { station = s.access, wait = { { type = "time", ticks = 30 } } } }, "to_access")
end

--- Auftrag beenden und den Zug selbst festhalten (Handbetrieb zum Rangieren).
local function take_over(train)
  local s = state()
  if s.job then remote.call("utl", "cancel_job", s.job) end
  s.job = nil
  remote.call("utl", "hold_train", train.id, MOD)
  train.manual_mode = true
end

--- Ankunft an einem Halt des Auftrags.
function Shunting.arrived(event)
  local s = state()
  if not (s and event.job_id and event.job_id == s.job) then return end
  local train = event.train
  if s.phase == "to_access" and event.station == s.access then
    take_over(train)
    s.phase = "couple"
    note("Rangieren: schiebe an den Wagen heran")
  elseif s.phase == "to_load" and event.station == s.load then
    s.wagon.get_inventory(defines.inventory.cargo_wagon).insert({ name = "iron-plate", count = 2000 })
    note("Rangieren: Wagen am Ladegleis beladen")
  elseif s.phase == "to_load" and event.station == s.siding then
    take_over(train)
    -- abkuppeln: Wagen ist vorn (geschoben)
    local old = train.id
    remote.call("utl", "begin_train_change", { old })
    for _, dir in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      if s.wagon.train == s.loco.train then s.wagon.disconnect_rolling_stock(dir) end
    end
    local loco_train = s.loco.train
    remote.call("utl", "end_train_change", { old }, loco_train)
    remote.call("utl", "forget_train", s.wagon.train.id)
    s.wagon.get_inventory(defines.inventory.cargo_wagon).clear() -- auf dem Abstellgleis „entladen“
    remote.call("utl", "release_train", loco_train.id)
    loco_train.manual_mode = false -- zurück ins Rangierdepot (eigener Fahrplan)
    s.phase = "idle"
    note("Rangieren: Wagen abgestellt, Lok fährt ins Depot")
  end
end

--- Alle 5 Ticks: beim Heranschieben bewegen und ankuppeln, sobald der Wagen anliegt.
function Shunting.tick()
  local s = state()
  if not (s and s.phase == "couple" and s.loco and s.loco.valid and s.wagon.valid) then return end
  local train = s.loco.train
  -- Richtung: zum Wagen hin (positive Geschwindigkeit fährt Richtung front_stock)
  local wx = s.wagon.position.x
  local towards_front = math.abs(train.front_stock.position.x - wx) < math.abs(train.back_stock.position.x - wx)
  -- anliegend? (Abstand der Mitten ≤ 7,2 Kacheln: eine Kupplungslänge)
  local nearest = towards_front and train.front_stock or train.back_stock
  if math.abs(nearest.position.x - wx) <= 7.2 then
    train.speed = 0
    local old = train.id
    remote.call("utl", "begin_train_change", { old })
    nearest.connect_rolling_stock(defines.rail_direction.front)
    if s.wagon.train ~= train then nearest.connect_rolling_stock(defines.rail_direction.back) end
    local joined = s.wagon.train
    if joined == s.loco.train then
      remote.call("utl", "end_train_change", { old }, joined)
      note("Rangieren: angekuppelt (Zug " .. old .. " → " .. joined.id .. ")")
      send(joined, {
        { station = s.load, wait = { { type = "time", ticks = 300 } } },
        { station = s.siding, wait = { { type = "time", ticks = 30 } } },
      }, "to_load")
    else
      remote.call("utl", "end_train_change", { old }, s.loco.train) -- Kuppeln ging nicht: nichts ändert sich
      train.speed = towards_front and SPEED or -SPEED
    end
    return
  end
  train.speed = towards_front and SPEED or -SPEED
end

return Shunting
