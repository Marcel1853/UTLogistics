--- Szenario „UTL-Lager“: Bausteine für die Beispiel-Strecken unterhalb des Rundkurses. Jede Strecke
--- ist ein gerades Gleis (74 Felder) mit Depot in der Mitte, Haltestellen nach Osten rechts und
--- nach Westen links, einem Zug Lok – Wagen – Lok. Maße wie in den Tipps-&-Tricks-Szenen (dort
--- geprüft): Ein Zug an einer Haltestelle bei x steht mit dem Wagen 7–13 Felder dahinter.
local Lines = {}

local W = defines.wire_connector_id
Lines.X0 = 74 -- Mitte der Strecken (gerade Zahl: Gleise liegen dann auf ungeraden x wie in den Tipps)

local surface, force

function Lines.use(s, f) surface, force = s, f end

local function entity(name, x, y, extra)
  local spec = { name = name, position = { Lines.X0 + x, y }, force = force }
  for k, v in pairs(extra or {}) do spec[k] = v end
  return surface.create_entity(spec)
end
Lines.entity = entity

function Lines.rails(line)
  for x = -37, 37, 2 do entity("straight-rail", x, line, { direction = 4 }) end
end

--- Haltestelle: nach Osten (`east`) südlich des Gleises, nach Westen nördlich.
function Lines.stop(line, name, x, east)
  local e = entity("utl-train-stop", x, line + (east and 2 or -2), { direction = east and 4 or 12, raise_built = true })
  e.backer_name = name
  return e
end

--- Spalten der Wagenplätze einer Haltestelle (zwei Greifarme wie in den Tipps).
function Lines.columns(x, east)
  if east then return { x - 10.5, x - 8.5 } end
  return { x + 8.5, x + 10.5 }
end

--- Strom und Kabel zur Haltestelle: Mast neben den Kisten, Zwischenmast Richtung Haltestelle.
--- Liefert Mast und Zwischenmast (für rote Kabel der Auftrags-Ausgabe).
function Lines.power(stop, first_chest, line, south)
  local d = south and 1 or -1
  local cy = first_chest.position.y
  local cx = first_chest.position.x - Lines.X0
  local pole = entity("medium-electric-pole", cx - 1, cy + d)
  -- links neben den Mast, damit hinter den Kisten Platz für Abflüsse bleibt
  local eei = entity("electric-energy-interface", cx - 3, cy + 2 * d)
  eei.power_production = 100000
  eei.electric_buffer_size = 1000000
  local relay = entity("medium-electric-pole", (cx + stop.position.x - Lines.X0) / 2, cy + d)
  local G = W.circuit_green
  first_chest.get_wire_connector(G, true).connect_to(pole.get_wire_connector(G, true))
  pole.get_wire_connector(G, true).connect_to(relay.get_wire_connector(G, true))
  relay.get_wire_connector(G, true).connect_to(stop.get_wire_connector(G, true))
  return pole, relay
end

--- Kisten mit Greifarmen am Wagenplatz. `load` = Kiste → Wagen, sonst Wagen → Kiste.
--- `kind`: "steel-chest" oder "infinity-chest"; `fill` = { Ware = Menge } je Kiste (Unendlich-Kiste:
--- Filter, Stahlkiste: Inhalt); `void` = Unendlich-Kiste, die alles vernichtet.
function Lines.bay(stop, line, xs, load, kind, fill, void)
  local south = stop.position.y > line
  local y = line + (south and 1.5 or -1.5)
  local chest_y = y + (south and 1 or -1)
  local chests, inserters = {}, {}
  for i, x in ipairs(xs) do
    inserters[i] = entity("bulk-inserter", x, y, { direction = load == south and 8 or 0 })
    local chest = entity(kind, x, chest_y)
    local f = fill and (fill[i] or fill[1])
    if f and kind == "infinity-chest" then
      local filters = {}
      for name, count in pairs(f) do filters[#filters + 1] = { index = #filters + 1, name = name, count = count, mode = "at-least" } end
      chest.infinity_container_filters = filters
    elseif f then
      for name, count in pairs(f) do chest.insert({ name = name, count = count }) end
    elseif void then
      chest.remove_unfiltered_items = true
    end
    if chests[i - 1] then
      chests[i - 1].get_wire_connector(W.circuit_green, true).connect_to(chest.get_wire_connector(W.circuit_green, true))
    end
    chests[i] = chest
  end
  local pole, relay = Lines.power(stop, chests[1], line, south)
  return { chests = chests, inserters = inserters, pole = pole, relay = relay, south = south, chest_y = chest_y }
end

--- Abfluss hinter jeder Kiste (langsamer Greifarm in eine Kiste, die alles vernichtet).
function Lines.drains(bay)
  local d = bay.south and 1 or -1
  for _, chest in ipairs(bay.chests) do
    local x = chest.position.x - Lines.X0
    entity("inserter", x, bay.chest_y + d, { direction = bay.south and 0 or 8 })
    local void = entity("infinity-chest", x, bay.chest_y + 2 * d)
    void.remove_unfiltered_items = true
  end
end

--- Zug Lok – Wagen – Lok mit genug Kohle für das Szenario (die Strecken haben keine Tankstelle).
function Lines.train(line, x, depot_name)
  local l1 = entity("locomotive", x, line, { direction = 4 })
  local wagon = surface.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, line }, direction = 4, force = force })
  local l2 = surface.create_entity({ name = "locomotive", position = { wagon.position.x - 7, line }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = depot_name, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  return l1.train, wagon
end

return Lines
