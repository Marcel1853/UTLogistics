-- Selbsttest R47 (11.10.2026): farbige Haltestellen-Lampen. Ein Zug fährt zu „R47-Ziel“ (Lampe erst
-- blau, nach der Ankunft grün), „R47-Leer“ ist gelb, „R47-Aus“ ist per Schaltung ausgeschaltet (rot).
-- Eine Vanilla-Haltestelle ohne UTL bekommt keine Lampen.
local Lamps = {}

local W = defines.wire_connector_id
local LINE = 1

local function stop(s, force, name, x, y, east, proto)
  local e = s.create_entity({ name = proto or "utl-train-stop", position = { x, y }, direction = east and 4 or 12,
    force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

--- Farbe der Lampen an `entity` als „blau/grün/gelb/rot“ (nil = keine Lampen), dazu die Anzahl.
local function lamp_color(entity)
  local color, count = nil, 0
  for _, object in pairs(rendering.get_all_objects("UTLogistics")) do
    if object.valid and object.type == "sprite" and object.target.entity == entity then
      count = count + 1
      local c = object.color
      if c.r > 0.8 and c.g < 0.3 then color = "rot"
      elseif c.g > 0.8 and c.r < 0.4 then color = "grün"
      elseif c.b > 0.8 and c.r < 0.4 then color = "blau"
      elseif c.r > 0.8 and c.g > 0.6 then color = "gelb"
      else color = "?" end
    end
  end
  return color, count
end

function Lamps.build()
  local s = game.create_surface("utl-selftest-r47")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  local target = stop(s, force, "R47-Ziel", -60, LINE - 2, false)
  local empty = stop(s, force, "R47-Leer", 60, LINE + 2, true)
  local off = stop(s, force, "R47-Aus", 30, LINE + 2, true)
  local vanilla = stop(s, force, "R47-Vanilla", 0, LINE + 2, true, "train-stop")
  -- „Aus“: per Schaltung ausgeschaltet (Bedingung A > 0, am Kabel liegt nichts an)
  local c = s.create_entity({ name = "constant-combinator", position = { 33.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  c.get_wire_connector(W.circuit_red, true).connect_to(off.get_wire_connector(W.circuit_red, true))
  local behavior = off.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
  behavior.circuit_enable_disable = true
  behavior.circuit_condition = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 0 }
  local l1 = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  local l2 = s.create_entity({ name = "locomotive", position = { 11, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  l1.insert({ name = "coal", count = 50 })
  l2.insert({ name = "coal", count = 50 })
  return { start = game.tick, train = l1.train, target = target, empty = empty, off = off, vanilla = vanilla }
end

--- Liefert true, wenn R47 fertig ist.
function Lamps.watch(r, check)
  if not r or r.done then return true end
  -- nach 5 s (Lampen-Runde hat alle Stationen gesehen) den Zug losschicken
  if not r.sent and game.tick - r.start > 300 then
    r.sent = game.tick
    local color_empty, count_empty = lamp_color(r.empty)
    local color_off = lamp_color(r.off)
    local _, count_vanilla = lamp_color(r.vanilla)
    check("R47 lampen: zwei je utl-haltestelle", count_empty == 2, tostring(count_empty))
    check("R47 lampe nichts los = gelb", color_empty == "gelb", tostring(color_empty))
    check("R47 lampe ausgeschaltet = rot", color_off == "rot", tostring(color_off))
    check("R47 vanilla-haltestelle ohne utl: keine lampen", count_vanilla == 0, tostring(count_vanilla))
    local schedule = r.train.get_schedule()
    schedule.add_record({ station = "R47-Ziel", wait_conditions = { { type = "time", ticks = 36000 } } })
    schedule.go_to_station(1)
    r.train.manual_mode = false
  end
  if r.sent and not r.blue and r.train.valid and r.train.state == defines.train_state.on_the_path then
    r.blue = lamp_color(r.target) or "keine"
  end
  if r.sent and r.train.valid and r.train.state == defines.train_state.wait_station then
    r.done = true
    check("R47 lampe zug kommt = blau", r.blue == "blau", tostring(r.blue))
    check("R47 lampe zug steht da = grün", lamp_color(r.target) == "grün", tostring(lamp_color(r.target)))
  elseif game.tick - r.start > 20000 then
    r.done = true
    check("R47 lampen", false, serpent.line({ geschickt = r.sent, blau = r.blue, zug = r.train.valid and r.train.state }))
  end
  return r.done
end

return Lamps
