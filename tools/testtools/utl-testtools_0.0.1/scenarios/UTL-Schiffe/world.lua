--- Szenario „UTL-Schiffe“: Marcels Rundkurs (derselbe wie in „UTL-Beispiele“) als Wasserweg.
--- Wasser liegt nur unter den Wasserwegen – so stehen Greifarme und Kisten direkt am Ufer.
--- Signale werden Bojen, Haltestellen UTL-Häfen; die Kombinatoren des Rundkurses fallen weg.
local Ring = require("__UTLogistics__/scenarios/UTL-Beispiele/rundkurs")

local World = {}

local RAILS = { S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail" }
local WATER = { S = "straight-waterway", A = "curved-waterway-a", B = "curved-waterway-b", H = "half-diagonal-waterway" }
local SIGNALS = { G = "buoy", K = "chain_buoy" }

--- Rundkurs bauen. Liefert { ports = { ["x/y"] = Hafen }, failed = Zahl }.
function World.build(surface, force)
  local failed = 0
  -- 1. Wo liegt Wasser? Jedes Gleisstück einmal an Land setzen, seine Fläche merken, wieder weg.
  local water, tiles = {}, {}
  for _, e in ipairs(Ring) do
    if RAILS[e[1]] then
      local rail = surface.create_entity({ name = RAILS[e[1]], position = { e[2], e[3] }, direction = e[4], force = force })
      if rail then
        local box = rail.bounding_box
        for x = math.floor(box.left_top.x), math.ceil(box.right_bottom.x) - 1 do
          for y = math.floor(box.left_top.y), math.ceil(box.right_bottom.y) - 1 do
            local key = x .. "/" .. y
            if not water[key] then
              water[key] = true
              tiles[#tiles + 1] = { name = "water", position = { x, y } }
            end
          end
        end
        rail.destroy()
      end
    end
  end
  surface.set_tiles(tiles)
  -- 2. Erst alle Wasserwege, dann Bojen und Häfen (eine Boje ohne Weg rutscht sonst weg)
  local ports = {}
  for _, only_ways in ipairs({ true, false }) do
    for _, e in ipairs(Ring) do
      local kind = e[1]
      if (WATER[kind] ~= nil) == only_ways then
        local name = WATER[kind] or SIGNALS[kind] or ((kind == "T" or kind == "V") and "utl-port") or nil
        if name then
          local made = surface.create_entity({ name = name, position = { e[2], e[3] }, direction = e[4], force = force,
            raise_built = name == "utl-port" })
          if not made then
            failed = failed + 1
          elseif name == "utl-port" then
            ports[e[2] .. "/" .. e[3]] = made
          end
        end
      end
    end
  end
  return { ports = ports, failed = failed, water = #tiles }
end

return World
