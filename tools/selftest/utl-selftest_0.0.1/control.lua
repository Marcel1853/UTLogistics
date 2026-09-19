local W = defines.wire_connector_id
local results = {}
local function check(name, ok, info) results[#results+1] = (ok and "PASS " or "FAIL ") .. name .. (info and (" -- " .. info) or "") end
local st = {}

---@class StationInfo
---@field unit integer
---@field kind string
---@field stop_name string?
---@field config table
---@field provide table<string, integer>
---@field request table<string, integer>

--- UTL-Station abfragen (Remote-API); typisiert, damit der Linter die Felder kennt.
---@param unit integer?
---@return StationInfo?
local function station_info(unit)
  return remote.call("utl", "get_station", unit) --[[@as StationInfo?]]
end
script.on_nth_tick(10, function(e)
  local s = game.surfaces["nauvis"]
  local force = game.forces["player"]
  if e.tick == 10 then
    s.request_to_generate_chunks({0,0}, 2); s.force_generate_chunk_requests()
    for _, ent in pairs(s.find_entities_filtered{area={{-20,-20},{20,20}}}) do if ent.type ~= "character" then ent.destroy() end end
    for x=-20,20 do for y=-20,20 do end end
    s.set_tiles((function() local t={} for x=-20,20 do for y=-20,20 do t[#t+1]={name="concrete",position={x,y}} end end return t end)())
    local rails = {}
    for y=-10,10,2 do rails[#rails+1] = s.create_entity{name="straight-rail", position={1,y}, direction=defines.direction.north, force=force} end
    st.stop = s.create_entity{name="train-stop", position={3,1}, direction=defines.direction.north, force=force, raise_built=true}
    check("train-stop gebaut", st.stop ~= nil)
    st.comb = s.create_entity{name="utl-station-combinator", position={5,1.5}, direction=defines.direction.east, force=force, raise_built=true}
    check("combinator gebaut", st.comb ~= nil)
    st.chest = s.create_entity{name="steel-chest", position={7,1}, force=force}
    st.chest.insert{name="iron-plate", count=2000}
    st.cc = s.create_entity{name="constant-combinator", position={7,3}, force=force}
    local sec = st.cc.get_control_behavior().get_section(1)
    sec.set_slot(1, {value={type="item", name="copper-plate", quality="normal"}, min=-1500})
    st.chest.get_wire_connector(W.circuit_red, true).connect_to(st.comb.get_wire_connector(W.combinator_input_red, true))
    st.cc.get_wire_connector(W.circuit_green, true).connect_to(st.comb.get_wire_connector(W.combinator_input_green, true))
    -- Zuordnung per Kabel: Combinator-Ausgang → Haltestelle
    st.comb.get_wire_connector(W.combinator_output_red, true).connect_to(st.stop.get_wire_connector(W.circuit_red, true))
    s.create_entity{name="electric-energy-interface", position={9,9}, force=force}
    s.create_entity{name="medium-electric-pole", position={6,3}, force=force}
    s.create_entity{name="medium-electric-pole", position={9,7}, force=force}
    -- UTL-Haltestelle mit Kiste direkt am Halt
    st.ustop = s.create_entity{name="utl-train-stop", position={3,-7}, direction=defines.direction.north, force=force, raise_built=true}
    check("utl-haltestelle gebaut", st.ustop ~= nil)
    st.uchest = s.create_entity{name="steel-chest", position={5,-7}, force=force}
    st.uchest.insert{name="coal", count=500}
    st.uchest.get_wire_connector(W.circuit_red, true).connect_to(st.ustop.get_wire_connector(W.circuit_red, true))
    remote.call("utl","configure_station", st.ustop.unit_number, {mode="station", provide=true, request=false, provide_threshold=100})
    check("station_count == 2", remote.call("utl","station_count") == 2, tostring(remote.call("utl","station_count")))
    remote.call("utl","configure_station", st.comb.unit_number, {mode="station", provide=true, request=true})
  elseif e.tick == 190 then
    local u = station_info(st.ustop.unit_number)
    check("utl-halt: art stop", u and u.kind == "stop", u and u.kind)
    check("utl-halt: angebot coal 500", u and u.provide["item|coal|normal"] == 500, serpent.line(u and u.provide))
    local info = station_info(st.comb.unit_number)
    check("combinator verbindet sich nicht mit utl-halt", info and info.stop_name == st.stop.backer_name, info and tostring(info.stop_name))
    -- Anforderung per Slot: 600 Kohle wollen, 500 liegen da → noch keine Anforderung unter Schwelle 1000
    remote.call("utl","configure_station", st.ustop.unit_number, {provide=false, request=true, request_threshold=50})
    remote.call("utl","set_request", st.ustop.unit_number, 1, {type="item", name="coal"}, 600)
    u = station_info(st.ustop.unit_number)
    check("slot-anforderung: bedarf coal 100", u and u.request["item|coal|normal"] == 100, serpent.line(u and u.request))
    -- Stack-Schwelle 1 Stack Kohle (50) > Bedarf 100? nein → bleibt; 3 Stacks (150) > 100 → fällt weg
    remote.call("utl","configure_station", st.ustop.unit_number, {request_stack_threshold=3})
    u = station_info(st.ustop.unit_number)
    check("stack-schwelle filtert bedarf", u and next(u.request) == nil, serpent.line(u and u.request))
    st.ustop.destroy()
  elseif e.tick == 200 then
    local info = station_info(st.comb.unit_number)
    check("stop verbunden", info and info.stop_name ~= nil, info and tostring(info.stop_name))
    check("angebot iron 2000", info and info.provide["item|iron-plate|normal"] == 2000, serpent.line(info and info.provide))
    check("bedarf copper 1500", info and info.request["item|copper-plate|normal"] == 1500, serpent.line(info and info.request))
    remote.call("utl","configure_station", st.comb.unit_number, {provide_threshold=5000})
    info = station_info(st.comb.unit_number)
    check("schwelle 5000 filtert angebot", info and next(info.provide) == nil, serpent.line(info and info.provide))
    st.stop.destroy()
  elseif e.tick == 220 then
    local info = station_info(st.comb.unit_number)
    check("stop entfernt -> nicht verbunden", info and info.stop_name == nil)
    st.comb.destroy()
  elseif e.tick == 240 then
    check("station entfernt", remote.call("utl","station_count") == 0, tostring(remote.call("utl","station_count")))
  elseif e.tick == 250 then
    -- Blaupause: Geist mit Tags → beim Bauen werden die Einstellungen übernommen.
    local ghost = s.create_entity{name="entity-ghost", inner_name="utl-train-stop", position={3,-3},
      direction=defines.direction.north, force=force,
      tags={utl={mode="depot", provide=true, request=true, network="bp-netz", max_trains=3}}}
    local _, built = ghost.revive{raise_revive=true}
    local info = built and station_info(built.unit_number)
    check("blaupause: einstellungen übernommen", info and info.config.mode == "depot"
      and info.config.network == "bp-netz" and info.config.max_trains == 3, info and serpent.line(info.config))
    -- Klonen: Einstellungen der Quelle übernehmen.
    local copy = built and built.clone{position={3,5}, surface=s, force=force}
    local cinfo = copy and station_info(copy.unit_number)
    check("klonen: einstellungen übernommen", cinfo and cinfo.config.mode == "depot"
      and cinfo.config.network == "bp-netz", cinfo and serpent.line(cinfo.config))
    -- Blaupause erstellen: UTL schreibt die Einstellungen als Tag hinein.
    local inv = game.create_inventory(1)
    inv.insert{name="blueprint"}
    local bp = inv[1]
    local map = bp.create_blueprint{surface=s, force=force, area={{2,-5},{5,-1}}}
    local tagged = remote.call("utl","tag_blueprint", bp, map, s)
    local tag
    for _, ent in pairs(bp.get_blueprint_entities() or {}) do
      if ent.name == "utl-train-stop" then tag = ent.tags and ent.tags.utl end
    end
    check("blaupause erstellen: tag geschrieben", tagged == 1 and tag and tag.mode == "depot" and tag.network == "bp-netz",
      tostring(tagged) .. " " .. serpent.line(tag))
    inv.destroy()
    if built then built.destroy() end
    if copy then copy.destroy() end
    -- Combinator ohne Kabel: keine Verbindung (kein Umkreis mehr); mit Kabel am Ausgang: verbunden
    st.vstop = s.create_entity{name="train-stop", position={3,-9}, direction=defines.direction.north, force=force, raise_built=true}
    st.vcomb = s.create_entity{name="utl-station-combinator", position={5,-9.5}, direction=defines.direction.east, force=force, raise_built=true}
    local vi = station_info(st.vcomb.unit_number)
    check("combinator ohne kabel: keine haltestelle", vi and vi.stop_name == nil, vi and tostring(vi.stop_name))
    st.vcomb.get_wire_connector(W.combinator_output_green, true).connect_to(st.vstop.get_wire_connector(W.circuit_green, true))
  elseif e.tick == 260 then
    local vi = station_info(st.vcomb.unit_number)
    check("combinator mit kabel am ausgang: verbunden", vi and vi.stop_name == st.vstop.backer_name, vi and tostring(vi.stop_name))
    st.vcomb.destroy(); st.vstop.destroy()
    build_train_test(s, force)
  elseif e.tick > 260 and not st.done then
    train_test_step()
  end
end)

-- Phase 2: echter Zug. Gerade Strecke bei x=61, Depot D (Richtung Nord), Anbieter P (Nord),
-- Abnehmer R (Süd). Laden/Entladen übernimmt der Test per Script.
function build_train_test(s, force)
  s.request_to_generate_chunks({61,0}, 4); s.force_generate_chunk_requests()
  for _, ent in pairs(s.find_entities_filtered{area={{40,-90},{80,90}}}) do if ent.type ~= "character" then ent.destroy() end end
  local t={} for x=40,80 do for y=-90,90 do t[#t+1]={name="concrete",position={x,y}} end end s.set_tiles(t)
  for y=-80,80,2 do s.create_entity{name="straight-rail", position={61,y}, direction=defines.direction.north, force=force} end
  local function stop(name, pos, dir)
    local e = s.create_entity{name="utl-train-stop", position=pos, direction=dir, force=force, raise_built=true}
    e.backer_name = name
    return e
  end
  st.d = stop("UTL-D", {63,-10}, defines.direction.north)
  st.p = stop("UTL-P", {63,-60}, defines.direction.north)
  st.r = stop("UTL-R", {59,60}, defines.direction.south)
  st.f = stop("UTL-F", {59,20}, defines.direction.south)
  st.c = stop("UTL-C", {59,45}, defines.direction.south)
  remote.call("utl","configure_station", st.c.unit_number, {mode="cleanup"})
  remote.call("utl","configure_station", st.f.unit_number, {mode="fuel"})
  st.d2 = stop("UTL-D2", {63,-30}, defines.direction.north) -- nur Ziel für copy_settings
  st.pcc = s.create_entity{name="constant-combinator", position={65,-60}, force=force}
  st.pcc.get_control_behavior().get_section(1).set_slot(1, {value={type="item", name="iron-plate", quality="normal"}, min=2000})
  st.pcc.get_wire_connector(W.circuit_green, true).connect_to(st.p.get_wire_connector(W.circuit_green, true))
  remote.call("utl","configure_station", st.d.unit_number, {mode="depot"})
  remote.call("utl","configure_station", st.p.unit_number, {mode="station", provide=true, request=false, provide_threshold=100})
  remote.call("utl","configure_station", st.r.unit_number, {mode="station", provide=false, request=true, request_threshold=100})
  remote.call("utl","set_request", st.r.unit_number, 1, {type="item", name="iron-plate"}, 1000)
  -- Einstellungen kopieren (Shift-Klick): zweite Haltestelle wird ebenfalls Depot.
  local e = stop("UTL-E", {63,-30}, defines.direction.north)
  remote.call("utl","copy_settings", st.d.unit_number, e.unit_number)
  local ei = station_info(e.unit_number)
  check("einstellungen kopiert: depot", ei and ei.config.mode == "depot", ei and ei.config.mode)
  e.destroy()
  local l1 = s.create_entity{name="locomotive", position={61,0}, direction=defines.direction.north, force=force}
  st.wagon = s.create_entity{name="cargo-wagon", position={61,7}, direction=defines.direction.north, force=force}
  local l2 = s.create_entity{name="locomotive", position={61,14}, direction=defines.direction.south, force=force}
  for _, l in ipairs({l1,l2}) do l.insert{name="coal", count=120} end
  st.locos = {l1, l2}
  st.train = l1.train
  st.round = 1
  local sch = st.train.get_schedule()
  sch.add_record{station="UTL-D", wait_conditions={{type="inactivity", ticks=300}}}
  sch.group = "UTL-Test"
  sch.go_to_station(1)
  st.seen = {}
end

local CARGO = defines.inventory.cargo_wagon

-- Runde 10: eigenes Gleis bei x = 91 mit Flüssigkeitszug (Netzwerk „fluid“).
function build_fluid_test()
  local s, force = game.surfaces["nauvis"], game.forces["player"]
  local t = {} for x = 84, 100 do for y = -90, 90 do t[#t + 1] = { name = "concrete", position = { x, y } } end end
  s.set_tiles(t)
  for _, ent in pairs(s.find_entities_filtered{ area = {{84,-90},{100,90}} }) do if ent.type ~= "character" then ent.destroy() end end
  for y = -80, 80, 2 do s.create_entity{ name = "straight-rail", position = { 91, y }, direction = defines.direction.north, force = force } end
  local function stop(name, pos, dir)
    local e = s.create_entity{ name = "utl-train-stop", position = pos, direction = dir, force = force, raise_built = true }
    e.backer_name = name
    return e
  end
  st.fd = stop("UTL-FD", { 93, -10 }, defines.direction.north)
  st.fp = stop("UTL-FP", { 93, -60 }, defines.direction.north)
  st.fr = stop("UTL-FR", { 89, 60 }, defines.direction.south)
  local cc = s.create_entity{ name = "constant-combinator", position = { 95, -60 }, force = force }
  cc.get_control_behavior().get_section(1).set_slot(1, { value = { type = "fluid", name = "water", quality = "normal" }, min = 50000 })
  cc.get_wire_connector(W.circuit_green, true).connect_to(st.fp.get_wire_connector(W.circuit_green, true))
  remote.call("utl", "configure_station", st.fd.unit_number, { mode = "depot", network = "fluid" })
  remote.call("utl", "configure_station", st.fp.unit_number, { mode = "station", provide = true, request = false, network = "fluid", provide_threshold = 1000 })
  remote.call("utl", "configure_station", st.fr.unit_number, { mode = "station", provide = false, request = true, network = "fluid", request_threshold = 1000 })
  remote.call("utl", "set_request", st.fr.unit_number, 1, { type = "fluid", name = "water" }, 20000)
  local l1 = s.create_entity{ name = "locomotive", position = { 91, 0 }, direction = defines.direction.north, force = force }
  st.fwagon = s.create_entity{ name = "fluid-wagon", position = { 91, 7 }, direction = defines.direction.north, force = force }
  local l2 = s.create_entity{ name = "locomotive", position = { 91, 14 }, direction = defines.direction.south, force = force }
  for _, l in ipairs({ l1, l2 }) do l.insert{ name = "coal", count = 120 } end
  st.ftrain = l1.train
  local sch = st.ftrain.get_schedule()
  sch.add_record{ station = "UTL-FD", wait_conditions = {{ type = "inactivity", ticks = 300 }} }
  sch.go_to_station(1)
end

local function set_fuel(count)
  for _, l in ipairs(st.locos) do
    local inv = l.get_fuel_inventory(); inv.clear()
    if count > 0 then inv.insert{name="coal", count=count} end
  end
end

-- Runde 1: normale Lieferung. Runde 2: Zug fast leer → erst Tankstelle, dann Lieferung.
-- Runde 3: knapper Zug im Depot fährt ohne Auftrag tanken und kommt zurück.
local function delivery_round(tag, fuel)
  local d = remote.call("utl","get_deliveries")[1]
  local seen = st.seen
  if d and not seen[tag .. d.state] then
    seen[tag .. d.state] = true
    if d.state == "to_provider" then
      check(tag .. "lieferung angelegt: 1000 eisen", d.manifest["item|iron-plate|normal"] == 1000, serpent.line(d))
      check(tag .. "depot-zug vergeben", remote.call("utl","idle_train_count") == 0)
      if tag == "R1 " then
        local found
        for _, a in ipairs(remote.call("utl","get_alerts")) do
          if a.group == "no_train" then found = a end
        end
        -- Standard: Warnung erst nach 5 Minuten unbedient → in den ersten Sekunden keine.
        check("keine „kein zug“-warnung vor ablauf der wartezeit", found == nil,
          serpent.line(remote.call("utl","get_alerts")))
      end
      local recs = st.train.get_schedule().get_records()
      local want = fuel and 7 or 5
      check(tag .. "temporäre halte eingefügt + depot", #recs == want, tostring(#recs) .. " statt " .. want)
    elseif d.state == "loading" then
      check(tag .. "am anbieter angekommen", st.train.station == st.p)
      if fuel then check(tag .. "vorher getankt", seen[tag .. "fuel"] == true) end
      st.wagon.get_inventory(CARGO).insert{name="iron-plate", count=1000}
    elseif d.state == "unloading" then
      check(tag .. "am abnehmer angekommen", st.train.station == st.r)
      remote.call("utl","set_request", st.r.unit_number, 1, nil)
      st.wagon.get_inventory(CARGO).clear()
    end
  end
  if fuel and d and d.state == "to_provider" and st.train.station == st.f and not seen[tag .. "fuel"] then
    seen[tag .. "fuel"] = true
    set_fuel(150) -- volltanken → fuel_full
  end
  if not d and seen[tag .. "unloading"] and remote.call("utl","idle_train_count") == 1 then
    check(tag .. "lieferung abgeschlossen", remote.call("utl","delivery_count") == 0)
    check(tag .. "nur depot-halt übrig", #st.train.get_schedule().get_records() == 1)
    check(tag .. "zuggruppe unverändert", st.train.get_schedule().group == "UTL-Test")
    check(tag .. "zug wieder frei im depot", st.train.station == st.d)
    return true
  end
  return false
end

function train_test_step()
  local tick = game.tick
  if st.round == 1 then
    if delivery_round("R1 ", false) then
      st.round = 2
      set_fuel(5) -- 5 von 150 Kohle ≈ 3 % < 25 %
      remote.call("utl","set_request", st.r.unit_number, 1, {type="item", name="iron-plate"}, 1000)
    end
  elseif st.round == 2 then
    if delivery_round("R2 ", true) then
      st.round = 3
      set_fuel(5)
      remote.call("utl","copy_settings", st.d.unit_number, st.d2.unit_number) -- löst Depot-Prüfung aus
      remote.call("utl","configure_station", st.d.unit_number, {mode="depot"})
    end
  elseif st.round == 3 then
    if st.train.station == st.f and not st.seen.r3fuel then
      st.seen.r3fuel = true
      check("R3 depot-zug ohne auftrag zur tankstelle", remote.call("utl","delivery_count") == 0 and remote.call("utl","idle_train_count") == 0)
      set_fuel(150)
    elseif st.seen.r3fuel and remote.call("utl","idle_train_count") == 1 then
      check("R3 nach dem tanken zurück im depot", st.train.station == st.d)
      st.round = 4
      st.wagon.get_inventory(CARGO).insert{name="copper-plate", count=300}
      remote.call("utl","configure_station", st.d.unit_number, {mode="depot"}) -- Depot neu prüfen
    end
  elseif st.round == 4 then
    if st.train.station == st.c and not st.seen.r4clean then
      st.seen.r4clean = true
      check("R4 restladung: zug zur cleanup-station", remote.call("utl","idle_train_count") == 0)
      st.wagon.get_inventory(CARGO).clear()
    elseif st.seen.r4clean and remote.call("utl","idle_train_count") == 1 then
      check("R4 nach dem cleanup frei im depot", st.train.station == st.d)
      -- Runde 5: D nur noch für Züge bis Länge 2 (Testzug hat 3) → Umsetzen zum gleichnamigen D2.
      st.round = 5
      st.d2.backer_name = "UTL-D"
      remote.call("utl","configure_station", st.d.unit_number, {max_train_length=2})
    end
  elseif st.round == 5 then
    if not st.seen.r5moving and st.train.station ~= st.d then
      st.seen.r5moving = true
      check("R5 zu langer zug verlässt depot", remote.call("utl","idle_train_count") == 0)
    elseif st.seen.r5moving and remote.call("utl","idle_train_count") == 1 then
      check("R5 zug steht frei im passenden depot", st.train.station == st.d2, st.train.station and st.train.station.position.y)
      check("R5 fahrplan unverändert (nur depot-halt)", #st.train.get_schedule().get_records() == 1)
      -- Runde 6: D2 verliert die Depot-Rolle (heißt aber weiter „UTL-D“) → Zug zieht nach D um.
      st.round = 6
      remote.call("utl","configure_station", st.d.unit_number, {max_train_length=0})
      -- erreichbares echtes Depot gleichen Namens in Fahrtrichtung (gerade Strecke ohne Schleife)
      st.d3 = game.surfaces["nauvis"].create_entity{name="utl-train-stop", position={63,-45},
        direction=defines.direction.north, force=game.forces["player"], raise_built=true}
      st.d3.backer_name = "UTL-D"
      remote.call("utl","configure_station", st.d3.unit_number, {mode="depot"})
      remote.call("utl","configure_station", st.d2.unit_number, {mode="station", provide=false, request=false})
    end
  elseif st.round == 6 then
    if not st.seen.r6moving and st.train.station ~= st.d2 then
      st.seen.r6moving = true
      check("R6 zug verlässt haltestelle ohne depot-rolle", remote.call("utl","idle_train_count") == 0)
    elseif st.seen.r6moving and remote.call("utl","idle_train_count") == 1 then
      check("R6 zug steht frei im echten depot", st.train.station == st.d3)
      -- Runde 7: Netzwerk „leer“ ohne Züge → Warnung „kein Zug“ erst nach 5 Minuten.
      st.round = 7
      local surface, force = game.surfaces["nauvis"], game.forces["player"]
      local req = surface.create_entity{name="utl-train-stop", position={59,-70}, direction=defines.direction.south, force=force, raise_built=true}
      local prov = surface.create_entity{name="utl-train-stop", position={63,70}, direction=defines.direction.north, force=force, raise_built=true}
      local cc = surface.create_entity{name="constant-combinator", position={65,70}, force=force}
      cc.get_control_behavior().get_section(1).set_slot(1, {value={type="item", name="coal", quality="normal"}, min=5000})
      cc.get_wire_connector(W.circuit_green, true).connect_to(prov.get_wire_connector(W.circuit_green, true))
      remote.call("utl","configure_station", prov.unit_number, {mode="station", provide=true, request=false, network="leer"})
      remote.call("utl","configure_station", req.unit_number, {mode="station", provide=false, request=true, network="leer", request_threshold=100})
      remote.call("utl","set_request", req.unit_number, 1, {type="item", name="coal"}, 2000)
      st.r7_start = game.tick
    end
  elseif st.round == 7 then
    local found
    for _, a in ipairs(remote.call("utl","get_alerts")) do
      if a.group == "no_train" then found = a end
    end
    local elapsed = game.tick - st.r7_start
    if found or elapsed > 5 * 3600 + 1800 then
      check("R7 warnung „kein zug“ nach ablauf der wartezeit", found and elapsed >= 5 * 3600, "nach " .. elapsed .. " ticks")
      -- Runde 8: direkt der nächste Auftrag – nach dem Entladen besteht der Bedarf weiter.
      st.round = 8
      remote.call("utl","set_request", st.r.unit_number, 1, {type="item", name="iron-plate"}, 1000)
    end
  elseif st.round == 8 then
    local d = remote.call("utl","get_deliveries")[1]
    if d and not st.seen["R8 " .. d.id .. d.state] then
      st.seen["R8 " .. d.id .. d.state] = true
      if d.state == "loading" then
        st.wagon.get_inventory(CARGO).insert{name="iron-plate", count=1000}
      elseif d.state == "unloading" then
        st.wagon.get_inventory(CARGO).clear()
        if st.r8_first then remote.call("utl","set_request", st.r.unit_number, 1, nil) end
        st.r8_first = st.r8_first or d.id
      elseif d.state == "to_provider" and st.r8_first and d.id ~= st.r8_first then
        check("R8 direkt der nächste auftrag (ohne depot)", d.chained == true and remote.call("utl","chained_count") >= 1,
          serpent.line(d))
      end
    end
    if not d and st.r8_first and remote.call("utl","idle_train_count") >= 1 and st.seen.r8_done == nil then
      st.seen.r8_done = true
      -- Runde 9: mehrere Waren – Anbieter hat Eisen und Kupfer, Abnehmer braucht beides.
      st.round = 9
      st.pcc.get_control_behavior().get_section(1).set_slot(2, {value={type="item", name="copper-plate", quality="normal"}, min=2000})
      remote.call("utl","set_request", st.r.unit_number, 1, {type="item", name="iron-plate"}, 800)
      remote.call("utl","set_request", st.r.unit_number, 2, {type="item", name="copper-plate"}, 600)
    end
  elseif st.round == 9 then
    local d = remote.call("utl","get_deliveries")[1]
    if d and not st.seen["R9 " .. d.state] then
      st.seen["R9 " .. d.state] = true
      if d.state == "to_provider" then
        check("R9 eine lieferung mit zwei waren", d.manifest["item|iron-plate|normal"] == 800
          and d.manifest["item|copper-plate|normal"] == 600, serpent.line(d.manifest))
      elseif d.state == "loading" then
        st.wagon.get_inventory(CARGO).insert{name="iron-plate", count=800}
        st.wagon.get_inventory(CARGO).insert{name="copper-plate", count=600}
      elseif d.state == "unloading" then
        remote.call("utl","set_request", st.r.unit_number, 1, nil)
        remote.call("utl","set_request", st.r.unit_number, 2, nil)
        st.wagon.get_inventory(CARGO).clear()
      end
    end
    if not d and st.seen["R9 unloading"] and not st.seen.r9_done then
      st.seen.r9_done = true
      check("R9 beide waren geliefert", true)
      build_fluid_test()
      st.round = 10
    end
  elseif st.round == 10 then
    local d
    for _, x in ipairs(remote.call("utl","get_deliveries")) do if x.manifest["fluid|water|normal"] then d = x end end
    if d and not st.seen["R10 " .. d.state] then
      st.seen["R10 " .. d.state] = true
      if d.state == "to_provider" then
        check("R10 flüssigkeit: lieferung wasser", d.manifest["fluid|water|normal"] == 20000, serpent.line(d.manifest))
      elseif d.state == "loading" then
        st.fwagon.insert_fluid{name="water", amount=20000}
      elseif d.state == "unloading" then
        remote.call("utl","set_request", st.fr.unit_number, 1, nil)
        st.fwagon.clear_fluid_inside()
      end
    end
    if not d and st.seen["R10 unloading"] and st.ftrain.station == st.fd then
      check("R10 flüssigkeitszug zurück im depot", true)
      -- Runde 11: Cleanup-Filter. Näher liegt ein Cleanup nur für Items, weiter weg eins nur für
      -- Wasser: Restwasser muss zum Wasser-Cleanup. Danach Dampf, den keiner annimmt: Zug wartet,
      -- bis der Filter ergänzt wird (erneuter Versuch per Heartbeat).
      local s, force = game.surfaces["nauvis"], game.forces["player"]
      local function stop(name, y)
        local e = s.create_entity{ name = "utl-train-stop", position = { 89, y }, direction = defines.direction.south, force = force, raise_built = true }
        e.backer_name = name
        return e
      end
      st.fci = stop("UTL-FC-Items", 20)
      st.fcw = stop("UTL-FC-Wasser", 40)
      remote.call("utl", "configure_station", st.fci.unit_number, { mode = "cleanup", network = "fluid",
        cleanup = { all_items = true, all_fluids = false, items = {}, fluids = {} } })
      remote.call("utl", "configure_station", st.fcw.unit_number, { mode = "cleanup", network = "fluid",
        cleanup = { all_items = false, all_fluids = false, items = {}, fluids = { "water" } } })
      st.fwagon.insert_fluid{ name = "water", amount = 5000 }
      remote.call("utl", "configure_station", st.fd.unit_number, { mode = "depot" }) -- Depot neu prüfen
      st.round = 11
    end
  elseif st.round == 11 then
    local at = st.ftrain.station
    if at == st.fci and not st.seen.r11_wrong then
      st.seen.r11_wrong = true
      check("R11 wasser nicht zum item-cleanup", false)
    elseif at == st.fcw and not st.seen.r11_water then
      st.seen.r11_water = true
      check("R11 restwasser zum wasser-cleanup", true)
      st.fwagon.clear_fluid_inside()
    elseif st.seen.r11_water and not st.seen.r11_steam and at == st.fd then
      st.seen.r11_steam = true
      st.steam_tick = tick
      st.fwagon.insert_fluid{ name = "steam", amount = 1000 }
      remote.call("utl", "configure_station", st.fd.unit_number, { mode = "depot" })
    elseif st.seen.r11_steam and not st.seen.r11_waited and tick > st.steam_tick + 1200 then
      st.seen.r11_waited = true
      check("R11 dampf ohne passendes cleanup: zug wartet im depot", st.ftrain.station == st.fd)
      remote.call("utl", "configure_station", st.fcw.unit_number,
        { cleanup = { all_items = false, all_fluids = false, items = {}, fluids = { "water", "steam" } } })
    elseif st.seen.r11_waited and at == st.fcw and not st.seen.r11_steam_done then
      st.seen.r11_steam_done = true
      check("R11 nach dem filter-eintrag: dampf zum cleanup (erneuter versuch)", true)
      st.fwagon.clear_fluid_inside()
    elseif st.seen.r11_steam_done and at == st.fd then
      check("R11 danach wieder im depot", true)
      st.done = true
    end
  end
  if not st.done and tick >= 71900 then
    check("zugtest vollständig", false, "runde " .. st.round .. " " .. serpent.line(st.seen) .. " idle=" .. remote.call("utl","idle_train_count") .. " state=" .. st.train.state)
    st.done = true
  end
  if st.done then
    for _, r in ipairs(results) do log("[SELFTEST] " .. r) end
  end
end
