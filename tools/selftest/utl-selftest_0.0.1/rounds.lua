-- Selbsttest, Runden R31 und R32 (29.09.2026) auf eigener Oberfläche mit gerader Strecke:
--   R31 Anschlussfahrt beachtet die Angebots-Priorität: Nach dem Entladen fährt der Zug direkt zum
--       fernen Anbieter mit Priorität 5, nicht zum nahen mit Priorität 0.
--   R32 Lager bekommt zwei Waren in einer Fahrt (Eisen und Kupfer, beide unter Mindest).
-- Laden und Entladen übernimmt der Test per Script.
local Rounds = {}
local Param = require("rounds-param") -- R40 (require nur beim Laden erlaubt)
local NoRail = require("rounds-norail") -- R42

--- R36: UTL-Ereignisse mitzählen (Anmeldung in on_init und on_load, siehe control.lua).
function Rounds.listen()
  local ids = remote.call("utl", "get_event_ids")
  for name, id in pairs(ids) do
    script.on_event(id, function(event) ---@param event table
      storage.r36 = storage.r36 or {}
      local key = name .. (event.reason and ("-" .. event.reason) or "")
      storage.r36[key] = (storage.r36[key] or 0) + 1
      if name == "on_delivery_created" and not (event.train and event.train.valid) then storage.r36.bad = true end
    end)
  end
end

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
  -- R37: Mindestladung 50 % – 400 Eisen (10 % des Wagens) lösen keine Fahrt aus, 3000 schon
  LINE = 201
  rails(s, force, -85, 85)
  local depot7 = stop(s, force, "R37-Depot", 10, true)
  local prov7 = stop(s, force, "R37-Anbieter", 60, true)
  local req7 = stop(s, force, "R37-Abnehmer", -60, false)
  supply(s, force, prov7, 60, { "iron-plate" }, 5000)
  local function cfg7(e, changes) changes.network = "R37"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg7(depot7, { mode = "depot" })
  cfg7(prov7, { mode = "station", provide = true, request = false })
  cfg7(req7, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req7.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  remote.call("utl", "set_map_config", "utl-min-load-percent", 50)
  train(s, force, 4, "R37-Depot")
  -- R38: aktiver Anbieter – (a) Lager über dem Mindest füllt sich nur aus dem aktiven Anbieter (der
  -- normale liegt näher), (b) ohne Abnehmer geht die Ware des aktiven Anbieters ins Cleanup
  LINE = 241
  rails(s, force, -85, 85)
  local depot8 = stop(s, force, "R38-Depot", 10, true)
  local normal8 = stop(s, force, "R38-Normal", 30, true)
  local active8 = stop(s, force, "R38-Aktiv", 60, true)
  local lager8 = stop(s, force, "R38-Lager", -60, false)
  supply(s, force, normal8, 30, { "iron-plate" })
  supply(s, force, active8, 60, { "iron-plate" })
  supply(s, force, lager8, -60, { "iron-plate" }, 500) -- Bestand 500: über Mindest 100, unter Höchst 1500
  local function cfg8(e, changes) changes.network = "R38"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg8(depot8, { mode = "depot" })
  cfg8(normal8, { mode = "station", provide = true, request = false })
  cfg8(active8, { mode = "station", provide = true, request = false, active_provider = true })
  cfg8(lager8, { mode = "storage", storage = { accept_leftover = false, limits = {
    { signal = { type = "item", name = "iron-plate" }, min = 100, max = 1500 } } } })
  train(s, force, 4, "R38-Depot")
  LINE = 281
  rails(s, force, -85, 85)
  local depot9 = stop(s, force, "R38b-Depot", 10, true)
  local active9 = stop(s, force, "R38b-Aktiv", 60, true)
  local cleanup9 = stop(s, force, "R38b-Cleanup", -60, false)
  supply(s, force, active9, 60, { "copper-plate" })
  local function cfg9(e, changes) changes.network = "R38b"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg9(depot9, { mode = "depot" })
  cfg9(active9, { mode = "station", provide = true, request = false, active_provider = true })
  cfg9(cleanup9, { mode = "cleanup" })
  train(s, force, 4, "R38b-Depot")
  -- R39: Tankstelle mit „Treibstoff anfordern“ bestellt Kohle wie ein Abnehmer
  LINE = 321
  rails(s, force, -85, 85)
  local depot10 = stop(s, force, "R39-Depot", 10, true)
  local prov10 = stop(s, force, "R39-Anbieter", 60, true)
  local fuel10 = stop(s, force, "R39-Tankstelle", -60, false)
  supply(s, force, prov10, 60, { "coal" }, 5000)
  local function cfg10(e, changes) changes.network = "R39"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg10(depot10, { mode = "depot" })
  cfg10(prov10, { mode = "station", provide = true, request = false })
  cfg10(fuel10, { mode = "fuel", fuel_request = true })
  remote.call("utl", "set_request", fuel10.unit_number, 1, { type = "item", name = "coal" }, 2000)
  train(s, force, 4, "R39-Depot")
  LINE = 1
  Param.run(check) -- R40: Blaupausen-Parameter (sofort, eigene Oberfläche)
  check("R31/R32 strecken gebaut", r31_train ~= nil and r32_train ~= nil)
  return { start = game.tick, train = r31_train, wagon = r31_wagon, train2 = r32_train, wagon2 = r32_wagon,
    train3 = r33_train, wagon3 = r33_wagon, loco3 = r33_train and r33_train.front_stock,
    train4 = r34_train, wagon4 = r34_wagon, r34 = {},
    train5 = r35_train, surface = s, r35 = {}, r37 = { req = req7.unit_number }, r38 = {},
    r42 = NoRail.build(check), -- R42: Haltestelle ohne Gleis (eigene Oberfläche)
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
    if d.to == "R37-Abnehmer" then
      if not r.r37.raised then r.r37.early = true elseif not r.r37.done then
        r.r37.done = true
        remote.call("utl", "set_map_config", "utl-min-load-percent", 0)
        check("R37 mindestladung: 400 warten, 3000 fahren", not r.r37.early, serpent.line(d.manifest))
      end
    end
    if d.to == "R38-Lager" and not r.r38.fill then
      r.r38.fill = true
      check("R38 aktiver anbieter füllt lager über dem mindest", d.from == "R38-Aktiv"
        and (d.manifest["item|iron-plate|normal"] or 0) == 1000, d.from .. " " .. serpent.line(d.manifest))
    end
    if d.to == "R39-Tankstelle" and not r.r39 then
      r.r39 = true
      check("R39 tankstelle fordert treibstoff an", d.from == "R39-Anbieter"
        and (d.manifest["item|coal|normal"] or 0) == 2000, d.from .. " " .. serpent.line(d.manifest))
    end
    if d.to == "R38b-Cleanup" and not r.r38.cleanup then
      r.r38.cleanup = true
      check("R38 aktiver anbieter leert ins cleanup", d.from == "R38b-Aktiv", d.from .. " " .. serpent.line(d.manifest))
    end
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
    -- R36: neue Schnittstelle an der hängenden R35-Lieferung
    local id = r.r35.delivery
    local d = remote.call("utl", "get_delivery", id) --[[@as table?]]
    check("R36 get_delivery", d ~= nil and d.id == id and d.to == "R35-Abnehmer", serpent.line(d and { d.id, d.to }))
    local t = d and remote.call("utl", "get_train", d.train_id) --[[@as table?]]
    check("R36 get_train", t ~= nil and t.delivery == id and t.depot == "R35-Depot", serpent.line(t))
    local st = remote.call("utl", "get_stations", { network = "R35", role = "requester" })
    check("R36 get_stations (netz + rolle)", #st == 1 and st[1].stop_name == "R35-Abnehmer", #st)
    local nets = remote.call("utl", "get_networks", r.surface.index)
    local has = false
    for _, n in ipairs(nets) do has = has or n == "R35" end
    check("R36 get_networks", has, table.concat(nets, ","))
    check("R36 get_idle_trains (filter)", #remote.call("utl", "get_idle_trains", { network = "gibt-es-nicht" }) == 0)
    check("R36 cancel_delivery", remote.call("utl", "cancel_delivery", id) == true
      and remote.call("utl", "get_delivery", id) == nil)
    local ev = storage.r36 or {}
    check("R36 ereignisse", (ev.on_delivery_created or 0) > 0 and (ev.on_delivery_state_changed or 0) > 0
      and (ev.on_delivery_completed or 0) > 0 and (ev["on_delivery_canceled-remote"] or 0) == 1 and not ev.bad,
      serpent.line(ev))
  end
  -- R37: nach 30 s den Bedarf auf 3000 heben
  if not r.r37.raised and game.tick - r.start > 1800 then
    r.r37.raised = true
    remote.call("utl", "set_request", r.r37.req, 1, { type = "item", name = "iron-plate" }, 3000)
  end
  -- R34: nach 20 s die Umweg-Grenze von 10 % auf 50 % heben
  if not r.r34.opened and game.tick - r.start > 1200 then
    r.r34.opened = true
    check("R34 umweg über der grenze: kein zweiter anbieter", not r.r34.early)
    remote.call("utl", "set_map_config", "utl-multi-pickup-detour", 50)
  end
  local r42_done = NoRail.watch(r.r42, check)
  if (r.chained and r.storage and r.moved and r.moved.ok and r.r34.done and r.r35.done and r.r37.done
      and r.r38.fill and r.r38.cleanup and r.r39 and r42_done) or game.tick - r.start > 36000 then
    r.done = true
    if not r.r39 then check("R39 tankstelle fordert treibstoff an", false, "keine lieferung") end
    if not r.r38.fill then check("R38 aktiver anbieter füllt lager über dem mindest", false, "keine lieferung") end
    if not r.r38.cleanup then check("R38 aktiver anbieter leert ins cleanup", false, "keine lieferung") end
    if not r.r37.done then check("R37 mindestladung: 400 warten, 3000 fahren", false, serpent.line(r.r37)) end
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
