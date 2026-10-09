--- Rangier-Bahnhof aus Marcels Blaupause (Szenario „rangieren“): Abstellgleise links (Wagen stehen am
--- Westende), Ladebuchten rechts (Wagen sollen am Ostende stehen), Rangierdepot oben, Wendestummel unten.
--- Die Rangierlok holt alle Wagen eines Gleises, wendet im Stummel (dann sind die Wagen vorn) und schiebt
--- sie auf ein freies Gleis der anderen Seite bis ans Ende. Erst alle nach rechts, dann wieder zurück.
---
--- Genutzte UTL-Schnittstelle: send_job, cancel_job, hold_train, release_train, begin/end_train_change,
--- forget_train, get_station, Ereignisse on_train_idle/on_train_arrived. UTL kuppelt nie selbst.
local Yard = {}

local MOD = "utl-addontest"
local SPEED = 0.05

local function note(text) Yard.note(text) end
local function y_of(stop) return math.floor(stop.connected_rail.position.y + 0.5) end

local function role_of(stop)
  local info = remote.call("utl", "get_station", stop.unit_number) --[[@as table?]]
  return info and info.config.addon_role or (info and info.config.mode)
end

--- Bahnhof erkennen: Haltestellen nach Name/Rolle und Gleis (y) ordnen.
function Yard.setup(surface_index)
  local s = game.surfaces[surface_index]
  local yard = { surface = surface_index, west = {}, east = {}, phase = "idle" }
  local stops = s.find_entities_filtered({ name = "utl-train-stop" })
  for _, stop in ipairs(stops) do
    if role_of(stop) == MOD .. "/depot" then yard.depot = stop end
  end
  local cx = yard.depot and yard.depot.position.x or 0
  yard.cx = cx
  for _, stop in ipairs(stops) do
    if stop.connected_rail then
      local role, y = role_of(stop), y_of(stop)
      if stop.position.x < cx - 20 then
        -- Abstellgleise: Zufahrt = östlichere Haltestelle, Ziel beim Abstellen ebenso
        local t = yard.west[y] or {}
        if not t.access or stop.position.x > t.access.position.x then t.access = stop end
        yard.west[y] = t
      elseif stop.position.x > cx + 20 then
        local t = yard.east[y] or {}
        if role == MOD .. "/bay" then t.bay = stop else t.access = stop end
        yard.east[y] = t
      elseif stop ~= yard.depot then
        yard.turn = stop -- Wendestummel unten
      end
    end
  end
  storage.yard = yard
  local count = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  note("Rangier-Bahnhof: " .. count(yard.west) .. " Abstellgleise, " .. count(yard.east) .. " Ladegleise, Wendestummel "
    .. (yard.turn and yard.turn.backer_name or "fehlt"))
end

--- Wagen auf Gleis y einer Seite (west/east).
local function wagons_on(yard, side, y)
  local s = game.surfaces[yard.surface]
  local list = {}
  for _, w in ipairs(s.find_entities_filtered({ type = "cargo-wagon" })) do
    local wy = math.floor(w.position.y + 0.5)
    if math.abs(wy - y) <= 1 and ((side == "west" and w.position.x < yard.cx - 20) or (side == "east" and w.position.x > yard.cx + 20)) then
      list[#list + 1] = w
    end
  end
  return list
end

--- Platz an der Haltestelle (Zuglimit)? Das Add-on prüft selbst; UTL lehnt sonst mit „station-full“ ab.
local function free(stop)
  local limit = stop.trains_limit
  return limit == nil or limit >= 4294967295 or stop.trains_count < limit
end

--- Gleise einer Seite in fester Reihenfolge (oben → unten).
local function sorted(t)
  local list = {}
  for y in pairs(t) do list[#list + 1] = y end
  table.sort(list)
  return list
end

--- Nächste Aufgabe: Gleis mit Wagen auf der einen Seite, freies Gleis auf der anderen. Die Richtung
--- bleibt, bis dort nichts mehr geht (erst alle nach rechts, dann alle zurück) – sonst pendelten immer
--- dieselben Wagen.
local function pick(yard)
  yard.dir = yard.dir or "west"
  for _ = 1, 2 do
    local from_side = yard.dir
    local to_side = from_side == "west" and "east" or "west"
    for _, y in ipairs(sorted(yard[from_side])) do
      local from = yard[from_side][y]
      if #wagons_on(yard, from_side, y) > 0 and free(from.access) then
        for _, y2 in ipairs(sorted(yard[to_side])) do
          local dest = yard[to_side][y2]
          local stop = dest.bay or dest.access
          if #wagons_on(yard, to_side, y2) == 0 and stop and free(stop) then
            return { from = from_side, from_y = y, to = to_side, to_y = y2 }
          end
        end
      end
    end
    yard.dir = to_side -- in dieser Richtung nichts mehr zu tun: umdrehen
  end
  return nil
end

local function send(train, stops)
  local yard = storage.yard
  local id, why = remote.call("utl", "send_job", train.id, MOD, stops)
  if not id then
    note("Rangieren: Auftrag abgelehnt (" .. tostring(why) .. "), neuer Versuch in 5 s")
    yard.phase = "idle"
    storage.waiting = storage.waiting or {}
    storage.waiting[train.id] = game.tick + 300
    return
  end
  storage.jobs = storage.jobs or {}
  storage.jobs[id] = true
  yard.job = id
end

local function take_over(train)
  local yard = storage.yard
  if yard.job then remote.call("utl", "cancel_job", yard.job) end
  yard.job = nil
  remote.call("utl", "hold_train", train.id, MOD)
  train.manual_mode = true
end

--- Rangierlok frei im Depot.
function Yard.idle(train)
  local yard = storage.yard
  if not yard or yard.phase ~= "idle" then return false end
  local task = pick(yard)
  if not task then
    -- nichts zu tun (alles belegt oder gesperrt): in 10 s noch einmal schauen
    storage.waiting = storage.waiting or {}
    storage.waiting[train.id] = game.tick + 600
    return true
  end
  yard.task, yard.loco = task, train.front_stock
  local access = yard[task.from][task.from_y].access
  note("Rangieren: Wagen holen von " .. (task.from == "west" and "Abstellgleis" or "Ladegleis") .. " (y " .. task.from_y
    .. ") nach " .. (task.to == "west" and "Abstellgleis" or "Ladegleis") .. " (y " .. task.to_y .. ")")
  yard.phase = "fetch"
  send(train, { { station = access.unit_number, wait = { { type = "time", ticks = 30 } } } })
  return true
end

function Yard.arrived(event)
  local yard = storage.yard
  if not (yard and event.job_id and event.job_id == yard.job) then return false end
  local task = yard.task
  if yard.phase == "fetch" and event.station == yard[task.from][task.from_y].access.unit_number then
    take_over(event.train)
    yard.phase = "couple"
    note("Rangieren: schiebe an die Wagen heran")
  elseif yard.phase == "deliver" then
    local dest = yard[task.to][task.to_y]
    if event.station == (dest.bay or dest.access).unit_number then
      take_over(event.train)
      yard.phase, yard.still = "push", 0
      note("Rangieren: schiebe die Wagen bis ans Gleisende")
    end
  end
  return true
end

--- Geschwindigkeit so setzen, dass der Zug Richtung x = `target_x` fährt.
local function crawl(train, target_x)
  local towards_front = math.abs(train.front_stock.position.x - target_x) < math.abs(train.back_stock.position.x - target_x)
  train.speed = towards_front and SPEED or -SPEED
  return towards_front and train.front_stock or train.back_stock
end

local function couple_step(yard)
  local train = yard.loco.train
  local wagons = wagons_on(yard, yard.task.from, yard.task.from_y)
  if not wagons[1] then return end
  -- nächster Wagen zur Lok
  local lx = yard.loco.position.x
  table.sort(wagons, function(a, b) return math.abs(a.position.x - lx) < math.abs(b.position.x - lx) end)
  local nearest_wagon = wagons[1]
  local leading = crawl(train, nearest_wagon.position.x)
  if math.abs(leading.position.x - nearest_wagon.position.x) > 7.2 then return end
  train.speed = 0
  local old = train.id
  remote.call("utl", "begin_train_change", { old })
  leading.connect_rolling_stock(defines.rail_direction.front)
  if nearest_wagon.train ~= yard.loco.train then leading.connect_rolling_stock(defines.rail_direction.back) end
  local joined = yard.loco.train
  remote.call("utl", "end_train_change", { old }, joined)
  if nearest_wagon.train ~= joined then return end -- noch nicht angekuppelt: weiter heranschieben
  note("Rangieren: " .. #joined.cargo_wagons .. " Wagen angekuppelt, fahre in den Wendestummel")
  local dest = yard[yard.task.to][yard.task.to_y]
  yard.phase = "deliver"
  send(joined, {
    { station = yard.turn.unit_number, wait = { { type = "time", ticks = 60 } } },
    { station = (dest.bay or dest.access).unit_number, wait = { { type = "time", ticks = 30 } } },
  })
end

local function uncouple(yard)
  local train = yard.loco.train
  local old = train.id
  remote.call("utl", "begin_train_change", { old })
  -- Grenze Lok ↔ Wagen suchen und dort trennen
  local carriages = train.carriages
  for i = 1, #carriages - 1 do
    local a, b = carriages[i], carriages[i + 1]
    if (a.type == "locomotive") ~= (b.type == "locomotive") then
      local loco = a.type == "locomotive" and a or b
      for _, dir in ipairs({ defines.rail_direction.front, defines.rail_direction.back }) do
        if loco.train == (a.type == "locomotive" and b or a).train then loco.disconnect_rolling_stock(dir) end
      end
      break
    end
  end
  local loco_train = yard.loco.train
  remote.call("utl", "end_train_change", { old }, loco_train)
  for _, w in ipairs(wagons_on(yard, yard.task.to, yard.task.to_y)) do
    if w.train ~= loco_train then remote.call("utl", "forget_train", w.train.id) end
  end
  remote.call("utl", "release_train", loco_train.id)
  loco_train.manual_mode = false -- zurück ins Rangierdepot (eigener Fahrplan)
  yard.phase = "idle"
  note("Rangieren: Wagen abgestellt, Lok fährt ins Depot")
end

local function push_step(yard)
  local train = yard.loco.train
  local far = yard.task.to == "east" and 1e6 or -1e6
  local before = yard.last_x
  local x = yard.loco.position.x
  yard.last_x = x
  if before and math.abs(x - before) < 0.02 then
    yard.still = (yard.still or 0) + 1
  else
    yard.still = 0
  end
  if yard.still >= 4 then
    train.speed = 0
    yard.last_x = nil
    uncouple(yard)
    return
  end
  crawl(train, far)
end

--- Alle 5 Ticks: heranschieben bzw. bis ans Gleisende schieben.
function Yard.tick()
  local yard = storage.yard
  if not (yard and yard.loco and yard.loco.valid) then return end
  if yard.phase == "couple" then couple_step(yard) elseif yard.phase == "push" then push_step(yard) end
end

return Yard
