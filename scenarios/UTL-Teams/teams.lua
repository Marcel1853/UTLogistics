--- Szenario „UTL-Teams“: vier eigenständige City-Block-Raster (je 2 × 2) auf einer Karte, jedes
--- einem Team. Die Raster berühren sich nicht – zwischen ihnen liegt eine Lücke, kein Gleis führt
--- hinüber. Eines der vier Teams ist das Standard-Team („player“).
--- Alle vier benutzen mit Absicht dieselben Stationsnamen („Depot“, „Anbieter“, „Abnehmer“,
--- „Tankstelle“, „Cleanup“) und denselben Netznamen „Eisen“: UTL muss sie trotzdem auseinander-
--- halten, denn Fahrpläne kennen nur Namen, kein Team.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local Teams = {}

Teams.SURFACE = "utl-teams"

local STEP = 768 -- Abstand der Raster (Raster ist 448 breit, dazwischen 320 Felder Lücke)

Teams.LIST = {
  { force = "player", label = "Standard", item = "iron-plate", origin = { 0, 0 } },
  { force = "rot", label = "Rot", item = "copper-plate", origin = { STEP, 0 } },
  { force = "blau", label = "Blau", item = "coal", origin = { 0, STEP } },
  { force = "gruen", label = "Grün", item = "stone", origin = { STEP, STEP } },
}

local NETWORK = "Eisen" -- gleicher Netzname bei allen: die Trennung muss über das Team laufen

--- Teams anlegen, alles erforschen, untereinander Frieden.
function Teams.create()
  local list = {}
  for _, team in ipairs(Teams.LIST) do
    local force = game.forces[team.force] or game.create_force(team.force)
    force.research_all_technologies()
    list[#list + 1] = force
  end
  for _, a in ipairs(list) do
    for _, b in ipairs(list) do
      if a ~= b then
        a.set_friend(b, true)
        a.set_cease_fire(b, true)
      end
    end
  end
  return list
end

--- Stationen eines Teams – bei allen Teams die gleichen Namen.
local function wanted(team)
  local list = {}
  local function add(kind, name, extra)
    local spec = { kind = kind, network = NETWORK, item = team.item, name = name }
    for key, value in pairs(extra or {}) do spec[key] = value end
    list[#list + 1] = spec
  end
  add("depot", "Depot", { cars = 2, item = nil })
  add("depot", "Depot", { cars = 2, item = nil })
  add("provider", "Anbieter")
  add("requester", "Abnehmer 1")
  add("requester", "Abnehmer 2")
  add("fuel", "Tankstelle", { item = nil })
  add("cleanup", "Cleanup", { item = nil })
  return list
end

--- Plätze des Rasters der Reihe nach belegen (die Liste ist zeilenweise sortiert).
local function assign_for(team)
  return function(places)
    local specs = {}
    local specs_list = wanted(team)
    local step = math.max(1, math.floor(#places / #specs_list))
    for i, spec in ipairs(specs_list) do
      local j = math.min(#places, 1 + (i - 1) * step)
      while specs[j] do j = j % #places + 1 end
      specs[j] = spec
    end
    return specs
  end
end

local function configure(spec)
  local unit = (spec.combinator_entity or spec.stop).unit_number
  if spec.kind == "depot" then
    remote.call("utl", "configure_station", unit, { mode = "depot" })
  elseif spec.kind == "fuel" then
    remote.call("utl", "configure_station", unit, { mode = "fuel" })
  elseif spec.kind == "cleanup" then
    remote.call("utl", "configure_station", unit, { mode = "cleanup" })
  elseif spec.kind == "provider" then
    remote.call("utl", "configure_station", unit, { mode = "station", provide = true, request = false, max_trains = 2 })
  elseif spec.kind == "requester" then
    remote.call("utl", "configure_station", unit,
      { mode = "station", provide = false, request = true, request_threshold = 500, max_trains = 1 })
    remote.call("utl", "set_request", unit, 1, { type = "item", name = spec.item }, 4000)
  end
  remote.call("utl", "configure_station", unit, { network = NETWORK })
end

-- Rechtsvektor je Fahrtrichtung der Haltestelle (Anzeigefeld zwischen Nebengleis und Hauptgleis)
local RIGHT = { [0] = { 1, 0 }, [4] = { 0, 1 }, [8] = { -1, 0 }, [12] = { 0, -1 } }

--- Ein Schild am ersten Depot des Teams.
local function sign(spec, team)
  local stop = spec.stop
  local r = RIGHT[stop.direction] or RIGHT[0]
  Signs.place(stop.surface, { stop.position.x - 5 * r[1], stop.position.y - 5 * r[2] },
    "teams-" .. team.force, { type = "virtual", name = "utl-network" })
end

--- Alle vier Raster bauen. Liefert Oberfläche, Startpunkte je Team und die Kartenbereiche.
function Teams.setup()
  Teams.create()
  local result = { starts = {}, areas = {}, stations = 0, trains = 0, rails = 0, failed = 0 }
  for _, team in ipairs(Teams.LIST) do
    local built = Builder.build({
      surface = Teams.SURFACE, grid = 2, depots = {},
      origin = team.origin, force = team.force, assign = assign_for(team),
    })
    result.surface = built.surface
    local signed = false
    for _, spec in ipairs(built.stations) do
      configure(spec)
      if spec.kind == "depot" then
        if not signed then
          sign(spec, team)
          signed = true
        end
        if not result.starts[team.force] then
          result.starts[team.force] = { x = spec.stop.position.x, y = spec.stop.position.y - 6 }
        end
      end
    end
    result.areas[#result.areas + 1] = built.areas[1]
    result.stations = result.stations + #built.stations
    result.trains = result.trains + #built.trains
    result.rails = result.rails + built.stats.rails
    result.failed = result.failed + built.stats.failed
    log(("[TEAMS] %s: %d Stationen, %d Züge bei %d/%d")
      :format(team.force, #built.stations, #built.trains, team.origin[1], team.origin[2]))
  end
  log(("[TEAMS] gesamt: %d Stationen, %d Züge, Gleise %d (%d fehlgeschlagen)")
    :format(result.stations, result.trains, result.rails, result.failed))
  return result
end

return Teams
