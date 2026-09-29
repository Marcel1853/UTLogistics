-- Selbsttest, Runden R31 und R32 (29.09.2026) auf eigener Oberfläche mit gerader Strecke:
--   R31 Anschlussfahrt beachtet die Angebots-Priorität: Nach dem Entladen fährt der Zug direkt zum
--       fernen Anbieter mit Priorität 5, nicht zum nahen mit Priorität 0.
--   R32 Lager bekommt zwei Waren in einer Fahrt (Eisen und Kupfer, beide unter Mindest).
-- Laden und Entladen übernimmt der Test per Script.
local Rounds = {}

local W = defines.wire_connector_id
local CARGO = defines.inventory.cargo_wagon
local LINE = 1

local function stop(s, force, name, x, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, LINE + (east and 2 or -2) }, direction = east and 4 or 12,
    force = force, raise_built = true })
  e.backer_name = name
  return e
end

--- Konstant-Kombinator mit Waren (grün) an die Haltestelle: so bietet sie an.
local function supply(s, force, st, x, items)
  local c = s.create_entity({ name = "constant-combinator", position = { x + 3.5, LINE + 5.5 }, force = force })
  local section = c.get_or_create_control_behavior().get_section(1)
  for i, item in ipairs(items) do
    section.set_slot(i, { value = { type = "item", name = item, quality = "normal", comparator = "=" }, min = 2000 })
  end
  c.get_wire_connector(W.circuit_green, true).connect_to(st.get_wire_connector(W.circuit_green, true))
end

--- Zug Lok – Wagen – Lok (fährt in beide Richtungen), Fahrplan nur das Depot.
local function train(s, force, x, depot)
  local l1 = s.create_entity({ name = "locomotive", position = { x, LINE }, direction = 4, force = force })
  local wagon = s.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, LINE }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { wagon.position.x - 7, LINE }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = depot, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return l1.train, wagon
end

local function rails(s, force, from, to)
  for x = from, to, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
end

function Rounds.build(check)
  local s = game.create_surface("utl-selftest-r31")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.technologies["utl-storage"].researched = true
  remote.call("utl", "set_map_config", "utl-chaining", true) -- R29 hatte sie abgeschaltet
  -- R31: Netz „R31“ – Abnehmer links (-60), naher Anbieter A (-20, Prio 0), ferner B (+60, Prio 5)
  rails(s, force, -85, 85)
  local depot = stop(s, force, "R31-Depot", 10, true)
  local req = stop(s, force, "R31-Abnehmer", -60, false)
  local near = stop(s, force, "R31-A-nah", -20, true)
  local far = stop(s, force, "R31-B-fern", 60, true)
  supply(s, force, near, -20, { "iron-plate" })
  supply(s, force, far, 60, { "iron-plate" })
  local function cfg(e, changes) changes.network = "R31"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg(depot, { mode = "depot" })
  cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
  cfg(near, { mode = "station", provide = true, request = false, provide_priority = 0 })
  cfg(far, { mode = "station", provide = true, request = false, provide_priority = 5 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  local r31_train, r31_wagon = train(s, force, 4, "R31-Depot") -- vor dem Depot-Haltepunkt (x = 10)
  -- R32: eigene Strecke (y = 41 → LINE-Versatz über eigene Oberfläche nicht nötig: eigenes Netz)
  LINE = 41
  rails(s, force, -85, 85)
  local depot2 = stop(s, force, "R32-Depot", 10, true)
  local prov = stop(s, force, "R32-Anbieter", 60, true)
  local lager = stop(s, force, "R32-Lager", -60, false)
  supply(s, force, prov, 60, { "iron-plate", "copper-plate" })
  local function cfg2(e, changes) changes.network = "R32"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg2(depot2, { mode = "depot" })
  cfg2(prov, { mode = "station", provide = true, request = false })
  cfg2(lager, { mode = "storage", storage = { accept_leftover = false, limits = {
    { signal = { type = "item", name = "iron-plate" }, min = 200, max = 600 },
    { signal = { type = "item", name = "copper-plate" }, min = 200, max = 600 } } } })
  local r32_train, r32_wagon = train(s, force, 4, "R32-Depot")
  LINE = 1
  check("R31/R32 strecken gebaut", r31_train ~= nil and r32_train ~= nil)
  return { start = game.tick, train = r31_train, wagon = r31_wagon, train2 = r32_train, wagon2 = r32_wagon,
    far = far.backer_name, near = near.backer_name, chained = nil, loaded = {}, unloaded = {} }
end

--- Laden/Entladen per Script für die beiden Testzüge.
local function handle(r, d, train, wagon)
  if not (train.valid and wagon.valid and d.train_id == train.id) then return end
  local inv = wagon.get_inventory(CARGO)
  if d.state == "loading" and not r.loaded[d.id] then
    r.loaded[d.id] = true
    for key, amount in pairs(d.manifest) do
      local name = key:match("^item|([^|]+)|")
      if name then inv.insert({ name = name, count = amount }) end
    end
  elseif d.state == "unloading" and not r.unloaded[d.id] then
    r.unloaded[d.id] = true
    inv.clear()
  end
end

--- Liefert true, wenn beide Runden fertig sind.
function Rounds.watch(r, check)
  if not r or r.done then return true end
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    handle(r, d, r.train, r.wagon)
    handle(r, d, r.train2, r.wagon2)
    -- R31: erste Anschlussfahrt des Testzugs
    if r.train.valid and d.train_id == r.train.id and d.chained and not r.chained then
      r.chained = d.from
      check("R31 anschlussfahrt beachtet angebots-priorität", d.from == r.far, "von " .. tostring(d.from))
    end
    -- R32: erste Lieferung ans Lager
    if d.to == "R32-Lager" and not r.storage then
      r.storage = true
      check("R32 lager bekommt zwei waren in einer fahrt",
        d.manifest["item|iron-plate|normal"] ~= nil and d.manifest["item|copper-plate|normal"] ~= nil, serpent.line(d.manifest))
    end
  end
  if (r.chained and r.storage) or game.tick - r.start > 36000 then
    r.done = true
    if not r.chained then check("R31 anschlussfahrt beachtet angebots-priorität", false, "keine anschlussfahrt gesehen") end
    if not r.storage then check("R32 lager bekommt zwei waren in einer fahrt", false, "keine lieferung ans lager") end
  end
  return r.done
end

return Rounds
