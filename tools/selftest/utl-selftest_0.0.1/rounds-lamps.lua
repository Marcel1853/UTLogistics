-- Selbsttest R47 (11.10.2026): Zustandsanzeige an Haltestellen. Jede Haltestelle hat ein Anzeigefeld am
-- Kabel; UTL schreibt das Farbsignal (Standardfarben): „R47-Leer“ gelb, „R47-Aus“ (per Schaltung aus)
-- rot, „R47-Ziel“ erst blau (Zug kommt), dann grün (Zug steht da), „R47-Depot“ türkis (Zug wartet).
-- Ein Feld mit eigener Nachricht bleibt unberührt. Lampen (Start-Einstellung) nur, wenn eingeschaltet.
local Lamps = {}

local W = defines.wire_connector_id
local LINE = 1

local function stop(s, force, name, x, y, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, y }, direction = east and 4 or 12,
    force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

--- Anzeigefeld neben der Haltestelle (auf der dem Gleis abgewandten Seite), per rotem Kabel angeschlossen.
local function panel(s, force, st, dx)
  local dy = st.direction == 12 and -3.5 or 3.5
  local p = s.create_entity({ name = "display-panel", position = { st.position.x + dx, st.position.y + dy },
    force = force }) --[[@as LuaEntity]]
  p.get_wire_connector(W.circuit_red, true).connect_to(st.get_wire_connector(W.circuit_red, true))
  return p
end

--- Farbe im Anzeigefeld („blue“, „green“ …) oder nil.
local function panel_color(p)
  local behavior = p.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior?]]
  local record = behavior and behavior.records_count > 0 and behavior.get_record(1)
  local name = record and record.icon and record.icon.name
  return name and name:gsub("^signal%-", "") or nil
end

--- Anzahl der Lampen an `entity`.
local function lamp_count(entity)
  local count = 0
  for _, object in pairs(rendering.get_all_objects("UTLogistics")) do
    if object.valid and object.type == "sprite" and object.target.entity == entity then count = count + 1 end
  end
  return count
end

local function loco_pair(s, force, x, dir)
  local a = s.create_entity({ name = "locomotive", position = { x, LINE }, direction = dir, force = force }) --[[@as LuaEntity]]
  local b = s.create_entity({ name = "locomotive", position = { x + (dir == 12 and 7 or -7), LINE }, direction = (dir + 8) % 16,
    force = force }) --[[@as LuaEntity]]
  a.insert({ name = "coal", count = 50 })
  b.insert({ name = "coal", count = 50 })
  return a.train
end

function Lamps.build()
  local s = game.create_surface("utl-selftest-r47")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  -- Strecke 1 (westwärts): Ziel, Leer, Aus. Strecke 2 (ostwärts, y + 20): Depot mit Zug.
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  local target = stop(s, force, "R47-Ziel", -60, LINE - 2, false)
  local empty = stop(s, force, "R47-Leer", 60, LINE + 2, true)
  local off = stop(s, force, "R47-Aus", 30, LINE + 2, true)
  local own = stop(s, force, "R47-Eigen", -30, LINE - 2, false)
  local c = s.create_entity({ name = "constant-combinator", position = { 33.5, LINE + 7.5 }, force = force }) --[[@as LuaEntity]]
  c.get_wire_connector(W.circuit_red, true).connect_to(off.get_wire_connector(W.circuit_red, true))
  local behavior = off.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
  behavior.circuit_enable_disable = true
  behavior.circuit_condition = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 0 }
  local p_target, p_empty, p_off = panel(s, force, target, -1.5), panel(s, force, empty, 1.5), panel(s, force, off, 1.5)
  -- eigenes Feld: hat schon eine Nachricht → UTL lässt es in Ruhe
  local p_own = panel(s, force, own, -1.5)
  local own_behavior = p_own.get_or_create_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
  own_behavior.records = { { text = "eigen", icon = { type = "virtual", name = "signal-pink" },
    condition = { first_signal = { type = "virtual", name = "signal-check" }, comparator = "=", constant = 0 } } }
  -- Depot auf eigener Strecke
  local y2 = LINE + 20
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, y2 }, direction = 4, force = force }) end
  local depot = stop(s, force, "R47-Depot", 20, y2 + 2, true)
  remote.call("utl", "configure_station", depot.unit_number, { mode = "depot", network = "R47" })
  local p_depot = panel(s, force, depot, 1.5)
  local d1 = s.create_entity({ name = "locomotive", position = { 4, y2 }, direction = 4, force = force }) --[[@as LuaEntity]]
  local d2 = s.create_entity({ name = "locomotive", position = { -3, y2 }, direction = 12, force = force }) --[[@as LuaEntity]]
  d1.insert({ name = "coal", count = 50 })
  d2.insert({ name = "coal", count = 50 })
  local schedule = d1.train.get_schedule()
  schedule.add_record({ station = "R47-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  d1.train.manual_mode = false
  local train = loco_pair(s, force, 4, 12)
  return { start = game.tick, train = train, target = target, empty = empty, p_target = p_target, p_empty = p_empty,
    p_off = p_off, p_own = p_own, p_depot = p_depot }
end

--- Liefert true, wenn R47 fertig ist.
function Lamps.watch(r, check)
  if not r or r.done then return true end
  -- nach 20 s (Lampen-Runde hat alle Stationen gesehen) prüfen und den Zug losschicken
  if not r.sent and game.tick - r.start > 1200 then
    r.sent = game.tick
    check("R47 anzeigefeld nichts los = gelb", panel_color(r.p_empty) == "yellow", tostring(panel_color(r.p_empty)))
    check("R47 anzeigefeld ausgeschaltet = rot", panel_color(r.p_off) == "red", tostring(panel_color(r.p_off)))
    check("R47 anzeigefeld depot mit zug = türkis", panel_color(r.p_depot) == "cyan", tostring(panel_color(r.p_depot)))
    check("R47 eigenes anzeigefeld bleibt unberührt", panel_color(r.p_own) == "pink", tostring(panel_color(r.p_own)))
    if settings.startup["utl-station-lamps"].value then
      check("R47 lampen: zwei je utl-haltestelle", lamp_count(r.empty) == 2, tostring(lamp_count(r.empty)))
    else
      check("R47 lampen aus (start-einstellung): keine lampen", lamp_count(r.empty) == 0, tostring(lamp_count(r.empty)))
    end
    local schedule = r.train.get_schedule()
    schedule.add_record({ station = "R47-Ziel", wait_conditions = { { type = "time", ticks = 36000 } } })
    schedule.go_to_station(1)
    r.train.manual_mode = false
  end
  if r.sent and not r.blue and r.train.valid and r.train.state == defines.train_state.on_the_path then
    r.blue = panel_color(r.p_target) or "keine"
  end
  if r.sent and r.train.valid and r.train.state == defines.train_state.wait_station then
    r.done = true
    check("R47 anzeigefeld zug kommt = blau", r.blue == "blue", tostring(r.blue))
    check("R47 anzeigefeld zug steht da = grün", panel_color(r.p_target) == "green", tostring(panel_color(r.p_target)))
    local behavior = r.p_target.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
    local text = behavior.get_record(1).text or ""
    check("R47 anzeigefeld nennt die zug-nummer", text:find("#" .. r.train.id, 1, true) ~= nil, text)
  elseif game.tick - r.start > 20000 then
    r.done = true
    check("R47 anzeige", false, serpent.line({ geschickt = r.sent, blau = r.blue, zug = r.train.valid and r.train.state }))
  end
  return r.done
end

return Lamps
