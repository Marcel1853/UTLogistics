-- Schiffstest (tools/shiptest.sh): UTL mit Cargo Ships. Wasserstreifen mit geradem Wasserweg, drei
-- UTL-Häfen in Fahrtrichtung Ost (Depot, Anbieter, Abnehmer), ein Frachtschiff; daneben ein Zugnetz im selben UTL-Netz
-- (Depot, Abnehmer, Zug). Laden und Entladen übernimmt der Test per Script.
-- Prüft: Häfen werden Stationen, das Schiff liefert (alle vier Zustände), Wagenfilter am
-- Frachtschiff, Auftrags-/Depot-Ausgabe am Hafen, Züge bekommen keine Hafen-Aufträge.
local results = {}
local function check(name, ok, info)
  results[#results + 1] = (ok and "PASS " or "FAIL ") .. name .. (info and (" -- " .. tostring(info)) or "")
end

local st = {}
local W = defines.wire_connector_id
local CARGO = defines.inventory.cargo_wagon

local function port(s, force, name, x, east)
  local e = s.create_entity({ name = "utl-port", position = { x, east and 3 or -1 }, direction = east and 4 or 12,
    force = force, raise_built = true })
  if e then e.backer_name = name end
  return e
end

local function build()
  local s = game.surfaces[1]
  local force = game.forces["player"]
  force.research_all_technologies() -- Ladesteuerung: Auftrags-/Depot-Ausgabe
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local area = { { -72, -12 }, { 72, 32 } }
  for _, e in pairs(s.find_entities_filtered({ area = area })) do
    if e.type ~= "character" then e.destroy() end
  end
  -- Land überall, Wasser in einem Streifen um y = 1
  local tiles = {}
  for x = -72, 71 do
    for y = -12, 31 do
      tiles[#tiles + 1] = { name = (y >= -1 and y <= 2) and "water" or "lab-dark-1", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  local ww = 0
  -- Schiffe haben nur hinten einen Motor und können nicht wenden: alles in Fahrtrichtung Ost
  for x = -65, 65, 2 do
    if s.create_entity({ name = "straight-waterway", position = { x, 1 }, direction = 4, force = force }) then ww = ww + 1 end
  end
  check("wasserwege gebaut", ww == 66, ww)
  st.depot = port(s, force, "Hafen-Depot", -25, true)
  st.provider = port(s, force, "Hafen-Anbieter", 5, true)
  st.requester = port(s, force, "Hafen-Abnehmer", 35, true)
  check("utl-häfen gebaut", st.depot and st.provider and st.requester,
    tostring(st.depot) .. " " .. tostring(st.provider) .. " " .. tostring(st.requester))
  if not (st.depot and st.provider and st.requester) then return end
  -- Anbieter: Konstant-Kombinator mit 2000 Eisen am Hafen (grün)
  local supply = s.create_entity({ name = "constant-combinator", position = { 9.5, 6.5 }, force = force })
  local section = supply.get_or_create_control_behavior().get_section(1)
  section.set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  supply.get_wire_connector(W.circuit_green, true).connect_to(st.provider.get_wire_connector(W.circuit_green, true))
  remote.call("utl", "configure_station", st.depot.unit_number, { mode = "depot" })
  remote.call("utl", "configure_station", st.provider.unit_number, { mode = "station", provide = true, request = false })
  remote.call("utl", "configure_station", st.requester.unit_number, { mode = "station", provide = false, request = true,
    request_threshold = 100 })
  -- Normaler Hafen mit UTL-Stations-Kombinator (Ausgang per Kabel an den Hafen)
  local vport = s.create_entity({ name = "port", position = { 55, 3 }, direction = 4, force = force })
  vport.backer_name = "Hafen-Vanilla"
  local comb = s.create_entity({ name = "utl-station-combinator", position = { 58.5, 6 }, direction = 4, force = force })
  comb.get_wire_connector(W.combinator_output_green, true).connect_to(vport.get_wire_connector(W.circuit_green, true))
  script.raise_script_built({ entity = comb })
  st.vport, st.comb = vport, comb
  -- Frachtschiff: Cargo Ships setzt den Motor beim Bau selbst dazu
  st.ship_body = s.create_entity({ name = "cargo_ship", position = { -40, 1 }, direction = 4, force = force, raise_built = true })
  check("frachtschiff gebaut", st.ship_body ~= nil)

  -- Zugnetz daneben (y = 21), gleiches UTL-Netz „default“: Depot und ein Abnehmer, der auch Eisen will
  for x = -41, 41, 2 do s.create_entity({ name = "straight-rail", position = { x, 21 }, direction = 4, force = force }) end
  local tdepot = s.create_entity({ name = "utl-train-stop", position = { -3, 23 }, direction = 4, force = force, raise_built = true })
  tdepot.backer_name = "Zug-Depot"
  local treq = s.create_entity({ name = "utl-train-stop", position = { -29, 19 }, direction = 12, force = force, raise_built = true })
  treq.backer_name = "Zug-Abnehmer"
  st.train_requester = treq
  remote.call("utl", "configure_station", tdepot.unit_number, { mode = "depot" })
  remote.call("utl", "configure_station", treq.unit_number, { mode = "station", provide = false, request = true,
    request_threshold = 100 })
  remote.call("utl", "set_request", treq.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  -- Zug-Anbieter (Eisen per Konstant-Kombinator) und eine Hafen-Tankstelle, die kein Zug erreicht
  local tprov = s.create_entity({ name = "utl-train-stop", position = { 29, 23 }, direction = 4, force = force, raise_built = true })
  tprov.backer_name = "Zug-Anbieter"
  local tsupply = s.create_entity({ name = "constant-combinator", position = { 33.5, 26.5 }, force = force })
  tsupply.get_or_create_control_behavior().get_section(1).set_slot(1,
    { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  tsupply.get_wire_connector(W.circuit_green, true).connect_to(tprov.get_wire_connector(W.circuit_green, true))
  remote.call("utl", "configure_station", tprov.unit_number, { mode = "station", provide = true, request = false })
  local fuelport = port(s, force, "Hafen-Tankstelle", 55, true)
  remote.call("utl", "configure_station", fuelport.unit_number, { mode = "fuel" })
  -- Zug Lok – Wagen – Lok, knapp an Treibstoff (30 von 150 Kohle = 20 %, unter „Tanken unter“, über
  -- dem Mindest-Treibstoff): darf fahren, weil er keine Tankstelle erreicht
  local l1 = s.create_entity({ name = "locomotive", position = { -8, 21 }, direction = 4, force = force })
  local wagon = s.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, 21 }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { wagon.position.x - 7, 21 }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 30 })
  l2.insert({ name = "coal", count = 30 })
  st.train, st.wagon = l1.train, wagon
  local sched = st.train.get_schedule()
  sched.add_record({ station = "Zug-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  sched.go_to_station(1)
  st.train.manual_mode = false
end

local function ship_train()
  local body = st.ship_body
  return body and body.valid and body.train or nil
end

local function output_near(stop, name)
  return stop.surface.find_entities_filtered({ name = name, position = stop.position, radius = 5 })[1]
end

--- Blaupause „Gleis ↔ Wasserweg“: hin und zurück tauschen
local function blueprint_test()
  local inv = game.create_inventory(1)
  inv.insert({ name = "blueprint" })
  local bp = inv[1]
  bp.set_blueprint_entities({
    { entity_number = 1, name = "straight-rail", position = { 1, 1 }, direction = 4 },
    { entity_number = 2, name = "half-diagonal-rail", position = { 5, 5 } },
    { entity_number = 3, name = "rail-signal", position = { 1.5, 2.5 } },
    { entity_number = 4, name = "rail-chain-signal", position = { 3.5, 2.5 } },
    { entity_number = 5, name = "train-stop", position = { 9, 3 }, direction = 4 },
    { entity_number = 6, name = "utl-train-stop", position = { 13, 3 }, direction = 4, tags = { utl = { mode = "depot" } } },
  })
  local n = remote.call("utl", "convert_blueprint_water", bp)
  local names = {}
  for _, ent in pairs(bp.get_blueprint_entities() or {}) do names[ent.entity_number] = ent.name end
  local tags = (bp.get_blueprint_entities() or {})[6]
  check("blaupause: gleis -> wasserweg", n == 6 and names[1] == "straight-waterway" and names[2] == "half-diagonal-waterway"
    and names[3] == "buoy" and names[4] == "chain_buoy" and names[5] == "port" and names[6] == "utl-port",
    tostring(n) .. " " .. serpent.line(names))
  check("blaupause: utl-einstellungen bleiben", tags and tags.tags and tags.tags.utl and tags.tags.utl.mode == "depot",
    serpent.line(tags and tags.tags))
  remote.call("utl", "convert_blueprint_water", bp)
  local back = bp.get_blueprint_entities() or {}
  check("blaupause: zurück zu gleis", back[1] and back[1].name == "straight-rail" and back[6] and back[6].name == "utl-train-stop",
    serpent.line({ back[1] and back[1].name, back[6] and back[6].name }))
  inv.destroy()
end

script.on_nth_tick(30, function(e)
  if e.tick == 30 then
    blueprint_test()
    build()
    return
  end
  if not st.depot then return end
  if e.tick == 120 then
    -- Schiff fertig gekoppelt? Treibstoff rein, Fahrplan: nur das Depot
    local train = ship_train()
    check("schiff hat motor und rumpf", train ~= nil and #train.carriages == 2,
      train and #train.carriages or "kein zug")
    if train then
      -- voll (5 Plätze): knapp führe es zuerst zur Hafen-Tankstelle am Ende der Sackgasse
      for _, loco in pairs(train.locomotives.front_movers) do loco.insert({ name = "coal", count = 250 }) end
      for _, loco in pairs(train.locomotives.back_movers) do loco.insert({ name = "coal", count = 250 }) end
      local sched = train.get_schedule()
      sched.add_record({ station = "Hafen-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
      sched.go_to_station(1)
      train.manual_mode = false
    end
    local vinfo = remote.call("utl", "get_station", st.comb.unit_number) --[[@as table?]]
    check("normaler hafen + stations-kombinator", vinfo ~= nil and vinfo.stop_name == "Hafen-Vanilla",
      vinfo and vinfo.stop_name)
    for _, p in ipairs({ st.depot, st.provider, st.requester }) do
      local info = remote.call("utl", "get_station", p.unit_number) --[[@as table?]]
      check("hafen ist utl-station: " .. p.backer_name, info ~= nil and info.kind == "stop", info and info.kind)
    end
    return
  end
  if e.tick == 600 then
    -- erst jetzt Bedarf am Hafen-Abnehmer: Schiff und Zug stehen dann in ihren Depots
    remote.call("utl", "set_request", st.requester.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
    check("depot-ausgabe am hafen-depot", output_near(st.depot, "utl-depot-output") ~= nil)
  end
  if e.tick % 1800 == 0 and not st.done then
    local ship = ship_train()
    local function desc(t) return t and (t.state .. "@" .. (t.station and t.station.backer_name or "-")) or "nil" end
    local p = remote.call("utl", "get_station", st.provider.unit_number) --[[@as table?]]
    local r = remote.call("utl", "get_station", st.requester.unit_number) --[[@as table?]]
    log(("[SHIPDBG] tick %d schiff %s zug %s frei %d anbieter %s abnehmer %s"):format(e.tick, desc(ship),
      desc(st.train), remote.call("utl", "idle_train_count"), serpent.line(p and p.provide), serpent.line(r and r.request)))
  end
  st.seen = st.seen or {}
  local ship = ship_train()
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    local is_ship = ship ~= nil and d.train_id == ship.id
    local to_port = d.requester == st.requester.unit_number
    if is_ship ~= to_port and not st.mixed then
      st.mixed = true
      check("schiff und zug nicht vermischt", false, serpent.line({ d.from, d.to, is_ship }))
    end
    if is_ship then
      if not st.seen[d.state] then st.seen[d.state] = e.tick end
      local body = st.ship_body
      local inv = body.valid and body.get_inventory(CARGO)
      if d.state == "loading" and inv and not st.loaded then
        st.loaded = true
        check("wagenfilter am frachtschiff", inv.is_filtered(), inv.is_filtered())
        local out = output_near(st.provider, "utl-station-output")
        check("auftrags-ausgabe am hafen-anbieter", out ~= nil)
        inv.insert({ name = "iron-plate", count = 400 })
      elseif d.state == "unloading" and inv and not st.unloaded then
        st.unloaded = true
        inv.clear()
        remote.call("utl", "set_request", st.requester.unit_number, 1, nil)
      end
    end
  end
  -- Zug: laden/entladen per Script; eine Lieferung trotz knappem Treibstoff genügt
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if st.train and st.train.valid and d.train_id == st.train.id and st.wagon.valid then
      local inv = st.wagon.get_inventory(CARGO)
      if d.state == "loading" and not st.t_loaded then
        st.t_loaded = true
        inv.insert({ name = "iron-plate", count = 400 })
      elseif d.state == "unloading" and not st.t_unloaded then
        st.t_unloaded = true
        inv.clear()
        check("knapper zug fährt trotz unerreichbarer hafen-tankstelle", true, e.tick)
        -- jetzt fast leer (1 Kohle je Lok, unter 10 %): danach darf er keinen Auftrag mehr fahren
        for _, list in pairs({ st.train.locomotives.front_movers, st.train.locomotives.back_movers }) do
          for _, loco in pairs(list) do
            local fuel = loco.get_fuel_inventory()
            fuel.clear()
            fuel.insert({ name = "coal", count = 1 })
          end
        end
        st.t_emptied = e.tick
      end
    end
  end
  if st.unloaded and not st.done then
    st.done = true
    check("schiff liefert: alle vier zustände",
      st.seen.to_provider and st.seen.loading and st.seen.to_requester and st.seen.unloading, serpent.line(st.seen))
  end
  if e.tick >= 36000 and not st.finished then
    st.finished = true
    if not st.done then check("schiff liefert: alle vier zustände", false, serpent.line(st.seen)) end
    if not st.t_unloaded then check("knapper zug fährt trotz unerreichbarer hafen-tankstelle", false,
      "geladen " .. tostring(st.t_loaded)) end
    -- fast leer: keine weitere Lieferung, Warnung „Treibstoff fehlt“
    local busy = false
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if st.train.valid and d.train_id == st.train.id then busy = true end
    end
    local warned = false
    for _, a in ipairs(remote.call("utl", "get_alerts")) do
      if string.find(a.key, "no-fuel:", 1, true) then warned = true end
    end
    check("fast leerer zug bleibt im depot und warnt", st.t_emptied ~= nil and not busy and warned,
      "leer seit " .. tostring(st.t_emptied) .. ", auftrag " .. tostring(busy) .. ", warnung " .. tostring(warned))
    if not st.mixed then check("schiff und zug nicht vermischt", true) end
    local alerts = remote.call("utl", "get_alerts")
    local list = {}
    for _, a in ipairs(alerts) do list[#list + 1] = a.key .. "×" .. a.count end
    check("warnungen (nur zur info)", true, table.concat(list, ", "))
    for _, r in ipairs(results) do log("[SHIPTEST] " .. r) end
  end
end)
