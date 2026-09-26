--- Szenario „UTL-Nachladen“: Aufbau und alles, was in der Welt zu sehen ist.
--- Ein City Block mit Depot (1 Zug, 2 Wagen), Anbieter (Eisen) und Abnehmer. Dazu Anzeigefelder
--- mit Erklärung und schwebende Texte: über dem Zug seine Ladeliste, über dem Abnehmer sein Bedarf.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local World = {}

World.SURFACE = "utl-nachladen"
World.KEY = "item|iron-plate|normal"

local STATIONS = {
  { kind = "depot", name = "Depot", network = "Demo", cars = 2 },
  { kind = "provider", name = "Anbieter", network = "Demo", item = "iron-plate" },
  { kind = "requester", name = "Abnehmer", network = "Demo", item = "iron-plate" },
}

--- Die drei Stationen gleichmäßig über die Plätze des Blocks verteilen.
local function assign(places)
  local specs = {}
  local step = math.max(1, math.floor(#places / #STATIONS))
  for i, spec in ipairs(STATIONS) do specs[1 + (i - 1) * step] = spec end
  return specs
end

-- Rechtsvektor je Fahrtrichtung der Haltestelle (Anzeigefeld zwischen Nebengleis und Hauptgleis)
local RIGHT = { [0] = { 1, 0 }, [4] = { 0, 1 }, [8] = { -1, 0 }, [12] = { 0, -1 } }

local function sign(stop, key)
  local r = RIGHT[stop.direction] or RIGHT[0]
  Signs.place(stop.surface, { stop.position.x - 5 * r[1], stop.position.y - 5 * r[2] }, key,
    { type = "item", name = "iron-plate" })
end

--- Schwebender Text, der `target` folgt (Entity oder Position).
local function label(surface, target, text, color)
  return rendering.draw_text({
    text = text, surface = surface, target = target, color = color or { 1, 1, 1 },
    scale = 2, font = "default-large-bold", alignment = "center", vertical_alignment = "bottom",
    use_rich_text = true, scale_with_zoom = true,
  })
end

--- Alles bauen und einstellen. Liefert die Teile, die der Ablauf braucht.
function World.build()
  local built = Builder.build({ surface = World.SURFACE, grid = 1, depots = {}, assign = assign })
  local result = { surface = built.surface, area = built.areas[1] }
  for _, spec in ipairs(built.stations) do
    local unit = (spec.combinator_entity or spec.stop).unit_number
    if spec.kind == "depot" then
      remote.call("utl", "configure_station", unit, { mode = "depot", network = "Demo" })
      sign(spec.stop, "demo-depot")
      result.depot = spec.stop
    elseif spec.kind == "provider" then
      remote.call("utl", "configure_station", unit,
        { mode = "station", provide = true, request = false, network = "Demo" })
      sign(spec.stop, "demo-provider")
      result.provider = spec.stop
    elseif spec.kind == "requester" then
      remote.call("utl", "configure_station", unit,
        { mode = "station", provide = false, request = true, network = "Demo", request_threshold = 100, max_trains = 1 })
      sign(spec.stop, "demo-requester")
      result.requester, result.requester_unit = spec.stop, unit
    end
  end
  local train = built.trains[1]
  result.locomotive = train and train.front_stock
  -- schwebende Texte: über der Lok die Ladeliste, über dem Abnehmer der Bedarf
  if result.locomotive then
    result.train_label = label(result.surface, { entity = result.locomotive, offset = { 0, -3 } },
      { "utl-demo.train-idle" })
  end
  result.need_label = label(result.surface, { entity = result.requester, offset = { 0, -3 } },
    { "utl-demo.need", 0 })
  return result
end

return World
