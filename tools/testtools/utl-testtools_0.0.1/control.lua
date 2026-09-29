-- Werkzeug-Mod für den großen grafischen Test (tools/testtools.sh, nur mit Grafik und Spieler).
-- Fährt in den Szenarien „UTL-Beispiele“ und „UTL-Schiffe“ alles aus 0.0.9 ab: prüft Werte per
-- Script (Zeilen „[TT] PASS/FAIL …“ im Log) und nimmt Screenshots auf
-- (script-output/utl-tt/<szenario>-NN-name.png). Klicks (Sortieren, Anheften) kann ein Script nicht
-- auslösen – die prüft Marcel selbst.
local R = { 1920, 1080 }
local FAST = 8          -- Spieltempo beim Warten
local results = {}
local steps, index, next_tick, prefix = nil, 0, nil, "x"
local watched = { incoming = false }

local function player() return game.get_player(1) end

local function check(name, ok, info)
  local line = (ok and "PASS " or "FAIL ") .. name .. (info ~= nil and (" -- " .. tostring(info)) or "")
  results[#results + 1] = line
  log("[TT] " .. line)
end

local function shot(name, extra)
  local p = player()
  local spec = { player = p, by_player = p, path = ("utl-tt/%s-%02d-%s.png"):format(prefix, index, name),
    resolution = R, show_gui = true, show_entity_info = true, anti_alias = true, quality = 85, zoom = 1 }
  for k, v in pairs(extra or {}) do spec[k] = v end
  game.take_screenshot(spec)
  log("[TT] bild " .. spec.path)
end

local function close() remote.call("utl", "close_windows", 1) end

--- Signale am Ausgang (Auftrags-/Depot-Ausgabe) neben einer Haltestelle: { [Name] = Wert }
local function output_of(stop, name)
  local out = stop.surface.find_entities_filtered({ name = name, position = stop.position, radius = 5 })[1]
  local values = {}
  local section = out and out.get_control_behavior().get_section(1)
  for _, filter in pairs(section and section.filters or {}) do
    if filter.value then values[filter.value.name] = filter.min end
  end
  return values, out
end

local function stop_named(surface, name)
  for _, e in pairs(surface.find_entities_filtered({ type = "train-stop" })) do
    if e.backer_name == name then return e end
  end
  return nil
end

--- Zug, der gerade an einer Haltestelle dieses Namens wartet
local function train_at(surface, name)
  for _, t in pairs(game.train_manager.get_trains({ surface = surface })) do
    if t.station and t.station.backer_name == name and t.state == defines.train_state.wait_station then return t end
  end
  return nil
end

local function wait(seconds) return { ticks = seconds * 60, fn = function() game.speed = FAST end } end
local function step(fn) return { ticks = 90, fn = function() game.speed = 1; fn() end } end

-- Gemeinsam: Rezept-Hinweis, Manager-Reiter, Einstellungen
local function common(list, surface)
  list[#list + 1] = step(function() close(); remote.call("utl", "show_recipe_notice", 1) end)
  list[#list + 1] = step(function()
    check("rezept-hinweis offen", player().gui.screen["utl_recipe_notice"] ~= nil)
    shot("rezept-hinweis")
  end)
  list[#list + 1] = step(function()
    close()
    check("rezept-hinweis schließt mit close_windows", player().gui.screen["utl_recipe_notice"] == nil)
    remote.call("utl", "open_manager", 1, "statistics")
  end)
  list[#list + 1] = step(function()
    local stats = remote.call("utl", "get_statistics") --[[@as table]]
    local n = 0
    for _ in pairs(stats.stations or {}) do n = n + 1 end
    check("statistik je station hat einträge", n > 0, n)
    shot("manager-statistik")
  end)
  list[#list + 1] = step(function() close(); remote.call("utl", "open_manager", 1, "stations") end)
  list[#list + 1] = step(function() shot("manager-stationen") end)
  list[#list + 1] = step(function() close(); remote.call("utl", "open_manager", 1, "settings") end)
  list[#list + 1] = step(function()
    check("einstellung mindest-treibstoff vorhanden", settings.global["utl-fuel-minimum"] ~= nil,
      settings.global["utl-fuel-minimum"] and settings.global["utl-fuel-minimum"].value)
    shot("manager-einstellungen")
  end)
end

--- Depot-Ausgabe und Mindest-Treibstoff an einem Depot mit wartendem Zug
--- `alert` = true: keine Tankstelle erreichbar → Zug bleibt, Warnung; false: er fährt tanken.
--- Warnfall (Schiffe-Szenario, Zugstrecke): Der Zug fährt durch „direkt der nächste Auftrag“ nie
--- ins Depot. Deshalb zuerst fast leer machen (12 Kohle = 8 %, reicht noch für die Heimfahrt) –
--- dann nimmt er keine Anschlussfahrt mehr, fährt heim und bleibt dort mit Warnung.
local function no_fuel_checks(list, surface, depot_name)
  local st = {}
  list[#list + 1] = step(function()
    close()
    local loco = surface.find_entities_filtered({ name = "locomotive" })[1]
    st.train = loco and loco.train
    check("zug der zugstrecke gefunden", st.train ~= nil)
    if not st.train then return end
    for _, list2 in pairs({ st.train.locomotives.front_movers, st.train.locomotives.back_movers }) do
      for _, l in pairs(list2) do
        local inv = l.get_fuel_inventory()
        if inv then
          inv.clear()
          inv.insert({ name = "coal", count = 12 })
        end
      end
    end
  end)
  list[#list + 1] = { ticks = 60, fn = function() game.speed = FAST end,
    until_ok = function() return train_at(surface, depot_name) ~= nil end, timeout = 10800 }
  list[#list + 1] = wait(15)
  list[#list + 1] = step(function()
    local train = train_at(surface, depot_name)
    check("fast leerer zug fährt heim ins depot", train ~= nil)
    if not train then return end
    local busy = false
    for _, d in pairs(remote.call("utl", "get_deliveries")) do if d.train_id == train.id then busy = true end end
    check("fast leerer zug bekommt keinen auftrag", not busy)
    local warned = false
    for _, a in ipairs(remote.call("utl", "get_alerts")) do
      if string.find(a.key, "no-fuel:" .. train.id, 1, true) then warned = true end
    end
    check("fast leerer zug: warnung „treibstoff fehlt“", warned)
    local values = output_of(train.station, "utl-depot-output")
    check("depot-ausgabe meldet „ohne treibstoff“", values["utl-trains-no-fuel"] == 1, serpent.line(values))
    shot("warnung-treibstoff", { position = train.station.position, zoom = 1.2 })
  end)
end

local function depot_checks(list, surface, depot_name, alert)
  local st = {}
  -- erst warten, bis ein Zug im Depot steht (höchstens 2 Minuten Spielzeit)
  list[#list + 1] = { ticks = 60, fn = function() game.speed = FAST end,
    until_ok = function() return train_at(surface, depot_name) ~= nil end, timeout = 7200 }
  list[#list + 1] = step(function()
    close()
    st.train = train_at(surface, depot_name)
    check("zug wartet im depot " .. depot_name, st.train ~= nil)
    if not st.train then return end
    local values, out = output_of(st.train.station, "utl-depot-output")
    check("depot-ausgabe (grün) vorhanden", out ~= nil)
    check("depot-ausgabe zeigt den zug", values["utl-train-id"] == st.train.id, serpent.line(values))
    st.stop = st.train.station
    shot("depot-ausgabe", { position = st.stop.position, zoom = 1.5, show_gui = false })
  end)
  list[#list + 1] = step(function()
    if not st.stop then return end
    local unit = (remote.call("utl", "get_station", st.stop.unit_number) and st.stop.unit_number)
    if unit then remote.call("utl", "open_station", 1, unit, 2) end
  end)
  list[#list + 1] = step(function() if st.stop then shot("depot-werte-reiter") end end)
  -- Mindest-Treibstoff: Zug fast leer machen → bleibt stehen, Warnung
  list[#list + 1] = step(function()
    close()
    if not (st.train and st.train.valid) then return end
    st.fuel = {}
    for _, list2 in pairs({ st.train.locomotives.front_movers, st.train.locomotives.back_movers }) do
      for _, loco in pairs(list2) do
        local inv = loco.get_fuel_inventory()
        if inv then
          st.fuel[#st.fuel + 1] = { loco = loco, contents = inv.get_contents() }
          inv.clear()
          inv.insert({ name = "coal", count = 1 })
        end
      end
    end
  end)
  list[#list + 1] = wait(20)
  list[#list + 1] = step(function()
    if not (st.train and st.train.valid) then return end
    local busy = false
    for _, d in pairs(remote.call("utl", "get_deliveries")) do if d.train_id == st.train.id then busy = true end end
    check("fast leerer zug bekommt keinen auftrag", not busy)
    if alert then
      local warned = false
      for _, a in ipairs(remote.call("utl", "get_alerts")) do
        if string.find(a.key, "no-fuel:" .. st.train.id, 1, true) then warned = true end
      end
      check("fast leerer zug: warnung „treibstoff fehlt“", warned)
      local values = st.stop and st.stop.valid and output_of(st.stop, "utl-depot-output") or {}
      check("depot-ausgabe meldet „ohne treibstoff“", values["utl-trains-no-fuel"] == 1, serpent.line(values))
    else
      local target = st.train.station and st.train.station.backer_name or (st.train.path_end_stop and st.train.path_end_stop.backer_name)
      local at_depot = st.train.station and st.train.station.backer_name == depot_name
      check("fast leerer zug fährt tanken statt zu warten", not at_depot, tostring(target))
    end
    shot("warnung-treibstoff")
    -- Treibstoff zurück
    for _, entry in ipairs(st.fuel or {}) do
      if entry.loco.valid then
        local inv = entry.loco.get_fuel_inventory()
        inv.clear()
        for _, item in pairs(entry.contents) do inv.insert({ name = item.name, count = item.count, quality = item.quality }) end
      end
    end
  end)
end

local function beispiele(surface)
  local list = { wait(90) }
  -- Netz-Kombinator am Startplatz (Modus Züge, Lampe) und Modus „Bedarf“
  list[#list + 1] = step(function()
    local readout = surface.find_entities_filtered({ name = "utl-network-combinator" })[1]
    check("netz-kombinator im szenario", readout ~= nil)
    if not readout then return end
    local r = remote.call("utl", "get_readout", readout.unit_number) --[[@as table]]
    check("netz-kombinator zählt züge", (r.values["virtual|utl-trains-total|normal"] or 0) >= 2, serpent.line(r.values))
    remote.call("utl", "open_readout", 1, readout.unit_number)
  end)
  list[#list + 1] = step(function() shot("netz-kombinator-zuege") end)
  list[#list + 1] = step(function()
    local readout = surface.find_entities_filtered({ name = "utl-network-combinator" })[1]
    remote.call("utl", "configure_readout", readout.unit_number, { mode = "demand" })
    close()
    remote.call("utl", "open_readout", 1, readout.unit_number)
  end)
  list[#list + 1] = step(function()
    local readout = surface.find_entities_filtered({ name = "utl-network-combinator" })[1]
    local r = remote.call("utl", "get_readout", readout.unit_number) --[[@as table]]
    check("netz-kombinator modus bedarf", r.config.mode == "demand", serpent.line(r.values))
    shot("netz-kombinator-bedarf") -- das Bild entsteht erst am Ende des Takts: danach nicht schließen
  end)
  list[#list + 1] = step(function()
    local readout = surface.find_entities_filtered({ name = "utl-network-combinator" })[1]
    remote.call("utl", "configure_readout", readout.unit_number, { mode = "trains" })
    close()
  end)
  -- „Züge unterwegs hierher“: laufend beobachtet (watch), hier ausgewertet
  list[#list + 1] = step(function() check("auftrags-ausgabe: züge unterwegs hierher", watched.incoming) end)
  depot_checks(list, surface, "Depot", false)
  common(list, surface)
  return list
end

local function schiffe(surface)
  local list = { wait(300) } -- Schiffe sind langsam
  list[#list + 1] = step(function()
    local bodies = surface.find_entities_filtered({ name = "cargo_ship" })
    check("zwei frachtschiffe mit rumpf", #bodies == 2, #bodies)
    local engines = surface.find_entities_filtered({ name = "cargo_ship_engine" })
    check("kein einzelner motor", #engines == #bodies, #engines .. " motoren")
    local stats = remote.call("utl", "get_statistics") --[[@as table]]
    local ship_deliveries = 0
    for _, body in pairs(bodies) do
      local entry = body.train and stats.trains[body.train.id]
      ship_deliveries = ship_deliveries + (entry and entry.deliveries or 0)
    end
    check("schiffe haben geliefert", ship_deliveries >= 1, ship_deliveries)
    -- Zugstrecke: Kohle in beiden Loks, keine geklaut
    local ok = true
    for _, loco in pairs(surface.find_entities_filtered({ name = "locomotive" })) do
      if loco.get_fuel_inventory().get_item_count("coal") < 50 then ok = false end
    end
    check("zugstrecke: loks behalten ihre kohle", ok)
    local port = stop_named(surface, "Mischlager")
    if port then shot("hafen-mischlager", { position = port.position, zoom = 0.6, show_gui = false }) end
  end)
  list[#list + 1] = step(function()
    local port = stop_named(surface, "Werkstatt")
    if port then remote.call("utl", "open_station", 1, port.unit_number) end
  end)
  list[#list + 1] = step(function()
    local p = player()
    check("utl-hafen: panel am hafenfenster", p.gui.relative["utl_station_window"] ~= nil or p.opened ~= nil)
    shot("hafen-panel")
  end)
  -- Blaupause Gleis ↔ Wasserweg in der Hand
  list[#list + 1] = step(function()
    close()
    local p = player()
    p.cursor_stack.set_stack({ name = "blueprint" })
    p.cursor_stack.set_blueprint_entities({
      { entity_number = 1, name = "straight-rail", position = { 1, 1 }, direction = 4 },
      { entity_number = 2, name = "rail-signal", position = { 1.5, 2.5 } },
      { entity_number = 3, name = "utl-train-stop", position = { 5, 3 }, direction = 4 },
    })
    local n = remote.call("utl", "convert_blueprint_water", p.cursor_stack)
    local names = {}
    for _, e in pairs(p.cursor_stack.get_blueprint_entities() or {}) do names[#names + 1] = e.name end
    check("blaupause in der hand: gleis → wasserweg", n == 3, table.concat(names, ", "))
    shot("blaupause-wasserweg")
  end)
  list[#list + 1] = step(function() player().clear_cursor() end)
  no_fuel_checks(list, surface, "Zug-Depot") -- Züge erreichen keine Tankstelle: Warnung
  common(list, surface)
  return list
end

script.on_nth_tick(60, function(e)
  local p = player()
  if not p then return end
  if not steps then
    local surface = game.surfaces["utl-schiffe"] or game.surfaces["utl-beispiele"]
    if not (surface and #surface.find_entities_filtered({ type = "train-stop" }) > 0) then return end
    prefix = surface.name
    p.teleport({ 74, 50 }, surface)
    steps = surface.name == "utl-schiffe" and schiffe(surface) or beispiele(surface)
    next_tick = e.tick + 60
    log("[TT] start " .. prefix .. ", " .. #steps .. " schritte")
  end
end)

--- Laufend: sieht eine Auftrags-Ausgabe „Züge unterwegs hierher“ ≥ 1?
local function watch(surface)
  if watched.incoming then return end
  for _, out in pairs(surface.find_entities_filtered({ name = "utl-station-output" })) do
    local section = out.get_control_behavior().get_section(1)
    for _, filter in pairs(section and section.filters or {}) do
      if filter.value and filter.value.name == "utl-trains-incoming" and (filter.min or 0) >= 1 then watched.incoming = true end
    end
  end
end

script.on_event(defines.events.on_tick, function(e)
  if steps and e.tick % 30 == 0 then watch(player().surface) end
  if not (steps and next_tick and e.tick >= next_tick) then return end
  index = index + 1
  local s = steps[index]
  if not s then
    game.speed = 1
    next_tick = nil
    local failed = 0
    for _, line in ipairs(results) do if line:sub(1, 4) == "FAIL" then failed = failed + 1 end end
    log(("[TT] fertig: %d prüfungen, %d fehlgeschlagen"):format(#results, failed))
    return
  end
  -- Warte-Schritt: bleibt stehen, bis die Bedingung erfüllt ist (oder die Zeit abläuft)
  if s.until_ok then
    s.started = s.started or e.tick
    if not s.until_ok() and e.tick - s.started < s.timeout then
      game.speed = FAST
      index = index - 1
      next_tick = e.tick + s.ticks
      return
    end
  end
  local ok, err = pcall(s.fn)
  if not ok then check("schritt " .. index, false, err) end
  next_tick = e.tick + s.ticks
end)
