--- Szenario „UTL-Aktiver-Anbieter“: Aufbau. Ein City Block mit Depot (2 Züge mit je 4 Wagen), aktivem Anbieter,
--- Abnehmer, Lager, Cleanup und Tankstelle. Anbieter, Abnehmer und Lager haben **echte Kisten**
--- (man sieht, wie der Anbieter leer wird und wohin die Ware geht); nur das Cleanup vernichtet.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local World = {}

World.SURFACE = "utl-aktiver-anbieter"
World.ITEM = "iron-plate"
World.SUPPLY = 6000      -- so viel Eisen liegt zu Beginn jeder Runde beim aktiven Anbieter
World.REQUEST = 1000     -- so viel braucht der Abnehmer
World.STORAGE_MIN, World.STORAGE_MAX = 500, 2000
World.STORAGE_START = 1000 -- Lager liegt über dem Mindest: normale Anbieter füllen es nicht auf

local NET = "Aktiv"
local STATIONS = {
  { kind = "depot", name = "Depot", network = NET, cars = 4 },
  { kind = "provider", name = "Aktiver Anbieter", network = NET, item = World.ITEM },
  { kind = "requester", name = "Abnehmer", network = NET, item = World.ITEM },
  { kind = "storage", name = "Lager", network = NET },
  { kind = "cleanup", name = "Cleanup", network = NET },
  { kind = "fuel", name = "Tankstelle", network = NET },
  { kind = "depot", name = "Depot", network = NET, cars = 4 },
}

local function assign(places)
  local specs = {}
  for i, spec in ipairs(STATIONS) do
    if places[i] then specs[i] = spec end
  end
  return specs
end

-- Rechtsvektor je Fahrtrichtung der Haltestelle (Anzeigefeld zwischen Nebengleis und Hauptgleis)
local RIGHT = { [0] = { 1, 0 }, [4] = { 0, 1 }, [8] = { -1, 0 }, [12] = { 0, -1 } }

local function sign(stop, key)
  local r = RIGHT[stop.direction] or RIGHT[0]
  Signs.place(stop.surface, { stop.position.x - 5 * r[1], stop.position.y - 5 * r[2] }, key,
    { type = "item", name = World.ITEM })
end

--- Schwebender Text über einer Haltestelle.
local function label(surface, stop)
  return rendering.draw_text({
    text = "", surface = surface, target = { entity = stop, offset = { 0, -3 } }, color = { 1, 1, 1 },
    scale = 3, font = "default-large-bold", alignment = "center", vertical_alignment = "bottom",
    use_rich_text = true, scale_with_zoom = false,
  })
end

--- Kisten an einer Haltestelle: alle Kisten im Umkreis, die per grünem Draht an ihr hängen.
local function chests_of(surface, stop)
  local net = stop.get_circuit_network(defines.wire_connector_id.circuit_green)
  local id = net and net.network_id
  local list = {}
  local p = stop.position
  for _, chest in pairs(surface.find_entities_filtered({ type = { "container", "infinity-container" },
    area = { { p.x - 40, p.y - 40 }, { p.x + 40, p.y + 40 } } })) do
    local chest_net = chest.get_circuit_network(defines.wire_connector_id.circuit_green)
    if id and chest_net and chest_net.network_id == id then list[#list + 1] = chest end
  end
  return list
end

--- Unendlich-Kisten des Baukastens zu gewöhnlichen Kisten machen (kein Nachschub, nichts verschwindet).
local function plain(chests)
  for _, chest in ipairs(chests) do
    if chest.type == "infinity-container" then
      chest.infinity_container_filters = {}
      chest.remove_unfiltered_items = false
    end
  end
end

local function cfg(unit, changes)
  changes.network = NET
  remote.call("utl", "configure_station", unit, changes)
end

--- Alles bauen und einstellen. Liefert die Teile, die der Ablauf braucht.
function World.build()
  local built = Builder.build({ surface = World.SURFACE, grid = 1, depots = {}, assign = assign })
  local s = built.surface
  local w = { surface = s, area = built.areas[1], trains = built.trains, wire = {} }
  for _, spec in ipairs(built.stations) do
    local unit = (spec.combinator_entity or spec.stop).unit_number
    if spec.kind == "depot" then
      cfg(unit, { mode = "depot" })
      sign(spec.stop, "aktiv-depot")
    elseif spec.kind == "provider" then
      cfg(unit, { mode = "station", provide = true, request = false, active_provider = true, provide_threshold = 1,
        filter_load = false })
      w.provider, w.provider_chests = spec.stop, chests_of(s, spec.stop)
      plain(w.provider_chests)
      sign(spec.stop, "aktiv-provider")
    elseif spec.kind == "requester" then
      cfg(unit, { mode = "station", provide = false, request = true, request_threshold = 100, max_trains = 1 })
      remote.call("utl", "set_request", unit, 1, { type = "item", name = World.ITEM }, World.REQUEST)
      w.requester, w.requester_chests = spec.stop, chests_of(s, spec.stop)
      plain(w.requester_chests)
      sign(spec.stop, "aktiv-requester")
    elseif spec.kind == "storage" then
      cfg(unit, { mode = "storage", storage = { accept_leftover = false, limits = {
        { signal = { type = "item", name = World.ITEM }, min = World.STORAGE_MIN, max = World.STORAGE_MAX } } } })
      w.storage, w.storage_chests = spec.stop, chests_of(s, spec.stop)
      if spec.bay then w.wire[#w.wire + 1] = { stop = spec.stop, pole = spec.bay.poles[1] } end
      sign(spec.stop, "aktiv-storage")
    elseif spec.kind == "cleanup" then
      cfg(unit, { mode = "cleanup" })
      w.cleanup = spec.stop
      sign(spec.stop, "aktiv-cleanup")
    elseif spec.kind == "fuel" then
      cfg(unit, { mode = "fuel" })
      sign(spec.stop, "aktiv-fuel")
    end
  end
  w.labels = {
    provider = w.provider and label(s, w.provider),
    requester = w.requester and label(s, w.requester),
    storage = w.storage and label(s, w.storage),
    cleanup = w.cleanup and label(s, w.cleanup),
  }
  return w
end

--- Lade-/Entlade-Greifarme des Lagers an seine Auftrags-Ausgabe (die entsteht erst nach dem Bau).
--- Liefert die Einträge, die noch warten.
function World.wire_outputs(list)
  local pending = {}
  for _, entry in ipairs(list or {}) do
    local stop, pole = entry.stop, entry.pole
    if stop.valid and pole and pole.valid then
      local p = stop.position
      local output = stop.surface.find_entities_filtered({ name = "utl-station-output",
        area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } } })[1]
      if output then
        output.get_wire_connector(defines.wire_connector_id.circuit_red, true)
          .connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red, true))
      else
        pending[#pending + 1] = entry
      end
    end
  end
  return pending
end

--- Eisen in einer Kistenliste.
function World.count(chests)
  local n = 0
  for _, chest in pairs(chests or {}) do
    if chest.valid then n = n + chest.get_item_count(World.ITEM) end
  end
  return n
end

--- Kisten auf genau `amount` Eisen bringen (gleichmäßig verteilt).
function World.set(chests, amount)
  local list = {}
  for _, chest in pairs(chests or {}) do
    if chest.valid then list[#list + 1] = chest end
  end
  for _, chest in ipairs(list) do chest.clear_items_inside() end
  if #list == 0 or amount <= 0 then return end
  local each = math.ceil(amount / #list)
  for _, chest in ipairs(list) do
    local n = math.min(each, amount)
    if n > 0 then amount = amount - chest.insert({ name = World.ITEM, count = n }) end
  end
end

return World
