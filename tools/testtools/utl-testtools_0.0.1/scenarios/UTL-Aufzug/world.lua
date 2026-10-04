--- Aufbau je Seite des Weltraumaufzugs: eine Einbahn-Schleife von der Ausfahrt (Osten) zurück zur
--- Einfahrt (Westen), oben mit Depots (Fahrtrichtung West), unten mit Anbieter/Abnehmer (Fahrtrichtung
--- Ost, direkt vor dem Aufzug). Züge fahren nur im Kreis – Wenden ist nicht nötig.
---
---      ┌──────── Depots ◄──────────┐
---      │                            │
---      └─► Abnehmer ─► Anbieter ─► [Aufzug] ─► Ausfahrt ┘
local Track = require("__utl-testtools__/scenarios/UTL-Aufzug/track")

local World = {}

local TOP = 90 -- gerade Stücke oben (je 2 Felder)
local SIDE = 14 -- gerade Stücke nach Norden bzw. Süden (über den Aufzug hinweg)
local STATION = 18 -- gerade Stücke vor jeder Haltestelle (Zug mit 4 Fahrzeugen = 28 Felder)

--- Einfahrt und Ausfahrt des Aufzugs: die offenen Gleisenden am westlichen und östlichen Rand.
function World.elevator_ends(surface, center)
  local entrance, exit = nil, nil
  for _, e in pairs(Track.open_ends(surface, center, 14)) do
    local p = e.location.position
    if p.x < center.x - 9 then entrance = e elseif p.x > center.x + 9 then exit = e end
  end
  return entrance, exit
end

--- Schleife bauen. `layout` = { top = { Namen der Depots }, bottom = { Namen der Stationen } }.
--- Liefert { stops = { { name, stop } … }, ok = bool, info = Text }.
function World.loop(surface, force, center, planner, layout)
  local entrance, exit = World.elevator_ends(surface, center)
  if not (entrance and exit) then return { stops = {}, ok = false, info = "Aufzug-Gleisenden nicht gefunden" } end
  local w = Track.walker(exit, surface, force, planner)
  local stops = {}
  local function fail(where) return { stops = stops, ok = false, info = where .. " (gebaut " .. w.built .. ")" } end
  if not Track.straight(w, 4) then return fail("Ausfahrt") end
  Track.signal(w)
  if not Track.turn(w, -1) then return fail("Kurve nach Norden") end
  if not Track.straight(w, SIDE) then return fail("nach Norden") end
  Track.signal(w)
  if not Track.turn(w, -1) then return fail("Kurve nach Westen") end
  local used = 0
  for _, name in ipairs(layout.top) do
    if not Track.straight(w, STATION) then return fail("oben vor " .. name) end
    used = used + STATION
    stops[#stops + 1] = { name = name, stop = Track.stop(w, name) }
    Track.signal(w)
  end
  if not Track.straight(w, TOP - used) then return fail("oben") end
  if not Track.turn(w, -1) then return fail("Kurve nach Süden") end
  if not Track.straight(w, SIDE) then return fail("nach Süden") end
  Track.signal(w)
  if not Track.turn(w, -1) then return fail("Kurve nach Osten") end
  if math.abs(w.e.location.position.y - entrance.location.position.y) > 0.01 then
    return fail("Höhe passt nicht: " .. w.e.location.position.y .. " statt " .. entrance.location.position.y)
  end
  for _, name in ipairs(layout.bottom) do
    if not Track.straight(w, STATION) then return fail("unten vor " .. name) end
    stops[#stops + 1] = { name = name, stop = Track.stop(w, name) }
    Track.signal(w)
  end
  if not Track.close(w, entrance, 200) then return fail("Anschluss an die Einfahrt") end
  return { stops = stops, ok = true, info = "gebaut " .. w.built }
end

--- Zug (Lok – 2 Wagen – Lok) an einer Depot-Haltestelle oben (Fahrtrichtung West), Fahrplan: Depot.
function World.train(stop, fuel)
  local surface, force = stop.surface, stop.force
  local y = stop.position.y + 2 -- Gleis unter der Haltestelle (rechts von Fahrtrichtung West = Norden)
  local x = stop.position.x
  local l1 = surface.create_entity({ name = "locomotive", position = { x + 4, y }, direction = defines.direction.west, force = force })
  if not l1 then return nil end
  surface.create_entity({ name = "cargo-wagon", position = { x + 11, y }, direction = defines.direction.west, force = force })
  surface.create_entity({ name = "cargo-wagon", position = { x + 18, y }, direction = defines.direction.west, force = force })
  local l2 = surface.create_entity({ name = "locomotive", position = { x + 25, y }, direction = defines.direction.east, force = force })
  for _, loco in pairs({ l1, l2 }) do if loco then loco.insert({ name = fuel, count = 50 }) end end
  local train = l1.train
  local schedule = train.get_schedule()
  schedule.add_record({ station = stop.backer_name, wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  train.manual_mode = false
  return train
end

--- Greifarme und Kisten an die Wagen eines Zugs, der an `stop` hält (einmal je Haltestelle).
--- `load` = true: Endlos-Kiste mit `item` → Wagen; sonst Wagen → Kiste, die alles vernichtet.
--- Die Seite gegenüber der Haltestelle bleibt frei für Greifarme; Strom aus einer Energie-Schnittstelle.
function World.dock(stop, train, load, item)
  local surface, force = stop.surface, stop.force
  local rail_y = stop.position.y + (stop.direction == defines.direction.east and -2 or 2)
  local side = stop.direction == defines.direction.east and -1 or 1 -- gegenüber der Haltestelle
  local built = 0
  local last_pole = nil
  for _, wagon in pairs(train.cargo_wagons) do
    local cx = math.floor(wagon.position.x) + 0.5
    for _, dx in pairs({ -2, 0, 2 }) do
      local ix, iy = cx + dx, rail_y + side * 1.5
      local chest = surface.create_entity({ name = "infinity-chest", position = { ix, rail_y + side * 2.5 }, force = force })
      local arm = surface.create_entity({ name = "bulk-inserter", position = { ix, iy }, force = force })
      if chest and arm then
        -- Greifarm so drehen, dass er in die richtige Richtung ablegt
        local drops_to_rail = (arm.drop_position.y - iy) * side < 0
        if drops_to_rail ~= load then arm.direction = (arm.direction + 8) % 16 end
        if load then
          chest.set_infinity_container_filter(1, { name = item, count = 1000, mode = "exactly", index = 1 })
        else
          chest.remove_unfiltered_items = true
        end
        built = built + 1
      end
    end
    -- Strom: Mittelmast neben den Greifarmen, eine Energie-Schnittstelle am ersten Wagen. Masten aus
    -- dem Skript verbinden sich nicht von selbst – Kupferkabel zum vorigen Mast ausdrücklich ziehen.
    local pole = surface.create_entity({ name = "medium-electric-pole", position = { cx + 4, rail_y + side * 1.5 }, force = force })
    if pole and last_pole then
      pole.get_wire_connector(defines.wire_connector_id.pole_copper, true)
        .connect_to(last_pole.get_wire_connector(defines.wire_connector_id.pole_copper, true))
    end
    last_pole = pole or last_pole
  end
  local first = train.cargo_wagons[1]
  if first then
    surface.create_entity({ name = "electric-energy-interface", force = force,
      position = { math.floor(first.position.x) + 5, rail_y + side * 4 } })
  end
  return built
end

return World
