--- Kleine Zugstrecke neben dem Wasser-Rundkurs (Szenario „UTL-Schiffe“), im selben UTL-Netz:
--- zeigt, dass Züge und Schiffe sich nicht in die Quere kommen – UTL schickt nur, wer Anbieter und
--- Abnehmer erreicht. Gerades Gleis, Depot in der Mitte, Anbieter rechts, Abnehmer links, Zug
--- Lok – Wagen – Lok (kann in beide Richtungen fahren). Die Strecke ist so lang, dass der Zug im
--- Depot weit weg von allen Greifarmen steht – sonst zögen sie Kohle aus einer Lok.
local Rail = {}

local W = defines.wire_connector_id
local LINE = 117        -- y des Gleises (ungerade wie im Gleisraster)
local X0 = 74           -- Mitte der Strecke

--- Greifarme an der Wagenposition: `load` = Kiste → Wagen, sonst Wagen → Kiste (vernichtet alles,
--- außer Kohle – steht eine Lok davor, zöge der Greifarm sonst ihren Treibstoff heraus).
local function equip(surface, force, xs, y, load, item, stop)
  local chest_y = y + (y > LINE and 1 or -1)
  local first
  for _, x in ipairs(xs) do
    local inserter = surface.create_entity({ name = "bulk-inserter", position = { x, y },
      direction = load == (y > LINE) and 8 or 0, force = force })
    local chest = surface.create_entity({ name = "infinity-chest", position = { x, chest_y }, force = force })
    if load then
      chest.infinity_container_filters = { { index = 1, name = item, count = 1000, mode = "at-least" } }
    else
      chest.remove_unfiltered_items = true
      inserter.use_filters = true
      inserter.inserter_filter_mode = "blacklist"
      inserter.set_filter(1, { name = "coal" })
    end
    if first then
      first.get_wire_connector(W.circuit_green, true).connect_to(chest.get_wire_connector(W.circuit_green, true))
    else
      first = chest
    end
  end
  local pole_y = chest_y + (y > LINE and 1 or -1)
  local relay = surface.create_entity({ name = "medium-electric-pole",
    position = { math.floor((first.position.x + stop.position.x) / 2) + 0.5, pole_y }, force = force })
  first.get_wire_connector(W.circuit_green, true).connect_to(relay.get_wire_connector(W.circuit_green, true))
  relay.get_wire_connector(W.circuit_green, true).connect_to(stop.get_wire_connector(W.circuit_green, true))
  surface.create_entity({ name = "medium-electric-pole", position = { xs[1] - 1, pole_y }, force = force })
  local eei = surface.create_entity({ name = "electric-energy-interface", position = { xs[1] - 1, pole_y + (y > LINE and 2 or -2) },
    force = force })
  eei.power_production = 100000
  eei.electric_buffer_size = 1000000
end

local function stop(surface, force, name, dx, east)
  local e = surface.create_entity({ name = "utl-train-stop", position = { X0 + dx, LINE + (east and 2 or -2) },
    direction = east and 4 or 12, force = force, raise_built = true })
  e.backer_name = name
  return e
end

--- Strecke bauen; liefert den Zug.
function Rail.build(surface, force)
  for x = X0 - 61, X0 + 61, 2 do
    surface.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force })
  end
  -- Zug im Depot: X0 – 11 … X0 + 9; Greifarme erst ab ±42
  local depot = stop(surface, force, "Zug-Depot", 9, true)
  local provider = stop(surface, force, "Zug-Anbieter", 55, true)
  local requester = stop(surface, force, "Zug-Abnehmer", -55, false)
  equip(surface, force, { X0 + 44.5, X0 + 46.5 }, LINE + 1.5, true, "iron-plate", provider)
  equip(surface, force, { X0 - 44.5, X0 - 46.5 }, LINE - 1.5, false, nil, requester)
  remote.call("utl", "configure_station", depot.unit_number, { mode = "depot" })
  remote.call("utl", "configure_station", provider.unit_number,
    { mode = "station", provide = true, request = false, provide_threshold = 100 })
  remote.call("utl", "configure_station", requester.unit_number,
    { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", requester.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  -- Zug: jedes Teil 7 Felder hinter dem vorigen, dann koppeln sie von selbst
  local l1 = surface.create_entity({ name = "locomotive", position = { X0 + 4, LINE }, direction = 4, force = force })
  local wagon = surface.create_entity({ name = "cargo-wagon", position = { l1.position.x - 7, LINE }, direction = 4, force = force })
  local l2 = surface.create_entity({ name = "locomotive", position = { wagon.position.x - 7, LINE }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "Zug-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return l1.train
end

return Rail
