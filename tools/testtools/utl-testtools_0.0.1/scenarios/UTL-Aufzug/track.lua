--- Gleisleger: baut Gleise Stück für Stück an ein offenes Gleisende an – mit denselben Bauangaben,
--- die das Spiel dem Gleisplaner gibt (LuaRailEnd.get_rail_extensions). So passen die Gleise auch an
--- die Innengleise des Weltraumaufzugs, ohne dass Koordinaten geraten werden müssen.
---
--- Ein „Läufer“ ist { e = LuaRailEnd (zeigt in Fahrtrichtung), surface, force, planner }.
local Track = {}

local CONN = defines.rail_connection_direction
local RAIL_TYPES = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
  "legacy-straight-rail", "legacy-curved-rail" }

-- rechts von der Fahrtrichtung (nur die vier Hauptrichtungen)
local RIGHT = {
  [defines.direction.north] = { 1, 0 }, [defines.direction.east] = { 0, 1 },
  [defines.direction.south] = { -1, 0 }, [defines.direction.west] = { 0, -1 },
}

local function same(a, b)
  return math.abs(a.x - b.x) < 0.01 and math.abs(a.y - b.y) < 0.01
end

--- Offene Gleisenden (ohne Anschluss) im Quadrat um `center`.
function Track.open_ends(surface, center, radius)
  local found = {}
  local rails = surface.find_entities_filtered({ type = RAIL_TYPES,
    area = { { center.x - radius, center.y - radius }, { center.x + radius, center.y + radius } } })
  for _, rail in pairs(rails) do
    for _, side in pairs({ defines.rail_direction.front, defines.rail_direction.back }) do
      local e = rail.get_rail_end(side)
      local connected = false
      for _, c in pairs({ CONN.straight, CONN.left, CONN.right }) do
        if e.make_copy().move_forward(c) then
          connected = true
          break
        end
      end
      if not connected then found[#found + 1] = e end
    end
  end
  return found
end

function Track.walker(e, surface, force, planner)
  return { e = e, surface = surface, force = force, planner = planner, built = 0 }
end

--- Ein Gleisstück ansetzen. `turn` = 0 geradeaus, -1 links, 1 rechts (je 22,5°). Liefert true bei Erfolg.
function Track.step(w, turn)
  local want = (w.e.location.direction + turn) % 16
  for _, ext in pairs(w.e.get_rail_extensions(w.planner)) do
    if ext.goal.direction == want then
      local rail = w.surface.create_entity({ name = ext.name, position = ext.position, direction = ext.direction,
        force = w.force })
      if not rail then return false end
      w.built = w.built + 1
      for _, c in pairs({ CONN.straight, CONN.left, CONN.right }) do
        local copy = w.e.make_copy()
        if copy.move_forward(c) and copy.location.direction == want and same(copy.location.position, ext.goal.position) then
          w.e = copy
          return true
        end
      end
      return false
    end
  end
  return false
end

--- `n` gerade Stücke (je 2 Felder).
function Track.straight(w, n)
  for _ = 1, n do
    if not Track.step(w, 0) then return false end
  end
  return true
end

--- Um 90° abbiegen (`side` = -1 links, 1 rechts): vier Schritte zu 22,5°.
function Track.turn(w, side)
  for _ = 1, 4 do
    if not Track.step(w, side) then return false end
  end
  return true
end

--- Signal für die Fahrtrichtung am aktuellen Ende (rechts neben dem Gleis).
function Track.signal(w)
  local loc = w.e.out_signal_location
  return w.surface.create_entity({ name = "rail-signal", position = loc.position, direction = loc.direction,
    force = w.force }) ~= nil
end

--- UTL-Haltestelle rechts neben dem aktuellen Ende, für die Fahrtrichtung.
function Track.stop(w, name)
  local loc = w.e.location
  local right = RIGHT[loc.direction]
  if not right then return nil end
  local stop = w.surface.create_entity({ name = "utl-train-stop", force = w.force, direction = loc.direction,
    position = { loc.position.x + 2 * right[1], loc.position.y + 2 * right[2] }, raise_built = true })
  if stop then stop.backer_name = name end
  return stop
end

--- Geradeaus bis zum Gleisende `goal` (zeigt uns entgegen). Liefert true, wenn beide verbunden sind.
function Track.close(w, goal, limit)
  for _ = 1, limit do
    if same(w.e.location.position, goal.location.position) then break end
    if not Track.step(w, 0) then return false end
  end
  if not same(w.e.location.position, goal.location.position) then return false end
  -- hinter der Einfahrt kann eine Kurve folgen: jede Anschlussrichtung zählt
  for _, c in pairs({ CONN.straight, CONN.left, CONN.right }) do
    if w.e.make_copy().move_forward(c) then return true end
  end
  return false
end

return Track
