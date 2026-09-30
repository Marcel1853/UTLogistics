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

--- Konstant-Kombinator mit Waren (grün) an die Haltestelle: so bietet sie an (Menge je Ware `count`,
--- Standard 2000).
local function supply(s, force, st, x, items, count)
  local c = s.create_entity({ name = "constant-combinator", position = { x + 3.5, LINE + 5.5 }, force = force })
  local section = c.get_or_create_control_behavior().get_section(1)
  for i, item in ipairs(items) do
    section.set_slot(i, { value = { type = "item", name = item, quality = "normal", comparator = "=" }, min = count or 2000 })
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
  -- R33: Zug bekommt mitten in der Lieferung eine neue ID (wie beim SE-Weltraumaufzug)
  LINE = 81
  rails(s, force, -85, 85)
  local depot3 = stop(s, force, "R33-Depot", 10, true)
  local prov3 = stop(s, force, "R33-Anbieter", 60, true)
  local req3 = stop(s, force, "R33-Abnehmer", -60, false)
  supply(s, force, prov3, 60, { "iron-plate" })
  local function cfg3(e, changes) changes.network = "R33"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg3(depot3, { mode = "depot" })
  cfg3(prov3, { mode = "station", provide = true, request = false })
  cfg3(req3, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req3.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  local r33_train, r33_wagon = train(s, force, 4, "R33-Depot")
  -- R34: zweiter Anbieter – A und B haben je 200 Eisen, der Abnehmer braucht 400. Umweg über B
  -- (Luftlinie): A → B 10, B → Abnehmer 110, direkt 100 → 20 %. Erst Grenze 10 % (kein Umweg,
  -- 200 allein liegt unter der Schwelle → keine Lieferung), nach 20 s Grenze 50 % (zwei Halte).
  LINE = 121
  rails(s, force, -85, 85)
  local depot4 = stop(s, force, "R34-Depot", 10, true)
  local prov_a = stop(s, force, "R34-A", 40, true)
  local prov_b = stop(s, force, "R34-B", 50, true)
  local req4 = stop(s, force, "R34-Abnehmer", -60, false)
  supply(s, force, prov_a, 40, { "iron-plate" }, 200)
  supply(s, force, prov_b, 50, { "iron-plate" }, 200)
  local function cfg4(e, changes) changes.network = "R34"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg4(depot4, { mode = "depot" })
  cfg4(prov_a, { mode = "station", provide = true, request = false, provide_threshold = 100 })
  cfg4(prov_b, { mode = "station", provide = true, request = false, provide_threshold = 100 })
  cfg4(req4, { mode = "station", provide = false, request = true, request_threshold = 300 })
  remote.call("utl", "set_request", req4.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  remote.call("utl", "set_map_config", "utl-multi-pickup", true)
  remote.call("utl", "set_map_config", "utl-multi-pickup-detour", 10)
  local r34_train, r34_wagon = train(s, force, 4, "R34-Depot")
  -- R35: Hänger-Erkennung – auf dem Weg zum Anbieter fehlt ein Gleis (kein Weg); nach 1 min Warnung
  LINE = 161
  rails(s, force, -85, 85)
  local depot5 = stop(s, force, "R35-Depot", 10, true)
  local prov5 = stop(s, force, "R35-Anbieter", 60, true)
  local req5 = stop(s, force, "R35-Abnehmer", -60, false)
  supply(s, force, prov5, 60, { "iron-plate" })
  local function cfg5(e, changes) changes.network = "R35"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg5(depot5, { mode = "depot" })
  cfg5(prov5, { mode = "station", provide = true, request = false })
  cfg5(req5, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req5.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  remote.call("utl", "set_map_config", "utl-stuck-minutes", 1)
  local r35_train = train(s, force, 4, "R35-Depot")
  LINE = 1
  check("R31/R32 strecken gebaut", r31_train ~= nil and r32_train ~= nil)
  return { start = game.tick, train = r31_train, wagon = r31_wagon, train2 = r32_train, wagon2 = r32_wagon,
    train3 = r33_train, wagon3 = r33_wagon, loco3 = r33_train and r33_train.front_stock,
    train4 = r34_train, wagon4 = r34_wagon, r34 = {},
    train5 = r35_train, surface = s, r35 = {},
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
  -- R33: Zug hat nach dem Umzug eine neue ID – immer den aktuellen Zug der Lok nehmen
  if r.loco3 and r.loco3.valid then r.train3 = r.loco3.train end
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    handle(r, d, r.train, r.wagon)
    handle(r, d, r.train2, r.wagon2)
    if r.train3 and r.train3.valid then handle(r, d, r.train3, r.wagon3) end
    if d.to == "R34-Abnehmer" and not r.r34.opened then r.r34.early = true end
    -- R35: Lieferzug unterwegs zum Anbieter → Gleis davor abreißen
    if d.to == "R35-Abnehmer" and d.state == "to_provider" and not r.r35.cut then
      r.r35.cut = game.tick
      r.r35.delivery = d.id
      local rail = r.surface.find_entities_filtered({ type = "straight-rail", position = { 41, 161 }, radius = 1.5 })[1]
      if rail then rail.destroy() end
    end
    -- R34: Laden je Halt nur den Anteil dieses Anbieters (erst A, dann B)
    if r.train4.valid and d.train_id == r.train4.id and d.state == "loading" then
      local leg = d.leg or 1
      if not r.r34[leg] then
        r.r34[leg] = true
        r.r34.second = r.r34.second or d.second
        r.wagon4.get_inventory(CARGO).insert({ name = "iron-plate", count = 200 })
      end
    elseif r.train4.valid and d.train_id == r.train4.id and d.state == "unloading" and not r.r34.done then
      r.r34.done = true
      r.r34.cargo = r.wagon4.get_inventory(CARGO).get_item_count("iron-plate")
      r.wagon4.get_inventory(CARGO).clear()
      remote.call("utl", "set_map_config", "utl-multi-pickup", false)
      remote.call("utl", "set_map_config", "utl-multi-pickup-detour", 50)
      check("R34 zweiter anbieter: ein zug, zwei ladehalte, volle menge",
        r.r34[1] and r.r34[2] and r.r34.second ~= nil and r.r34.cargo == 400 and d.manifest["item|iron-plate|normal"] == 400,
        serpent.line({ halte = { r.r34[1], r.r34[2] }, zweiter = r.r34.second, ladung = r.r34.cargo, liste = d.manifest }))
    end
    -- R33: beim Laden am Anbieter „Aufzug“ spielen: Umzug melden, abkoppeln, ankoppeln, fertig melden
    if r.train3 and r.train3.valid and d.train_id == r.train3.id and d.state == "loading" and not r.moved then
      local old_id = r.train3.id
      r.moved = { delivery = d.id, old = old_id }
      remote.call("utl", "train_transfer_started", old_id)
      -- wie SE: Fahrplan sichern und nach dem Neubau wiederherstellen
      local schedule = r.train3.get_schedule()
      local records, current = schedule.get_records(), schedule.current
      local loco = r.loco3
      loco.disconnect_rolling_stock(defines.rail_direction.back)
      loco.connect_rolling_stock(defines.rail_direction.back)
      r.train3 = loco.train
      local restored = r.train3.get_schedule()
      restored.set_records(records)
      restored.go_to_station(current)
      r.train3.manual_mode = false
      remote.call("utl", "train_transfer_finished", old_id, r.train3)
      r.moved.new = r.train3.id
    end
    if r.moved and d.id == r.moved.delivery then r.moved.seen = d.state .. " " .. d.train_id end
    if r.moved and d.id == r.moved.delivery and d.state == "unloading" and not r.moved.ok then
      r.moved.ok = true
      check("R33 neue zug-id mitten in der lieferung: lieferung läuft weiter",
        d.train_id == r.moved.new and r.moved.new ~= r.moved.old, "alt " .. r.moved.old .. ", neu " .. d.train_id)
    end
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
  -- R35: nach über 1 min ohne Weg muss „steckt fest“ gemeldet sein, die Lieferung läuft weiter
  if r.r35.cut and not r.r35.done and game.tick - r.r35.cut > 3600 + 900 then
    r.r35.done = true
    local alerted = false
    for _, alert in ipairs(remote.call("utl", "get_alerts")) do
      if alert.key == "stuck:" .. r.r35.delivery then alerted = true end
    end
    local running = false
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if d.id == r.r35.delivery then running = true end
    end
    remote.call("utl", "set_map_config", "utl-stuck-minutes", 5)
    check("R35 hänger-erkennung: warnung nach 1 min, lieferung läuft weiter", alerted and running,
      "warnung " .. tostring(alerted) .. ", lieferung " .. tostring(running) .. ", zug " .. tostring(r.train5.valid and r.train5.state))
  end
  -- R34: nach 20 s die Umweg-Grenze von 10 % auf 50 % heben
  if not r.r34.opened and game.tick - r.start > 1200 then
    r.r34.opened = true
    check("R34 umweg über der grenze: kein zweiter anbieter", not r.r34.early)
    remote.call("utl", "set_map_config", "utl-multi-pickup-detour", 50)
  end
  if (r.chained and r.storage and r.moved and r.moved.ok and r.r34.done and r.r35.done) or game.tick - r.start > 36000 then
    r.done = true
    if not r.r35.done then check("R35 hänger-erkennung: warnung nach 1 min, lieferung läuft weiter", false, serpent.line(r.r35)) end
    if not r.r34.done then check("R34 zweiter anbieter: ein zug, zwei ladehalte, volle menge", false, serpent.line(r.r34)) end
    if not (r.moved and r.moved.ok) then
      check("R33 neue zug-id mitten in der lieferung: lieferung läuft weiter", false, serpent.line(r.moved))
    end
    if not r.chained then check("R31 anschlussfahrt beachtet angebots-priorität", false, "keine anschlussfahrt gesehen") end
    if not r.storage then check("R32 lager bekommt zwei waren in einer fahrt", false, "keine lieferung ans lager") end
  end
  return r.done
end

return Rounds
