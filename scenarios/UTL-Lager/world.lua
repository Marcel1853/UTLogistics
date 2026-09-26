--- Szenario „UTL-Lager“: Aufbau. Marcels Rundkurs (Blaupause `rundkurs_scenarios`, wie
--- UTL-Beispiele) mit neuen Rollen – Lage der Haltestelle in der Blaupause → Rolle:
---   oben, nach Osten:   Anbieter (Eisen, Kupfer) · Werkstatt (Eisen)
---                       Tankstelle · Cleanup (gibt zurück, ein Wende-Greifarm)
---   unten, nach Westen: Fabrik (Eisen) · Lager (Eisen, Mindest/Höchst, drei Wende-Greifarme)
---                       Kupfer-Werkstatt A · Kupfer-Werkstatt B
---   links und rechts:   je ein Depot mit einem Zug
--- Das Lager liegt näher an der Fabrik als der Anbieter, die Werkstatt näher am Anbieter.
local Ring = require("__UTLogistics__/scenarios/UTL-Beispiele/rundkurs")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local World = {}

local W = defines.wire_connector_id
World.SURFACE = "utl-lager"
World.IRON = "item|iron-plate|normal"
World.COPPER = "item|copper-plate|normal"
World.MIN, World.MAX = 400, 1200
World.COPPER_A = 300 -- Zielbestand und Kistengröße der Kupfer-Werkstatt A

local NAMES = {
  S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", T = "utl-train-stop", V = "train-stop",
  C = "utl-station-combinator",
}
local RAILS = { S = true, A = true, B = true, H = true }

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor (rechts = Seite der Haltestelle)
local DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } },
  [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } },
  [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

local IRON = { type = "item", name = "iron-plate" }
local COPPER = { type = "item", name = "copper-plate" }
local SLOTS3 = { -2.5, -0.5, 1.5 } -- drei Ladestellen entlang eines Wagens

local surface, force

local function entity(name, position, extra)
  local spec = { name = name, position = position, force = force }
  for key, value in pairs(extra or {}) do spec[key] = value end
  return surface.create_entity(spec)
end

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end
local function back(v) return { -v[1], -v[2] } end

--- Richtung (16er) zu einem Einheitsvektor.
local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

--- Wagenmitte (`behind` = 10) bzw. vordere Lok (3) hinter der Haltestelle.
local function spot_at(stop, behind)
  local d = DIRS[stop.direction] or DIRS[0]
  local rail = stop.connected_rail
  local base = rail and { rail.position.x, rail.position.y } or add({ stop.position.x, stop.position.y }, d.r, -2)
  return add(base, d.f, -behind), d
end

local function wire(a, b, color)
  if not (a and b and a.valid and b.valid) then return false end
  local id = color == "red" and W.circuit_red or W.circuit_green
  return a.get_wire_connector(id, true).connect_to(b.get_wire_connector(id, true))
end

--- Wende-Greifarm über eine Blaupause bauen: so kommt seine Einstellung (Tag `utl_rev`) mit,
--- genau wie beim Spieler. `cfg` = nil → Standard (dreht sich, solange ein Zug hier entlädt).
local function reversible(position, direction, cfg)
  local inv = game.create_inventory(1)
  inv[1].set_stack({ name = "blueprint" })
  local tags = cfg and { utl_rev = { cfg = cfg, flipped = false } } or nil
  inv[1].set_blueprint_entities({ { entity_number = 1, name = "utl-reversible-inserter", position = { 0.5, 0.5 },
    direction = direction, tags = tags } })
  local ghosts = inv[1].build_blueprint({ surface = surface, force = force,
    position = { math.floor(position[1]), math.floor(position[2]) }, skip_fog_of_war = true, raise_built = true })
  local made
  for _, ghost in pairs(ghosts or {}) do
    if ghost.valid then
      local _, revived = ghost.revive({ raise_revive = true })
      made = revived or made
    end
  end
  inv.destroy()
  return made
end

--- Ladestelle am Wagen: je Platz ein Greifarm (Seite Gleis) und eine Kiste; auf Wunsch dahinter ein
--- Abfluss (Greifarm in eine Kiste, die alles vernichtet). Dazu Strom und zwei Masten, über die die
--- Kabel zur Station laufen (ein Kabel reicht nur 9 Felder).
--- `opts` = { slots, behind, supply = { Ware je Platz }, reversible = cfg | true, unload_base,
---   drain = Greifarm-Name, bar }
local function bay(stop, station, opts)
  local spot, d = spot_at(stop, opts.behind or 10)
  local grab_chest, grab_wagon = direction_of(d.r), direction_of(back(d.r))
  local out = { inserters = {}, chests = {} }
  for i, f in ipairs(opts.slots or { -0.5 }) do
    local at = add(spot, d.f, f)
    local inserter_at = add(at, d.r, 1.5)
    if opts.reversible then
      out.inserters[i] = reversible(inserter_at, opts.unload_base and grab_wagon or grab_chest,
        opts.reversible ~= true and opts.reversible or nil)
    else
      out.inserters[i] = entity("bulk-inserter", inserter_at, { direction = opts.supply and grab_chest or grab_wagon })
    end
    local chest = entity(opts.supply and "infinity-chest" or "steel-chest", add(at, d.r, 2.5))
    if opts.supply then
      local item = opts.supply[i]
      chest.infinity_container_filters = { { index = 1, name = item, count = item == "coal" and 200 or 4000, mode = "at-least" } }
    elseif opts.bar then
      chest.get_inventory(defines.inventory.chest).set_bar(opts.bar + 1)
    end
    if out.chests[i - 1] then wire(out.chests[i - 1], chest) end
    out.chests[i] = chest
    if opts.drain then
      entity(opts.drain, add(at, d.r, 3.5), { direction = grab_wagon }) -- greift von der Kiste davor
      local void = entity("infinity-chest", add(at, d.r, 4.5))
      void.remove_unfiltered_items = true
    end
  end
  out.pole = entity("medium-electric-pole", add(add(spot, d.f, 0.5), d.r, 3.5))
  out.relay = entity("medium-electric-pole", add(add(spot, d.f, 6.5), d.r, 3.5))
  local eei = entity("electric-energy-interface", add(add(spot, d.f, 3.5), d.r, 6))
  eei.power_production = 200000
  eei.electric_buffer_size = 2000000
  wire(out.chests[1], out.pole)
  wire(out.pole, out.relay)
  local input = station.name == "utl-station-combinator" and W.combinator_input_green or W.circuit_green
  out.relay.get_wire_connector(W.circuit_green, true).connect_to(station.get_wire_connector(input, true))
  return out
end

--- Gleise, Signale und Haltestellen der Blaupause (wie UTL-Beispiele). Liefert die Haltestellen
--- nach Lage und die Station je Haltestelle (bei der Combinator-Bauart der Combinator).
local function build_ring()
  local stops, combinators = {}, {}
  for _, only_rails in ipairs({ true, false }) do
    for _, e in ipairs(Ring) do
      if (RAILS[e[1]] or false) == only_rails then
        local raise = e[1] == "T" or e[1] == "C"
        local made = entity(NAMES[e[1]], { e[2], e[3] }, { direction = e[4], raise_built = raise })
        if made and (e[1] == "T" or e[1] == "V") then stops[e[2] .. "/" .. e[3]] = made end
        if made and e[1] == "C" then combinators[#combinators + 1] = made end
      end
    end
  end
  local station_of = {}
  for _, comb in ipairs(combinators) do
    local best, found
    for _, stop in pairs(stops) do
      if stop.name == "train-stop" and not station_of[stop] then
        local dx, dy = stop.position.x - comb.position.x, stop.position.y - comb.position.y
        local dist = dx * dx + dy * dy
        if dist < 20 and (not best or dist < best) then best, found = dist, stop end
      end
    end
    if found then
      comb.get_wire_connector(W.combinator_output_red, true).connect_to(found.get_wire_connector(W.circuit_red, true))
      station_of[found] = comb
    else
      comb.destroy()
    end
  end
  return stops, station_of
end

local function train(stop)
  local spot, d = spot_at(stop, 10)
  local l1 = entity("locomotive", add(spot, back(d.f), -7), { direction = stop.direction })
  entity("cargo-wagon", spot, { direction = stop.direction })
  local l2 = entity("locomotive", add(spot, back(d.f), 7), { direction = stop.direction })
  for _, loco in ipairs({ l1, l2 }) do loco.insert({ name = "coal", count = 200 }) end
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "Depot", wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return l1.train
end

local function requester(unit, signal, amount)
  remote.call("utl", "configure_station", unit, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", unit, 1, signal, amount)
end

-- Lage → { Name, Schild (utl-sign.*), Symbol }
local ROLES = {
  ["65/3"] = { "Anbieter", "lager-provider", IRON },
  ["115/3"] = { "Werkstatt", "lager-workshop", IRON },
  ["69/19"] = { "Tankstelle", "fuel-low", { type = "item", name = "coal" } },
  ["115/19"] = { "Cleanup", "lager-cleanup", COPPER },
  ["11/41"] = { "Depot", "lager-depot" },
  ["137/61"] = { "Depot", "lager-depot" },
  ["79/83"] = { "Lager", "lager-storage", IRON },
  ["33/83"] = { "Fabrik", "lager-factory", IRON },
  ["33/99"] = { "Kupfer-Werkstatt A", "lager-copper-a", COPPER },
  ["83/99"] = { "Kupfer-Werkstatt B", "lager-copper-b", COPPER },
}

function World.build()
  surface = game.surfaces[World.SURFACE] or game.create_surface(World.SURFACE)
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  force = game.forces["player"]
  surface.request_to_generate_chunks({ 74, 50 }, 5)
  surface.force_generate_chunk_requests()

  local stops, station_of = build_ring()
  local made = { stops = {}, units = {}, bays = {}, surface = surface }
  for key, role in pairs(ROLES) do
    local stop = stops[key]
    stop.backer_name = role[1]
    made.stops[key] = stop
    made.units[key] = (station_of[stop] or stop).unit_number
    local f = (DIRS[stop.direction] or DIRS[0]).f
    Signs.place(surface, { stop.position.x + 3 * f[1], stop.position.y + 3 * f[2] }, role[2],
      role[3] or { type = "item", name = "utl-train-stop" })
  end
  local function station(key) return station_of[made.stops[key]] or made.stops[key] end
  local u = made.units

  remote.call("utl", "configure_station", u["11/41"], { mode = "depot" })
  remote.call("utl", "configure_station", u["137/61"], { mode = "depot" })
  -- Tankstelle: je ein Greifarm an der vorderen (3 Felder hinter der Haltestelle) und der hinteren
  -- Lok (17 Felder) – beide Loks schauen nach vorn und verbrauchen Kohle
  bay(made.stops["69/19"], station("69/19"), { behind = 3, supply = { "coal" } })
  bay(made.stops["69/19"], station("69/19"), { behind = 17, supply = { "coal" } })
  remote.call("utl", "configure_station", u["69/19"], { mode = "fuel" })

  -- Anbieter: zwei Plätze Eisen, einer Kupfer; die Greifarme gibt die Auftrags-Ausgabe frei
  made.bays.provider = bay(made.stops["65/3"], station("65/3"),
    { slots = SLOTS3, supply = { "iron-plate", "iron-plate", "copper-plate" } })
  remote.call("utl", "configure_station", u["65/3"], { mode = "station", provide = true, request = false, provide_threshold = 100 })

  bay(made.stops["115/3"], station("115/3"), { drain = "inserter" })
  requester(u["115/3"], IRON, 400)
  bay(made.stops["33/83"], station("33/83"), { drain = "inserter" })
  requester(u["33/83"], IRON, 400)

  -- Lager: drei Wende-Greifarme (Standard: umgedreht, solange ein Zug hier entlädt) und dahinter
  -- eine kleine Fabrik, die stetig Eisen verbraucht – so fällt es unter Mindest
  made.bays.storage = bay(made.stops["79/83"], station("79/83"), { slots = SLOTS3, reversible = true, drain = "inserter" })
  remote.call("utl", "configure_station", u["79/83"], { mode = "storage",
    storage = { limits = { { signal = IRON, min = World.MIN, max = World.MAX } }, accept_leftover = false } })

  -- Cleanup: gebaut zum Entladen; die Bedingung „utl-loading > 0“ dreht ihn nur zum Abholen um
  made.bays.cleanup = bay(made.stops["115/19"], station("115/19"), { unload_base = true,
    reversible = { signal = { type = "virtual", name = "utl-loading" }, comparator = ">", constant = 0, red = true, green = true } })
  -- Anbieter-Schwelle klein: ein Rest ist oft nur ein paar Dutzend Platten
  remote.call("utl", "configure_station", u["115/19"], { mode = "cleanup", cleanup = { offer = "first" }, provide_threshold = 50 })

  -- Kupfer-Werkstatt A: kleine Kiste ohne Abfluss (ein Abfluss schüfe ständig ein wenig Platz, der
  -- Zug würde nie inaktiv und entlüde am Ende doch alles) – control.lua leert sie. B: mit Abfluss.
  made.bays.copper_a = bay(made.stops["33/99"], station("33/99"), { bar = World.COPPER_A / 100 })
  requester(u["33/99"], COPPER, World.COPPER_A)
  bay(made.stops["83/99"], station("83/99"), { drain = "inserter" })
  requester(u["83/99"], COPPER, 200)

  made.trains = { train(made.stops["11/41"]), train(made.stops["137/61"]) }
  made.start = { x = 74, y = 50 }
  made.area = { { -8, -8 }, { 160, 112 } }
  return made
end

--- Auftrags-Ausgabe neben einer Haltestelle (legt UTL selbst an, einen Moment nach dem Einstellen).
local function output_of(stop)
  local p = stop.position
  return surface.find_entities_filtered({ name = "utl-station-output", area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } } })[1]
end

--- Rotes Kabel von der Auftrags-Ausgabe über die Masten an die Greifarme (das grüne trägt schon den
--- Bestand der Kisten zur Station). Beim Anbieter läuft jeder Greifarm nur für seine Ware.
--- Liefert false, solange eine Ausgabe noch fehlt.
function World.wire(made)
  surface = made.surface
  local plan = {
    { made.stops["65/3"], made.bays.provider, { "iron-plate", "iron-plate", "copper-plate" } },
    { made.stops["79/83"], made.bays.storage },
    { made.stops["115/19"], made.bays.cleanup },
  }
  for _, entry in ipairs(plan) do
    if not output_of(entry[1]) then return false end
  end
  for _, entry in ipairs(plan) do
    local b = entry[2]
    wire(output_of(entry[1]), b.relay, "red")
    wire(b.relay, b.pole, "red")
    for i, inserter in ipairs(b.inserters) do
      wire(b.pole, inserter, "red")
      if entry[3] then
        local behavior = inserter.get_or_create_control_behavior()
        behavior.circuit_enable_disable = true
        behavior.circuit_condition = { first_signal = { type = "item", name = entry[3][i], quality = "normal" },
          comparator = ">", constant = 0 }
      end
    end
  end
  return true
end

--- Eisen bzw. Kupfer in den Kisten einer Ladestelle.
function World.stock(b, item)
  local n = 0
  for _, chest in pairs(b and b.chests or {}) do
    if chest.valid then n = n + chest.get_item_count(item) end
  end
  return n
end

return World
