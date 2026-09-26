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
    -- Zeitlimits aus: die alten Runden füllen und leeren die Wagen selbst (erst R18 prüft sie)
    remote.call("utl", "set_map_config", "utl-load-timeout", 0)
    remote.call("utl", "set_map_config", "utl-unload-timeout", 0)
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
    -- Forschung: ohne „Netzverbund I“ keine Verbindung, mit Stufe I genau ein Partner. Ein Partner
    -- darf nirgends sonst Partner sein und keine eigenen Partner haben.
    local surf = st.ustop.surface_index
    check("forschung: ohne netzverbund keine verbindung",
      remote.call("utl","link_networks", surf, "X", "Y") == "link-limit")
    force.technologies["utl-networks-1"].researched = true
    check("forschung: stufe I erlaubt einen partner", remote.call("utl","link_networks", surf, "X", "Y") == true)
    check("forschung: stufe I erlaubt keinen zweiten",
      remote.call("utl","link_networks", surf, "X", "Z") == "link-limit")
    check("stern: partner kann nicht partner eines anderen werden",
      remote.call("utl","link_networks", surf, "Z", "Y") == "link-partner-taken")
    check("stern: partner bekommt keine eigenen partner",
      remote.call("utl","link_networks", surf, "Y", "Z") == "link-center-is-partner")
    remote.call("utl","unlink_networks", surf, "X", "Y")
    check("stern: verbindung gelöst", (remote.call("utl","get_network_star", surf, "X") --[[@as table]]).role == nil)
    -- Für die übrigen Runden alles freischalten (Ladesteuerung, Zusatznetze II/III).
    for _, name in ipairs({ "utl-train-logistics", "utl-loading-control", "utl-networks-2", "utl-networks-3" }) do
      force.technologies[name].researched = true
    end
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

-- Runde 12: eigenes Gleis bei x = 121. Netz „A“ und Netz „B“ sind getrennt; das Reserve-Depot
-- hat das Heimatnetz „R“ und die Zusatznetze „A“ und „B“, sein Zug bedient also beide.
function build_network_test()
  local s, force = game.surfaces["nauvis"], game.forces["player"]
  local t = {} for x = 114, 130 do for y = -90, 90 do t[#t + 1] = { name = "concrete", position = { x, y } } end end
  s.set_tiles(t)
  for _, ent in pairs(s.find_entities_filtered{ area = {{114,-90},{130,90}} }) do if ent.type ~= "character" then ent.destroy() end end
  for y = -80, 80, 2 do s.create_entity{ name = "straight-rail", position = { 121, y }, direction = defines.direction.north, force = force } end
  local function stop(name, pos, dir)
    local e = s.create_entity{ name = "utl-train-stop", position = pos, direction = dir, force = force, raise_built = true }
    e.backer_name = name
    return e
  end
  st.pa = stop("UTL-PA", { 123, -60 }, defines.direction.north)   -- Anbieter Netz A
  st.pb = stop("UTL-PB", { 123, -40 }, defines.direction.north)   -- Anbieter Netz B
  st.nd = stop("UTL-RD", { 123, -10 }, defines.direction.north)   -- Reserve-Depot (R + A + B)
  st.ra = stop("UTL-RA", { 119, 40 }, defines.direction.south)    -- Abnehmer Netz A
  st.rb = stop("UTL-RB", { 119, 60 }, defines.direction.south)    -- Abnehmer Netz B
  for _, def in ipairs({ { st.pa, "iron-plate" }, { st.pb, "copper-plate" } }) do
    local cc = s.create_entity{ name = "constant-combinator", position = { def[1].position.x + 2, def[1].position.y }, force = force }
    cc.get_control_behavior().get_section(1).set_slot(1, { value = { type = "item", name = def[2], quality = "normal" }, min = 5000 })
    cc.get_wire_connector(W.circuit_green, true).connect_to(def[1].get_wire_connector(W.circuit_green, true))
  end
  remote.call("utl", "configure_station", st.pa.unit_number, { mode = "station", provide = true, request = false, network = "A", provide_threshold = 100 })
  remote.call("utl", "configure_station", st.pb.unit_number, { mode = "station", provide = true, request = false, network = "B", provide_threshold = 100 })
  remote.call("utl", "configure_station", st.ra.unit_number, { mode = "station", provide = false, request = true, network = "A", request_threshold = 100 })
  remote.call("utl", "configure_station", st.rb.unit_number, { mode = "station", provide = false, request = true, network = "B", request_threshold = 100 })
  -- Reserve-Depot im Netz R; R wird Zentrum eines Sterns mit den Partnern A und B
  remote.call("utl", "configure_station", st.nd.unit_number, { mode = "depot", network = "R" })
  local surf = st.nd.surface_index
  local ok_a = remote.call("utl", "link_networks", surf, "R", "A")
  local ok_b = remote.call("utl", "link_networks", surf, "R", "B")
  local star = remote.call("utl", "get_network_star", surf, "R") --[[@as table]]
  check("R16 stern R mit A und B", ok_a == true and ok_b == true and star.role == "center" and #star.partners == 2,
    serpent.line(star))
  local l1 = s.create_entity{ name = "locomotive", position = { 121, 0 }, direction = defines.direction.north, force = force }
  st.nwagon = s.create_entity{ name = "cargo-wagon", position = { 121, 7 }, direction = defines.direction.north, force = force }
  local l2 = s.create_entity{ name = "locomotive", position = { 121, 14 }, direction = defines.direction.south, force = force }
  for _, l in ipairs({ l1, l2 }) do l.insert{ name = "coal", count = 120 } end
  st.ntrain = l1.train
  local sch = st.ntrain.get_schedule()
  sch.add_record{ station = "UTL-RD", wait_conditions = {{ type = "inactivity", ticks = 300 }} }
  sch.go_to_station(1)
  remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
end

-- Runde 20: eigenes Gleis bei x = 151 mit Depot „UTL-QD“ (Limit 2) und Cleanup „UTL-QC“
-- (Limit 1), dazu zwei Züge. Beide bekommen von Hand Ladung: UTL muss das bemerken und sie
-- nacheinander zum Cleanup schicken, nie beide gleichzeitig (Vormerkung der Wegpunkt-Fahrten).
function build_cleanup_limit_test()
  local s, force = game.surfaces["nauvis"], game.forces["player"]
  local t = {} for x = 144, 160 do for y = -90, 90 do t[#t + 1] = { name = "concrete", position = { x, y } } end end
  s.set_tiles(t)
  for _, ent in pairs(s.find_entities_filtered{ area = {{144,-90},{160,90}} }) do
    if ent.type ~= "character" then ent.destroy() end
  end
  for y = -80, 80, 2 do
    s.create_entity{ name = "straight-rail", position = { 151, y }, direction = defines.direction.north, force = force }
  end
  local function stop(name, pos)
    local e = s.create_entity{ name = "utl-train-stop", position = pos, direction = defines.direction.north,
      force = force, raise_built = true }
    e.backer_name = name
    return e
  end
  st.qd = stop("UTL-QD", { 153, -20 })   -- Depot
  st.qc = stop("UTL-QC", { 153, -60 })   -- Cleanup, in Fahrtrichtung dahinter
  remote.call("utl", "configure_station", st.qd.unit_number, { mode = "depot", network = "Q" })
  remote.call("utl", "configure_station", st.qc.unit_number, { mode = "cleanup", network = "Q" })
  st.qd.trains_limit = 2
  st.qc.trains_limit = 1
  local wagons = {}
  for i = 1, 2 do
    -- Lok an beiden Enden, sonst kann der Zug nicht wenden (Depot liegt hinter ihm)
    local y = 20 + (i - 1) * 35 -- beide südlich, fahren nacheinander nach Norden
    local loco = s.create_entity{ name = "locomotive", position = { 151, y }, direction = defines.direction.north, force = force }
    local wagon = s.create_entity{ name = "cargo-wagon", position = { 151, y + 7 }, direction = defines.direction.north, force = force }
    local back = s.create_entity{ name = "locomotive", position = { 151, y + 14 }, direction = defines.direction.south, force = force }
    loco.insert{ name = "coal", count = 120 }
    back.insert{ name = "coal", count = 120 }
    local sch = loco.train.get_schedule()
    sch.add_record{ station = "UTL-QD", wait_conditions = {{ type = "inactivity", ticks = 120 }} }
    sch.go_to_station(1)
    loco.train.manual_mode = false
    wagon.get_inventory(CARGO).insert{ name = "copper-plate", count = 100 }
    wagons[i] = wagon
  end
  st.r20 = { wagons = wagons, max = 0, deadline = 149000 }
end

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
      -- Runde 12: Ladefilter. Der Anbieter bietet Eisen und Kupfer an, bestellt wird nur Eisen –
      -- die Wagenslots müssen auf Eisen stehen und der Rest gesperrt sein.
      st.round = 12
      remote.call("utl", "set_request", st.r.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
    end
  elseif st.round == 12 then
    local inv = st.wagon.get_inventory(CARGO)
    local d = remote.call("utl","get_deliveries")[1]
    if d and not st.seen["R12 " .. d.state] then
      st.seen["R12 " .. d.state] = true
      if d.state == "to_provider" then
        local f = inv.get_filter(1)
        check("R12 ladefilter auf die bestellte ware", f ~= nil and f.name == "iron-plate", f and f.name or "kein filter")
        check("R12 übrige slots gesperrt", inv.get_bar() <= #inv, inv.get_bar() .. " von " .. #inv)
        check("R12 fremde ware wird nicht angenommen", inv.can_insert{ name = "copper-plate", count = 1 } == false)
      elseif d.state == "loading" then
        check("R12 bestellte ware passt hinein", inv.insert{ name = "iron-plate", count = 1000 } == 1000)
      elseif d.state == "unloading" then
        remote.call("utl","set_request", st.r.unit_number, 1, nil)
        inv.clear()
      end
    end
    if not d and st.seen["R12 unloading"] and not st.seen.r12_done then
      st.seen.r12_done = true
      check("R12 nach der lieferung sind die filter wieder weg", not inv.is_filtered(), serpent.line(inv.get_filter(1)))
      check("R12 sperre wieder aufgehoben", inv.get_bar() == #inv + 1, inv.get_bar() .. " von " .. #inv)
      -- Runde 13: eigener Filter des Spielers bleibt unangetastet.
      st.round = 13
      inv.set_filter(1, { name = "coal", quality = "normal", comparator = "=" })
      remote.call("utl","set_request", st.r.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
    end
  elseif st.round == 13 then
    local inv = st.wagon.get_inventory(CARGO)
    local d = remote.call("utl","get_deliveries")[1]
    if d and not st.seen["R13 " .. d.state] then
      st.seen["R13 " .. d.state] = true
      if d.state == "to_provider" then
        local f = inv.get_filter(1)
        check("R13 eigener filter des spielers bleibt", f ~= nil and f.name == "coal", f and f.name or "kein filter")
        check("R13 keine sperre gesetzt", inv.get_bar() == #inv + 1, inv.get_bar() .. " von " .. #inv)
        -- Runde 14 gleich hier: Lieferung abbrechen (Handbetrieb) → Filter müssen weg sein.
        inv.set_filter(1, nil)
        st.train.manual_mode = true
      end
    end
    if st.seen["R13 to_provider"] and not st.seen.r13_done and remote.call("utl","delivery_count") == 0 then
      st.seen.r13_done = true
      check("R14 abbruch räumt die filter", not inv.is_filtered() and inv.get_bar() == #inv + 1,
        serpent.line(inv.get_filter(1)) .. " bar " .. inv.get_bar())
      remote.call("utl","set_request", st.r.unit_number, 1, nil)
      st.train.manual_mode = false
      -- Runde 15: Auftrags-Ausgabe. Am Anbieter muss die Lieferung positiv anliegen,
      -- am Abnehmer negativ; danach ist die Ausgabe wieder leer.
      st.round = 15
      st.r15_start = tick
    end
  elseif st.round == 15 then
    local function output_signals(stop)
      local found = stop.surface.find_entities_filtered{ name = "utl-station-output",
        area = { { stop.position.x - 3, stop.position.y - 3 }, { stop.position.x + 3, stop.position.y + 3 } } }[1]
      if not found then return nil end
      local section = found.get_control_behavior().get_section(1)
      local out = {}
      for _, filter in pairs(section and section.filters or {}) do
        if filter.value then out[filter.value.name] = filter.min end
      end
      return out
    end
    if not st.seen.r15_started and tick > st.r15_start + 120 then
      st.seen.r15_started = true
      check("R15 ausgabe neben der haltestelle vorhanden", output_signals(st.p) ~= nil)
      remote.call("utl","set_request", st.r.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
    end
    local d = st.seen.r15_started and remote.call("utl","get_deliveries")[1]
    if d and not st.seen["R15 " .. d.state] then
      st.seen["R15 " .. d.state] = true
      if d.state == "to_provider" then
        st.r15_sent = tick -- die Ausgabe schreibt der Heartbeat, also gleich danach prüfen
      elseif d.state == "loading" then
        local p = output_signals(st.p)
        check("R15 zug am bahnsteig: nummer, länge, loks und wagen",
          p and p["utl-train-id"] == st.train.id and p["utl-train-length"] == 3
          and p["utl-train-locos"] == 2 and p["utl-train-wagons"] == 1, serpent.line(p))
        st.wagon.get_inventory(CARGO).insert{ name = "iron-plate", count = 1000 }
      elseif d.state == "unloading" then
        remote.call("utl","set_request", st.r.unit_number, 1, nil)
        st.wagon.get_inventory(CARGO).clear()
      end
    end
    if st.r15_sent and not st.seen.r15_checked and tick > st.r15_sent + 60 then
      st.seen.r15_checked = true
      local p, r = output_signals(st.p), output_signals(st.r)
      check("R15 anbieter zeigt den auftrag positiv", p and p["iron-plate"] == 1000, serpent.line(p))
      check("R15 abnehmer zeigt den auftrag negativ", r and r["iron-plate"] == -1000, serpent.line(r))
    end
    if st.seen["R15 unloading"] and not d and not st.seen.r15_done then
      st.seen.r15_done = true
      local p, r = output_signals(st.p), output_signals(st.r)
      check("R15 nach der lieferung ist die ausgabe leer", p and next(p) == nil and r and next(r) == nil,
        serpent.line(p) .. " " .. serpent.line(r))
      -- Runde 16: Zusatznetze. Eigenes Gleis bei x = 121 mit zwei getrennten Netzen „A“ und „B“
      -- und einem Reserve-Depot (Heimatnetz „R“, Zusatznetze A und B).
      build_network_test()
      st.round = 16
    end
  elseif st.round == 16 then
    local d = remote.call("utl", "get_deliveries")[1]
    local cargo = st.nwagon.get_inventory(CARGO)
    if d then
      local to = d.to or ""
      -- Be- und Entladen übernimmt der Test (wie in den anderen Runden)
      if d.state == "loading" then
        cargo.insert{ name = string.find(to, "UTL-RA", 1, true) and "iron-plate" or "copper-plate", count = 1000 }
      elseif d.state == "unloading" then
        cargo.clear()
      end
      if string.find(to, "UTL-RA", 1, true) and not st.seen.r12_a then
        st.seen.r12_a = true
        check("R16 reserve-zug bedient netz A", d.train_id == st.ntrain.id, tostring(d.train_id))
        -- Anfrage in A sofort zurücknehmen, sonst verkettet der Zug Lieferung an Lieferung nach A
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
      elseif string.find(to, "UTL-RB", 1, true) and not st.seen.r12_b then
        st.seen.r12_b = true
        check("R16 derselbe reserve-zug bedient auch netz B", d.train_id == st.ntrain.id, tostring(d.train_id))
        remote.call("utl", "set_request", st.rb.unit_number, 1, nil)
      end
    elseif st.seen.r12_a and not st.seen.r12_next then
      -- Netz A fertig: jetzt Bedarf in Netz B; derselbe Zug muss auch dorthin
      st.seen.r12_next = true
      remote.call("utl", "set_request", st.rb.unit_number, 1, { type = "item", name = "copper-plate" }, 1000)
    elseif st.seen.r12_b and st.ntrain.station == st.nd then
      check("R16 reserve-zug wieder im eigenen depot", true)
      -- Gegenprobe: ohne Verbindung zu B darf der Reserve-Zug Netz B nicht bedienen
      remote.call("utl", "unlink_networks", st.nd.surface_index, "R", "B")
      remote.call("utl", "set_request", st.rb.unit_number, 1, { type = "item", name = "copper-plate" }, 1000)
      st.round = 17
      st.wait_until = tick + 1200
    end
  elseif st.round == 17 then
    if tick >= st.wait_until then
      check("R17 ohne verbindung keine lieferung in netz B", remote.call("utl", "delivery_count") == 0,
        tostring(remote.call("utl", "delivery_count")))
      -- Runde 18: Zeitlimits (5 s) mit dem Reserve-Zug in Netz A
      remote.call("utl", "set_request", st.rb.unit_number, 1, nil)
      remote.call("utl", "set_map_config", "utl-load-timeout", 5)
      remote.call("utl", "set_map_config", "utl-unload-timeout", 5)
      check("R18 standard: fracht oder inaktivität", remote.call("utl", "get_team_config", "player", "timeout_mode") == "or",
        tostring(remote.call("utl", "get_team_config", "player", "timeout_mode")))
      remote.call("utl", "set_map_config", "utl-timeout-mode", "and") -- erst „und“ prüfen
      st.nwagon.get_inventory(CARGO).clear()
      remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
      st.r18 = { phase = "and" }
      st.round = 18
    end
  elseif st.round == 18 then
    local r = st.r18
    local d = remote.call("utl", "get_deliveries")[1]
    local cargo = st.nwagon.get_inventory(CARGO)
    if r.phase == "and" then
      -- „Fracht und Zeit“: sofort voll beladen, trotzdem erst nach 5 s los; beim Abnehmer ebenso
      if d and d.state == "loading" and not r.and_load then
        r.and_load = tick
        cargo.insert{ name = "iron-plate", count = 1000 }
      elseif d and d.state == "to_requester" and r.and_load and not r.and_left then
        r.and_left = true
        check("R18 fracht und inaktivität: laden dauert mindestens 5 s", tick - r.and_load >= 280, tostring(tick - r.and_load))
      elseif d and d.state == "unloading" and not r.and_unload then
        r.and_unload = tick
        r.and_id = d.id
        cargo.clear()
        -- Anforderung weg und ab jetzt „oder“: sonst hängte die Verkettung sofort einen neuen
        -- Auftrag (noch mit „und“) an
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
        remote.call("utl", "set_map_config", "utl-timeout-mode", "or")
      elseif r.and_unload and (not d or d.id ~= r.and_id) then
        check("R18 fracht und inaktivität: entladen dauert mindestens 5 s", tick - r.and_unload >= 280, tostring(tick - r.and_unload))
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
        r.phase = "partial"
      end
    elseif r.phase == "partial" then
      -- nur 400 von 1000 laden: der Zug muss nach 5 s mit 400 losfahren
      if d and d.state == "loading" and not r.loading then
        r.loading = tick
        cargo.insert{ name = "iron-plate", count = 400 }
      elseif d and d.state == "to_requester" and r.loading then
        local waited = tick - r.loading
        check("R18 inaktivität laden: abfahrt nach ~5 s", waited >= 280 and waited <= 700, tostring(waited))
        check("R18 ladeliste auf das geladene gekürzt", d.manifest["item|iron-plate|normal"] == 400,
          serpent.line(d.manifest))
        r.phase = "unload"
      end
    elseif r.phase == "unload" then
      -- beim Abnehmer nicht entladen: nach 5 s fährt er trotzdem weiter
      if d and d.state == "unloading" and not r.unloading then
        r.unloading = tick
      elseif not d and r.unloading then
        local waited = tick - r.unloading
        check("R18 inaktivität entladen: weiterfahrt nach ~5 s mit rest", waited >= 280 and waited <= 700
          and cargo.get_item_count("iron-plate") > 0, waited .. " " .. cargo.get_item_count("iron-plate"))
        cargo.clear() -- Rest „ausräumen“, damit der Zug wieder frei wird
        r.phase = "empty"
      end
    elseif r.phase == "empty" then
      -- leerer Anbieter: nichts laden → nach 5 s Abbruch statt Fahrt zum Abnehmer
      if d and d.state == "loading" and not r.empty then
        r.empty = tick
      elseif not d and r.empty then
        local canceled = false
        for _, a in pairs(remote.call("utl", "get_alerts")) do
          if string.find(a.key, "canceled:", 1, true) then canceled = true end
        end
        check("R18 leerer anbieter: lieferung abgebrochen", canceled and tick - r.empty <= 700, tostring(tick - r.empty))
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
        -- Runde 19: Teams getrennt – Abnehmer des Teams „blau“ im selben Netz „A“
        local blau = game.forces["blau"] or game.create_force("blau")
        local s = game.surfaces["nauvis"]
        st.blue = s.create_entity{ name = "utl-train-stop", position = { 119, 20 }, direction = defines.direction.south,
          force = blau, raise_built = true }
        st.blue.backer_name = "UTL-BLAU"
        remote.call("utl", "configure_station", st.blue.unit_number,
          { mode = "station", provide = false, request = true, network = "A", request_threshold = 100 })
        remote.call("utl", "set_request", st.blue.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
        -- Verbindungen je Team: „blau“ kann A ↔ B verbinden, obwohl bei „player“ R ↔ A besteht
        local surf = st.blue.surface_index
        check("R19 netzverbindungen je team getrennt",
          remote.call("utl", "link_networks", surf, "A", "B", "blau") == "link-limit" -- blau hat keine Forschung
          and (remote.call("utl", "get_network_star", surf, "A", "blau") --[[@as table]]).role == nil
          and (remote.call("utl", "get_network_star", surf, "A") --[[@as table]]).role == "partner",
          serpent.line(remote.call("utl", "get_network_star", surf, "A")))
        st.round = 19
        st.wait_until = tick + 1500
      end
    end
  elseif st.round == 19 then
    local wrong = false
    for _, d in pairs(remote.call("utl", "get_deliveries")) do
      if d.to == "UTL-BLAU" then wrong = true end
    end
    if wrong then
      check("R19 zug beliefert kein fremdes team", false, "lieferung an UTL-BLAU")
      st.done = true
    elseif tick >= st.wait_until then
      check("R19 zug beliefert kein fremdes team", true)
      build_cleanup_limit_test()
      st.round = 20
    end
  elseif st.round == 20 then
    -- Zuglimit am Cleanup: UTL fährt per Wegpunkt, deshalb muss es die unterwegs befindlichen
    -- Züge selbst mitzählen. Nie mehr als „Limit“ dort stehend + unterwegs.
    local r = st.r20
    local here = st.qc.trains_count + remote.call("utl", "pending_trains", st.qc.unit_number)
    if here > r.max then r.max = here end
    -- Das Cleanup leert der Test selbst (im Spiel machen das Greifarme)
    for _, wagon in ipairs(r.wagons) do
      if wagon.valid and wagon.train.station == st.qc then wagon.get_inventory(CARGO).clear() end
    end
    local empty = 0
    for _, wagon in ipairs(r.wagons) do
      if wagon.valid and wagon.get_inventory(CARGO).is_empty() then empty = empty + 1 end
    end
    -- Genug geprüft, sobald ein Zug von selbst geleert wurde: dass UTL die Fahrt überhaupt
    -- vergibt (sonst wäre das Limit trivial eingehalten) und dass nie zwei gleichzeitig dürfen.
    if (empty >= 1 and r.max >= 1) or tick >= r.deadline then
      check("R20 zuglimit am cleanup eingehalten (stehend + unterwegs)", r.max <= 1,
        "höchstens " .. r.max .. " gleichzeitig")
      check("R20 von Hand beladener Zug wird selbst zum Cleanup geschickt", empty >= 1 and r.max >= 1,
        empty .. " von 2 geleert, max " .. r.max)
      -- Runde 21: Nachladen. Ohne Zeitlimit wartet der Zug am Anbieter, solange die Ladeliste
      -- nicht voll ist – so lässt sich in Ruhe prüfen, ob der neue Bedarf dort landet.
      remote.call("utl", "set_map_config", "utl-load-timeout", 0)
      remote.call("utl", "set_map_config", "utl-unload-timeout", 0)
      remote.call("utl", "set_map_config", "utl-top-up", true)
      st.nwagon.get_inventory(CARGO).clear()
      -- Frischer Zug am Reserve-Gleis: der alte findet nach R18/R20 keinen Weg mehr zurück
      -- (no_path), und ein Zug ohne Depot gilt nicht als frei.
      if st.ntrain.valid then
        for _, wagen in pairs(st.ntrain.carriages) do wagen.destroy() end
      end
      do
        local s21 = game.surfaces["nauvis"]
        local f21 = game.forces["player"]
        local l1 = s21.create_entity{ name = "locomotive", position = { 121, 0 }, direction = defines.direction.north, force = f21 }
        st.nwagon = s21.create_entity{ name = "cargo-wagon", position = { 121, 7 }, direction = defines.direction.north, force = f21 }
        local l2 = s21.create_entity{ name = "locomotive", position = { 121, 14 }, direction = defines.direction.south, force = f21 }
        for _, l in ipairs({ l1, l2 }) do if l then l.insert{ name = "coal", count = 150 } end end
        st.ntrain = l1 and l1.train
        if st.ntrain then
          local sch = st.ntrain.get_schedule()
          sch.add_record{ station = "UTL-RD", wait_conditions = { { type = "inactivity", ticks = 120 } } }
          sch.go_to_station(1)
          st.ntrain.manual_mode = false
        end
      end
      remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 500)
      st.r21 = { phase = "wait", deadline = tick + 5400 }
      st.round = 21
    end
  elseif st.round == 21 then
    local r = st.r21
    local list = remote.call("utl", "get_deliveries") --[[@as table]]
    local KEY = "item|iron-plate|normal"
    -- Nur Lieferungen an den Abnehmer dieser Runde zählen: nach dem Entladen hängt UTL dem Zug
    -- sofort den nächsten Auftrag an (Verkettung), der sonst mit dem alten verwechselt wird.
    local d, mine = nil, {}
    for _, entry in pairs(list) do
      if entry.requester == st.ra.unit_number then
        mine[#mine + 1] = entry
        if d == nil or (r.id and entry.id == r.id) then d = entry end
      end
    end
    local function by_id(id)
      for _, entry in pairs(list) do
        if entry.id == id then return entry end
      end
      return nil
    end
    if r.phase == "wait" then
      if d and (d.state == "to_provider" or d.state == "loading") then
        r.id, r.first = d.id, d.manifest[KEY] or 0
        -- Bedarf wächst, während der Zug schon unterwegs/am Anbieter ist
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 1500)
        r.phase = "grow"
        r.deadline = tick + 3600
      end
      if r.phase == "wait" and tick >= r.deadline then
        local ra, pa = station_info(st.ra.unit_number), station_info(st.pa.unit_number)
        check("R21 nachladen: lieferung kam zustande", false,
          "frei=" .. remote.call("utl", "idle_train_count")
          .. " zug=" .. (st.ntrain.valid and (st.ntrain.state .. "/" .. tostring(st.ntrain.station and st.ntrain.station.backer_name)) or "weg")
          .. " ladung=" .. serpent.line(st.ntrain.valid and st.ntrain.get_contents() or {})
          .. " bedarf=" .. serpent.line(ra and ra.request) .. " angebot=" .. serpent.line(pa and pa.provide))
        st.done = true
      end
    elseif r.phase == "grow" then
      local menge = d and d.manifest[KEY] or 0
      if d and d.id == r.id and menge > r.first then
        check("R21 nachladen: ladeliste der laufenden lieferung wächst", true, r.first .. " -> " .. menge)
        check("R21 nachladen: kein zweiter zug losgeschickt", #mine == 1, tostring(#mine))
        -- Wartebedingung am Anbieter-Halt muss die neue Menge verlangen
        local wanted = nil
        local schedule = st.ntrain.valid and st.ntrain.get_schedule()
        if schedule then
          for i = 1, schedule.get_record_count() or 0 do
            local record = schedule.get_record({ schedule_index = i })
            if record and record.station == "UTL-PA" then
              for _, condition in pairs(schedule.get_wait_conditions({ schedule_index = i }) or {}) do
                if condition.condition and condition.condition.constant then wanted = condition.condition.constant end
              end
            end
          end
        end
        check("R21 nachladen: wartebedingung am anbieter angepasst", wanted == menge,
          tostring(wanted) .. " statt " .. tostring(menge))
        -- Nächster Fall: eine zweite Ware kommt dazu. Der Anbieter bietet ab jetzt auch Kupfer.
        local s21 = game.surfaces["nauvis"]
        local umkreis = { { st.pa.position.x, st.pa.position.y - 3 }, { st.pa.position.x + 5, st.pa.position.y + 3 } }
        local cc = s21.find_entities_filtered({ name = "constant-combinator", area = umkreis })[1]
        if cc then
          cc.get_control_behavior().get_section(1)
            .set_slot(2, { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 5000 })
        end
        remote.call("utl", "set_request", st.ra.unit_number, 2, { type = "item", name = "copper-plate" }, 800)
        r.grown = menge
        r.phase = "second"
        r.deadline = tick + 3600
      elseif tick >= r.deadline then
        check("R21 nachladen: ladeliste der laufenden lieferung wächst", false,
          "blieb bei " .. tostring(menge) .. ", " .. serpent.line(list))
        st.done = true
      end
    elseif r.phase == "second" then
      local COPPER = "item|copper-plate|normal"
      local eigene = by_id(r.id)
      local kupfer = eigene and eigene.manifest[COPPER] or 0
      if eigene and kupfer > 0 then
        local eisen = eigene.manifest[KEY] or 0
        check("R21 nachladen: zweite ware kommt auf dieselbe ladeliste", kupfer == 800, tostring(kupfer))
        check("R21 nachladen: erste ware bleibt erhalten", eisen == r.grown,
          tostring(eisen) .. " statt " .. tostring(r.grown))
        -- Nächster Fall: mehr Bedarf als in den Zug passt (1 Wagen = 40 Slots × 100 = 4000)
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 20000)
        r.phase = "cap"
        r.deadline = tick + 3600
      elseif tick >= r.deadline then
        local pa, ra = station_info(st.pa.unit_number), station_info(st.ra.unit_number)
        check("R21 nachladen: zweite ware kommt auf dieselbe ladeliste", false,
          "Ladeliste " .. serpent.line(eigene and eigene.manifest)
          .. " Angebot " .. serpent.line(pa and pa.provide)
          .. " Bedarf " .. serpent.line(ra and ra.request)
          .. " Zustand " .. tostring(eigene and eigene.state))
        st.done = true
      end
    elseif r.phase == "cap" then
      -- Der Wagen hat 40 Slots à 100 Stück. Eisen und Kupfer zusammen dürfen sie nicht sprengen.
      local eigene = by_id(r.id)
      local eisen = eigene and eigene.manifest[KEY] or 0
      local kupfer = eigene and eigene.manifest["item|copper-plate|normal"] or 0
      local slots = math.ceil(eisen / 100) + math.ceil(kupfer / 100)
      if eigene and slots >= 40 then
        check("R21 nachladen: nicht mehr als in den Zug passt", slots == 40,
          slots .. " Slots (" .. eisen .. " Eisen, " .. kupfer .. " Kupfer)")
        check("R21 nachladen: immer noch nur ein Zug", #mine == 1, tostring(#mine))
        -- Jetzt wirklich beladen: der Zug muss abfahren und die Lieferung sauber abschließen
        local inv = st.nwagon.get_inventory(CARGO)
        inv.insert{ name = "iron-plate", count = eisen }
        if kupfer > 0 then inv.insert{ name = "copper-plate", count = kupfer } end
        r.phase = "deliver"
        r.deadline = tick + 5400
      elseif tick >= r.deadline then
        check("R21 nachladen: nicht mehr als in den Zug passt", false,
          "nur " .. slots .. " Slots belegt (erwartet 40)")
        st.done = true
      end
    elseif r.phase == "deliver" then
      local eigene = by_id(r.id)
      if eigene and eigene.state == "unloading" then
        st.nwagon.get_inventory(CARGO).clear() -- der Abnehmer hat keine Greifarme
      elseif not eigene then
        local ra = station_info(st.ra.unit_number)
        check("R21 nachgeladene lieferung sauber abgeschlossen", true)
        -- Reservierungen müssen weg sein: der Abnehmer fragt wieder die volle Menge an
        check("R21 nach dem entladen keine reste in den reservierungen",
          ra ~= nil and (ra.request[KEY] or 0) > 0, serpent.line(ra and ra.request))
        -- Gegenprobe: mit ausgeschaltetem Nachladen darf die Ladeliste nicht wachsen.
        -- Erst alles zur Ruhe bringen, sonst startet die nächste Lieferung gleich mit voller
        -- Ladung (dann könnte auch mit Nachladen nichts mehr dazukommen).
        remote.call("utl", "set_map_config", "utl-top-up", false)
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
        remote.call("utl", "set_request", st.ra.unit_number, 2, nil)
        -- Zeitlimit kurz wieder an: der verkettete Auftrag wartet sonst ewig auf Ladung,
        -- die im Test niemand einfüllt.
        remote.call("utl", "set_map_config", "utl-load-timeout", 5)
        st.nwagon.get_inventory(CARGO).clear()
        r.phase = "off-idle"
        r.deadline = tick + 5400
      elseif tick >= r.deadline then
        check("R21 nachgeladene lieferung sauber abgeschlossen", false,
          "Zustand " .. tostring(eigene and eigene.state) .. ", " .. serpent.line(list))
        st.done = true
      end
    elseif r.phase == "off-idle" then
      -- warten, bis keine Lieferung mehr an diesem Abnehmer läuft
      -- Laufende Fahrten zu Ende bringen: beim Anbieter beladen, beim Abnehmer leeren.
      -- Ein nachträglich gesetztes Zeitlimit hilft hier nicht, die Wartebedingungen stehen
      -- schon im Fahrplan.
      for _, entry in pairs(mine) do
        if entry.state == "loading" then
          for key, menge in pairs(entry.manifest) do
            if key == KEY then st.nwagon.get_inventory(CARGO).insert{ name = "iron-plate", count = menge } end
          end
        elseif entry.state == "unloading" then
          st.nwagon.get_inventory(CARGO).clear()
        end
      end
      if #mine == 0 then
        st.nwagon.get_inventory(CARGO).clear()
        remote.call("utl", "set_map_config", "utl-load-timeout", 0) -- für die Gegenprobe wieder aus
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 500)
        r.id = nil
        r.phase = "off-wait"
        r.deadline = tick + 5400
      elseif tick >= r.deadline then
        check("R21 gegenprobe: lieferungen kamen zur ruhe", false, serpent.line(mine))
        st.done = true
      end
    elseif r.phase == "off-wait" then
      local neue = mine[1]
      if neue and (neue.state == "to_provider" or neue.state == "loading") then
        r.id, r.first = neue.id, neue.manifest[KEY] or 0
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 1500)
        r.phase = "off-check"
        r.deadline = tick + 1800
      elseif tick >= r.deadline then
        check("R21 gegenprobe: zweite lieferung kam zustande", false, serpent.line(list))
        st.done = true
      end
    elseif r.phase == "off-check" then
      local eigene = by_id(r.id)
      local menge = eigene and eigene.manifest[KEY] or r.first
      if tick >= r.deadline then
        check("R21 mit abgeschaltetem nachladen bleibt die ladeliste gleich",
          menge == r.first and r.first < 4000,
          tostring(r.first) .. " -> " .. tostring(menge) .. " (Zug fasst 4000)")
        -- Runde 22: Cleanup gibt zurück. Erst alles zur Ruhe bringen, dann kurze Zeitlimits:
        -- eine Fahrt ohne Ladung bricht nach 5 s von selbst ab, so lässt sich Anbieter-Wahl um
        -- Anbieter-Wahl prüfen.
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
        remote.call("utl", "set_request", st.ra.unit_number, 2, nil)
        remote.call("utl", "set_map_config", "utl-load-timeout", 5)
        remote.call("utl", "set_map_config", "utl-unload-timeout", 5)
        st.r22 = { phase = "drain", deadline = tick + 7200 }
        st.round = 22
      end
    end
  elseif st.round == 22 then
    -- Das Reserve-Gleis ist ein Sackgleis ohne Wendeschleife: Haltestellen nur in Fahrtrichtung
    -- anfahren und keine Fahrt am Anbieter abbrechen lassen (sonst findet der Zug nicht mehr
    -- „richtig herum“ ins Depot, no_path). Der Test bringt deshalb jede Fahrt selbst zu Ende.
    -- Aufbau: Depot RD (nordwärts, y -9) · Cleanup RC als Anbieter (südwärts, y 28, vor dem
    -- Abnehmer) · Abnehmer RA (südwärts, y 40) · Cleanup RC2 für die Restladung (südwärts, y 50).
    local r = st.r22
    local list = remote.call("utl", "get_deliveries") --[[@as table]]
    local d = nil
    for _, entry in pairs(list) do
      if entry.requester == st.ra.unit_number then d = entry end
    end
    local inv = st.nwagon.valid and st.nwagon.get_inventory(CARGO)
    local function request(name, count)
      remote.call("utl", "set_request", st.ra.unit_number, 1, name and { type = "item", name = name } or nil, count)
    end
    local function fail(name, info)
      check(name, false, info)
      st.done = true
    end
    --- Fahrt zu Ende bringen: am Anbieter das Bestellte einladen, am Abnehmer leeren.
    local function feed(entry)
      if not inv then return end
      r.fed = r.fed or {}
      if entry.state == "loading" and not r.fed[entry.id] then
        r.fed[entry.id] = true
        for key, amount in pairs(entry.manifest) do
          local _, name = string.match(key, "^(%a+)|([^|]+)")
          if name then inv.insert{ name = name, count = amount } end
        end
      elseif entry.state == "unloading" then
        inv.clear()
      end
    end
    local at_depot = st.ntrain.valid and st.ntrain.station == st.nd
    if r.phase == "drain" then
      for _, entry in pairs(list) do feed(entry) end
      if #list == 0 and at_depot then
        if inv then inv.clear() end
        local s22, f22 = game.surfaces["nauvis"], game.forces["player"]
        local function stop22(name, y)
          local e = s22.create_entity{ name = "utl-train-stop", position = { 119, y }, direction = defines.direction.south,
            force = f22, raise_built = true }
          e.backer_name = name
          return e
        end
        st.rc = stop22("UTL-RC", 28)
        st.rc2 = stop22("UTL-RC2", 50)
        -- ein Konstant-Kombinator spielt den Kisteninhalt des Cleanups RC
        st.rc_cc = s22.create_entity{ name = "constant-combinator", position = { 116, 28 }, force = f22 }
        -- Kupfer statt Eisen: Eisen blieb in R18 an RA als Rest übrig und ist für Cleanups dorthin
        -- noch gesperrt (Rückweg-Sperre, 5 min) – das würde den Rang-Test verfälschen
        st.rc_cc.get_control_behavior().get_section(1).set_slot(1,
          { value = { type = "item", name = "copper-plate", quality = "normal" }, min = 3000 })
        st.rc_cc.get_wire_connector(W.circuit_green, true).connect_to(st.rc.get_wire_connector(W.circuit_green, true))
        remote.call("utl", "configure_station", st.rc.unit_number, { mode = "cleanup", network = "R" })
        remote.call("utl", "configure_station", st.rc2.unit_number, { mode = "cleanup", network = "R" })
        r.phase, r.deadline = "off", tick + 180
      elseif tick >= r.deadline then
        fail("R22 vorbereitung: zug ist frei im depot", serpent.line(list))
      end
    elseif r.phase == "off" and tick >= r.deadline then
      local rc = station_info(st.rc.unit_number)
      check("R22 cleanup ohne häkchen bietet nichts an", rc ~= nil and next(rc.provide) == nil,
        serpent.line(rc and rc.provide))
      remote.call("utl", "configure_station", st.rc.unit_number, { cleanup = { offer = "reserve" } })
      r.phase, r.deadline = "reserve", tick + 180
    elseif r.phase == "reserve" and tick >= r.deadline then
      local rc = station_info(st.rc.unit_number)
      check("R22 cleanup mit häkchen bietet seinen inhalt an",
        rc ~= nil and (rc.provide["item|copper-plate|normal"] or 0) == 3000, serpent.line(rc and rc.provide))
      check("R22 häkchen setzen behält die übrigen cleanup-einstellungen",
        rc ~= nil and rc.config.cleanup.all_items == true, serpent.line(rc and rc.config.cleanup))
      request("copper-plate", 500)
      r.phase, r.deadline = "reserve-pick", tick + 3600
    elseif r.phase == "reserve-pick" then
      if d and not r.picked then
        r.picked = true
        check("R22 reserve: normaler anbieter geht vor", d.from == "UTL-PA", tostring(d.from))
        request(nil)
      end
      for _, entry in pairs(list) do feed(entry) end
      if r.picked and #list == 0 and at_depot then
        remote.call("utl", "configure_station", st.rc.unit_number, { cleanup = { offer = "first" } })
        request("copper-plate", 500)
        r.phase, r.deadline = "first-pick", tick + 3600
      elseif tick >= r.deadline then
        fail("R22 reserve: fahrt vom normalen anbieter", "picked=" .. tostring(r.picked) .. " " .. serpent.line(list))
      end
    elseif r.phase == "first-pick" then
      if d then
        check("R22 zuerst leeren: cleanup geht vor", d.from == "UTL-RC", tostring(d.from))
        r.id = d.id
        r.phase, r.deadline = "leftover", tick + 7200
      elseif tick >= r.deadline then
        fail("R22 zuerst leeren: lieferung kam zustande", "frei=" .. remote.call("utl", "idle_train_count")
          .. " " .. serpent.line(list))
      end
    elseif r.phase == "leftover" then
      -- Am Cleanup RC 500 Kupfer laden; der Abnehmer nimmt nur 300 ab: 200 bleiben als Rest im
      -- Zug → Rückweg-Sperre für Kupfer an diesem Abnehmer. (Fremde Ware lässt sich nicht als Rest
      -- unterschieben: die Wagenfilter lassen nur das Bestellte in den Wagen.)
      local own = nil
      for _, entry in pairs(list) do if entry.id == r.id then own = entry end end
      if own and own.state == "loading" and not r.loaded and inv then
        inv.insert{ name = "copper-plate", count = 500 }
        r.loaded = true
      elseif own and own.state == "unloading" and not r.unloaded and inv then
        inv.remove{ name = "copper-plate", count = 300 }
        request(nil)
        r.unloaded = true
      end
      -- Rest am Cleanup RC2 (hinter dem Abnehmer) – dort leert der Test den Wagen
      if st.ntrain.valid and st.ntrain.station then
        r.visits = r.visits or {}
        r.visits[st.ntrain.station.backer_name] = true
      end
      if r.unloaded and st.ntrain.valid and st.ntrain.station == st.rc2 and inv then
        r.cleaned = true
        inv.clear()
      end
      if r.cleaned and not own and #list == 0 and at_depot and inv and inv.is_empty() then
        -- Kupfer hat jetzt nur noch der Cleanup RC: dem normalen Anbieter PA das Kupfer nehmen
        local umkreis = { { st.pa.position.x, st.pa.position.y - 3 }, { st.pa.position.x + 5, st.pa.position.y + 3 } }
        local pa_cc = game.surfaces["nauvis"].find_entities_filtered({ name = "constant-combinator", area = umkreis })[1]
        if pa_cc then pa_cc.get_control_behavior().get_section(1).clear_slot(2) end
        request("copper-plate", 300)
        r.phase, r.deadline = "block", tick + 1500
      elseif tick >= r.deadline then
        fail("R22 rest: zug bringt die restladung zum cleanup", serpent.line(list) .. " station="
          .. tostring(st.ntrain.valid and st.ntrain.station and st.ntrain.station.backer_name)
          .. " besucht=" .. serpent.line(r.visits) .. " ladung=" .. serpent.line(inv and inv.get_contents())
          .. " geladen=" .. tostring(r.loaded) .. " entladen=" .. tostring(r.unloaded))
      end
    elseif r.phase == "block" then
      if d then
        fail("R22 rückweg-sperre: cleanup bringt den rest nicht gleich zurück", "lieferung von " .. tostring(d.from))
      elseif tick >= r.deadline then
        -- aussagekräftig nur, wenn der Zug die ganze Zeit frei war
        check("R22 rückweg-sperre: cleanup bringt den rest nicht gleich zurück",
          remote.call("utl", "idle_train_count") >= 1, "frei=" .. remote.call("utl", "idle_train_count"))
        request(nil)
        -- Runde 23: Wende-Greifarm auf freiem Feld bei x = 200: Kiste A – Greifarm – Kiste B.
        -- Ein Konstant-Kombinator (rotes Kabel) schaltet das Standard-Signal utl-unloading.
        local s23, f23 = game.surfaces["nauvis"], game.forces["player"]
        s23.request_to_generate_chunks({ 200, 0 }, 1)
        s23.force_generate_chunk_requests()
        for _, e in pairs(s23.find_entities_filtered{ area = { { 195, -5 }, { 206, 6 } } }) do
          if e.type ~= "character" then e.destroy() end
        end
        st.ra_chest = s23.create_entity{ name = "iron-chest", position = { 200.5, -0.5 }, force = f23 }
        st.rev = s23.create_entity{ name = "utl-reversible-inserter", position = { 200.5, 0.5 },
          direction = defines.direction.north, force = f23, raise_built = true }
        st.rb_chest = s23.create_entity{ name = "iron-chest", position = { 200.5, 1.5 }, force = f23 }
        local eei = s23.create_entity{ name = "electric-energy-interface", position = { 203, 0 }, force = f23 }
        eei.power_production, eei.electric_buffer_size = 1000000, 10000000
        s23.create_entity{ name = "medium-electric-pole", position = { 201.5, 0.5 }, force = f23 }
        st.rev_cc = s23.create_entity{ name = "constant-combinator", position = { 199.5, 0.5 }, force = f23 }
        st.rev_cc.get_wire_connector(W.circuit_red, true).connect_to(st.rev.get_wire_connector(W.circuit_red, true))
        st.ra_chest.insert{ name = "iron-plate", count = 50 }
        st.rb_chest.insert{ name = "copper-plate", count = 50 }
        st.r23 = { phase = "normal", deadline = tick + 180, base = st.rev.direction }
        st.round = 23
      end
    end
  elseif st.round == 23 then
    local r = st.r23
    local function set_signal(value)
      local section = st.rev_cc.get_control_behavior().get_section(1)
      if value and value ~= 0 then
        section.set_slot(1, { value = { type = "virtual", name = "utl-unloading", quality = "normal" }, min = value })
      else
        section.clear_slot(1)
      end
    end
    local function counts()
      return st.ra_chest.get_item_count("iron-plate"), st.rb_chest.get_item_count("iron-plate"),
        st.ra_chest.get_item_count("copper-plate"), st.rb_chest.get_item_count("copper-plate")
    end
    if r.phase == "normal" and tick >= r.deadline then
      -- ohne Signal: arbeitet wie gebaut – eine Ware ist hinübergewandert
      local a_iron, b_iron, a_copper, b_copper = counts()
      r.flow = b_iron > 0 and "A-B" or (a_copper > 0 and "B-A" or nil)
      check("R23 wende-greifarm ohne signal arbeitet wie gebaut", r.flow ~= nil and st.rev.direction == r.base,
        "fluss " .. tostring(r.flow) .. ", eisen A/B " .. a_iron .. "/" .. b_iron .. ", kupfer A/B " .. a_copper .. "/" .. b_copper)
      set_signal(1)
      r.phase, r.deadline = "flipped", tick + 240
    elseif r.phase == "flipped" and tick >= r.deadline then
      local a_iron, b_iron, a_copper, b_copper = counts()
      local reversed = (r.flow == "A-B" and a_copper > 0) or (r.flow == "B-A" and b_iron > 0)
      check("R23 wende-greifarm mit signal dreht sich um", reversed and st.rev.direction == (r.base + 8) % 16,
        "richtung " .. st.rev.direction .. " (gebaut " .. r.base .. "), eisen A/B " .. a_iron .. "/" .. b_iron
        .. ", kupfer A/B " .. a_copper .. "/" .. b_copper)
      r.phase, r.deadline, r.changes, r.last_dir = "flicker", tick + 180, 0, st.rev.direction
    elseif r.phase == "flicker" then
      -- flackerndes Signal (alle 10 Ticks um): höchstens eine Drehung je Sekunde
      set_signal((tick / 10) % 2 == 0 and 1 or 0)
      if st.rev.direction ~= r.last_dir then
        r.changes = r.changes + 1
        r.last_dir = st.rev.direction
      end
      if tick >= r.deadline then
        check("R23 flackerndes signal: höchstens eine drehung je sekunde", r.changes <= 4,
          r.changes .. " drehungen in 3 s")
        set_signal(0)
        -- Auftrags-Ausgabe: Lade- und Entlade-Signal während eines echten Zugs
        remote.call("utl", "set_request", st.ra.unit_number, 1, { type = "item", name = "iron-plate" }, 500)
        r.phase, r.deadline = "output", tick + 7200
      end
    elseif r.phase == "output" then
      local function output_of(stop)
        local found = stop.surface.find_entities_filtered{ name = "utl-station-output",
          area = { { stop.position.x - 3, stop.position.y - 3 }, { stop.position.x + 3, stop.position.y + 3 } } }[1]
        local out = {}
        local section = found and found.get_control_behavior().get_section(1)
        for _, filter in pairs(section and section.filters or {}) do
          if filter.value then out[filter.value.name] = filter.min end
        end
        return out
      end
      local d = nil
      for _, entry in pairs(remote.call("utl", "get_deliveries") --[[@as table]]) do
        if entry.requester == st.ra.unit_number then d = entry end
      end
      local inv = st.nwagon.valid and st.nwagon.get_inventory(CARGO)
      if d and d.state == "loading" and not r.seen_load then
        local out = output_of(st.pa)
        r.seen_load = true
        check("R23 auftrags-ausgabe am anbieter: zug lädt", out["utl-loading"] == 1 and out["utl-unloading"] == nil,
          serpent.line(out))
        if inv then inv.insert{ name = "iron-plate", count = 500 } end
      elseif d and d.state == "unloading" and not r.seen_unload then
        local out = output_of(st.ra)
        r.seen_unload = true
        check("R23 auftrags-ausgabe am abnehmer: zug entlädt", out["utl-unloading"] == 1 and out["utl-loading"] == nil,
          serpent.line(out))
        remote.call("utl", "set_request", st.ra.unit_number, 1, nil)
        if inv then inv.clear() end
      end
      if r.seen_load and r.seen_unload then
        st.done = true
      elseif tick >= r.deadline then
        check("R23 auftrags-ausgabe: lade- und entladesignal gesehen", false,
          "laden " .. tostring(r.seen_load) .. ", entladen " .. tostring(r.seen_unload) .. ", " .. serpent.line(d))
        st.done = true
      end
    end
  end
  if not st.done and tick >= 199900 then
    check("zugtest vollständig", false, "runde " .. st.round .. " " .. serpent.line(st.seen) .. " idle=" .. remote.call("utl","idle_train_count") .. " state=" .. st.train.state
      .. " deliveries=" .. serpent.line(remote.call("utl","get_deliveries"))
      .. (st.ntrain and st.ntrain.valid and (" ntrain=" .. st.ntrain.state .. " " .. tostring(st.ntrain.station and st.ntrain.station.backer_name)) or ""))
    st.done = true
  end
  if st.done then
    for _, r in ipairs(results) do log("[SELFTEST] " .. r) end
  end
end
