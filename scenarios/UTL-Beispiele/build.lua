--- Baut das Beispielnetz: Marcels Rundkurs mit Ausbuchtungen (Blaupause `rundkurs_tipps`), sechs
--- Bahnhöfe und zwei Züge. Gezeigt werden die beiden Wege, mit denen UTL der Ladeseite sagt, was
--- geladen werden soll:
---   1. „Mischlager“: EINE Kiste mit drei Waren, EIN gewöhnlicher Greifarm – die Wagenfilter
---      sorgen dafür, dass nur die bestellte Ware hineinkommt.
---   2. „Tanklager“: zwei Tanks, zwei Pumpen – geschaltet über die Auftrags-Ausgabe, damit nur
---      die bestellte Flüssigkeit fließt.
local Ring = require("__UTLogistics__/scenarios/UTL-Beispiele/rundkurs")

local Build = {}

local W = defines.wire_connector_id

local NAMES = {
  S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", T = "utl-train-stop", V = "train-stop",
  C = "utl-station-combinator",
}

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor.
local DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } },
  [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } },
  [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

local surface, force
local stats = { failed = 0 }

local function entity(name, position, extra)
  local spec = { name = name, position = position, force = force }
  for key, value in pairs(extra or {}) do spec[key] = value end
  local made = surface.create_entity(spec)
  if not made then stats.failed = stats.failed + 1 end
  return made
end

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end

--- Richtung (16er) zu einem Einheitsvektor – per Vergleich, nicht per Text (Lua kennt „-0“).
local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

--- Platz des ersten Wagens hinter einer Haltestelle. Ausgangspunkt ist das Gleis, an dem die
--- Haltestelle wirklich hängt (`connected_rail`) – gerechnete Punkte liegen sonst schnell auf dem
--- Gleis. Die Haltestelle steht immer rechts der Fahrtrichtung, daraus ergibt sich die Seite,
--- auf der Kisten und Tanks Platz haben.
local function wagon_spot(stop)
  local d = DIRS[stop.direction] or DIRS[0]
  local rail = stop.connected_rail
  local base = rail and { rail.position.x, rail.position.y }
    or add({ stop.position.x, stop.position.y }, d.r, -2)
  return add(base, d.f, -10), d
end

--- Liegt an dieser Stelle schon ein Gleis (oder ein Signal/eine Haltestelle)?
local function rail_here(position, half)
  return #surface.find_entities_filtered({
    area = { { position[1] - half, position[2] - half }, { position[1] + half, position[2] + half } },
    type = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
      "rail-signal", "rail-chain-signal", "train-stop", "rail-support" },
  }) > 0
end

--- Ein Objekt neben das Gleis setzen: Liegt an der gewünschten Stelle Gleis, rückt es
--- feldweise vom Gleis weg. `half` = halbe Kantenlänge des Objekts.
local function place_beside(name, position, d, half, extra)
  for step = 0, 5 do
    local p = add(position, d.r, step)
    if not rail_here(p, half) then
      local made = entity(name, p, extra)
      if made then return made end
    end
  end
  return nil
end

--- Strom für eine Ladestelle: ein Mast neben der Kiste und eine kleine Energiequelle daneben.
--- `along` verschiebt beides entlang des Gleises (bei Tanks ist der Platz daneben belegt).
local function power_at(at, d, along)
  place_beside("medium-electric-pole", add(add(at, d.r, 3.5), d.f, along), d, 0.5)
  local eei = place_beside("electric-energy-interface", add(add(at, d.r, 6), d.f, along), d, 1)
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
end

--- Unendlich-Kiste mit Greifarm am Wagenplatz. `filters` = Anbieter (Nachschub),
--- nil = Abnehmer (die Kiste vernichtet alles).
local function chest_at(stop, filters, prefill)
  local spot, d = wagon_spot(stop)
  local at = add(spot, d.f, -0.5)
  -- Richtung eines Greifarms = die Seite, von der er greift: beim Laden die Kiste, beim
  -- Entladen der Wagen.
  local grab = filters and d.r or { -d.r[1], -d.r[2] }
  entity("bulk-inserter", add(at, d.r, 1.5), { direction = direction_of(grab) })
  -- Anbieter: Unendlich-Kiste (Nachschub). Abnehmer: gewöhnliche Kiste – sie läuft voll, dann
  -- ist die Anforderung erfüllt und der Zug holt die andere Ware. Zum Weiterspielen einfach
  -- ausräumen.
  local chest = place_beside(filters and "infinity-chest" or "steel-chest", add(at, d.r, 2.5), d, 0.5)
  power_at(at, d, 0)
  if chest then
    if filters then
      local list = {}
      for i, name in ipairs(filters) do list[i] = { index = i, name = name, count = 4000, mode = "at-least" } end
      chest.infinity_container_filters = list
    elseif prefill then
      -- Vorgefüllt, aber mit Luft: So ist eine Anforderung bald erfüllt und der Zug holt die
      -- andere Ware – die nächste Lieferung passt aber noch hinein (eine Stahlkiste fasst 4800).
      local each = math.floor(3000 / #prefill)
      for _, name in ipairs(prefill) do chest.insert({ name = name, count = each }) end
    end
  end
  return chest
end

--- Pumpe, Tank und Unendlich-Rohr am Wagenplatz (Maße wie im Lasttest-Szenario, dort erprobt):
--- Laden: Rohr → Tank → Pumpe → Wagen; Entladen andersherum. Der Anschluss des Tanks zur
--- Gleisseite liegt ein Feld neben seiner Mitte. `offset` verschiebt das Gespann am Wagen entlang.
local function near_offset(r)
  if r[2] == 1 then return { 1, 0 } elseif r[2] == -1 then return { -1, 0 } elseif r[1] == 1 then return { 0, 1 } end
  return { 0, -1 }
end

local function tank_at(stop, offset, fluid, loads)
  local spot, d = wagon_spot(stop)
  local back = { -d.f[1], -d.f[2] }
  local at = add(add(spot, back, -0.5), d.f, offset)
  local off = near_offset(d.r)
  local flow = loads and { -d.r[1], -d.r[2] } or d.r
  local pump = entity("pump", add(at, d.r, 2), { direction = direction_of(flow) })
  local tank_pos = add(add(at, d.r, 4.5), off, 1)
  local tank = place_beside("storage-tank", tank_pos, d, 1.5)
  local pipe = tank and place_beside("infinity-pipe",
    add(add({ tank.position.x, tank.position.y }, d.r, 2), off, 1), d, 0.5)
  if pipe then
    pipe.set_infinity_pipe_filter({ name = fluid, percentage = loads and 1 or 0,
      mode = loads and "at-least" or "exactly" })
  end
  -- Strom direkt neben die Pumpe: ein Mittelmast versorgt 5 × 5 Felder.
  local pole_at = add(add(at, d.r, 2.5), d.f, 2)
  place_beside("medium-electric-pole", { pole_at[1] + 0.5, pole_at[2] + 0.5 }, d, 0.5)
  local eei = place_beside("electric-energy-interface", add(add(at, d.r, 3), d.f, 4.5), d, 1)
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
  return pump, tank
end

--- Pumpe nur öffnen, wenn diese Flüssigkeit im laufenden Auftrag steht.
--- `previous` = schon verkabelte Pumpe: Ein Schaltkabel reicht nur 9 Felder, die zweite Pumpe
--- hängt deshalb an der ersten statt direkt an der Ausgabe.
local function pump_on_signal(pump, output, fluid, previous)
  if not (pump and output) then return false end
  local source = previous or output
  -- connect_to sagt, ob das Kabel wirklich zustande kam (Reichweite 9 Felder).
  if not source.get_wire_connector(W.circuit_green, true)
      .connect_to(pump.get_wire_connector(W.circuit_green, true)) then
    return false
  end
  local behavior = pump.get_or_create_control_behavior()
  behavior.circuit_enable_disable = true
  behavior.circuit_condition = {
    first_signal = { type = "fluid", name = fluid, quality = "normal" },
    comparator = ">",
    constant = 0,
  }
  return true
end

--- Auftrags-Ausgabe neben einer Haltestelle (die UTL selbst gesetzt hat).
local function output_of(stop)
  local p = stop.position
  return surface.find_entities_filtered({ name = "utl-station-output",
    area = { { p.x - 3, p.y - 3 }, { p.x + 3, p.y + 3 } } })[1]
end

--- Zug in die Ausbuchtung setzen: Lok an der Haltestelle, Wagen dahinter, zweite Lok als Schluss.
local function train(stop, wagon_name, depot_name)
  local spot, d = wagon_spot(stop)
  local back = { -d.f[1], -d.f[2] }
  local dir = stop.direction
  local l1 = entity("locomotive", add(spot, back, -7), { direction = dir })
  local wagon = entity(wagon_name, spot, { direction = dir })
  local l2 = entity("locomotive", add(spot, back, 7), { direction = dir })
  if not (l1 and wagon and l2) then return nil end
  for _, loco in ipairs({ l1, l2 }) do loco.insert({ name = "coal", count = 200 }) end
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = depot_name, wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return l1.train
end

local function key_of(x, y) return x .. "/" .. y end

function Build.run()
  surface = game.surfaces["utl-beispiele"] or game.create_surface("utl-beispiele")
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  force = game.forces["player"]
  surface.request_to_generate_chunks({ 81, 45 }, 5)
  surface.force_generate_chunk_requests()

  -- Erst alle Gleise, dann Signale und Haltestellen: Ein Signal ohne sein Gleis rutscht beim
  -- Setzen an das nächstbeste Gleis – dann stehen die Signale kreuz und quer.
  local RAILS = { S = true, A = true, B = true, H = true }
  local stops, combinators = {}, {}
  for _, only_rails in ipairs({ true, false }) do
    for _, e in ipairs(Ring) do
      if (RAILS[e[1]] or false) == only_rails then
        local raise = e[1] == "T" or e[1] == "C"
        local made = entity(NAMES[e[1]], { e[2], e[3] }, { direction = e[4], raise_built = raise })
        if made and (e[1] == "T" or e[1] == "V") then stops[key_of(e[2], e[3])] = made end
        if made and e[1] == "C" then combinators[#combinators + 1] = made end
      end
    end
  end

  -- Combinator mit „seiner“ normalen Haltestelle verkabeln: Die Kabel der Blaupause gehen beim
  -- Umwandeln in eine Lua-Tabelle verloren, also hier die nächstgelegene Haltestelle nehmen.
  local function nearest_stop(entity_at, only_vanilla)
    local best, found
    for _, stop in pairs(stops) do
      if not only_vanilla or stop.name == "train-stop" then
        local dx = stop.position.x - entity_at.position.x
        local dy = stop.position.y - entity_at.position.y
        local dist = dx * dx + dy * dy
        if not best or dist < best then best, found = dist, stop end
      end
    end
    return found, best
  end
  for _, comb in ipairs(combinators) do
    local stop = nearest_stop(comb, true)
    if stop then
      comb.get_wire_connector(W.combinator_output_red, true)
        .connect_to(stop.get_wire_connector(W.circuit_red, true))
    end
  end

  local area = { { -8, -8 }, { 160, 96 } }

  --- Die Station einer Haltestelle: bei der Combinator-Bauart ist der Combinator die Station.
  local function station_of(stop)
    for _, comb in ipairs(combinators) do
      local dx = stop.position.x - comb.position.x
      local dy = stop.position.y - comb.position.y
      if dx * dx + dy * dy < 30 then return comb end
    end
    return stop
  end

  local made = { stops = stops }
  local depot = stops[key_of(11, 33)]
  local mix = stops[key_of(69, 11)]
  local iron = stops[key_of(115, 11)]
  local copper = stops[key_of(137, 53)]
  local tanks = stops[key_of(79, 75)]
  local oil = stops[key_of(33, 75)]

  depot.backer_name = "Depot"
  remote.call("utl", "configure_station", station_of(depot).unit_number, { mode = "depot" })

  -- 1. Gemischter Anbieter – hier als normale Haltestelle mit UTL-Stations-Combinator.
  mix.backer_name = "Mischlager"
  local mix_station = station_of(mix)
  local chest = chest_at(mix, { "iron-plate", "copper-plate", "iron-gear-wheel" })
  if chest then
    local input = mix_station.name == "utl-station-combinator" and W.combinator_input_green or W.circuit_green
    chest.get_wire_connector(W.circuit_green, true)
      .connect_to(mix_station.get_wire_connector(input, true))
  end
  remote.call("utl", "configure_station", mix_station.unit_number,
    { mode = "station", provide = true, request = false, provide_threshold = 100 })

  -- 2. Zwei Abnehmer: Die Werkstatt braucht zwei Waren – UTL packt beide in eine Fahrt, solange
  -- der Anbieter beides hat und im Wagen Platz ist. Die Lackiererei braucht nur eine.
  for _, entry in ipairs({
    { stop = iron, name = "Werkstatt (Eisen + Kupfer)", items = { "iron-plate", "copper-plate" } },
    { stop = copper, name = "Kupfer-Lager", items = { "copper-plate" } },
  }) do
    entry.stop.backer_name = entry.name
    chest_at(entry.stop, nil, entry.items)
    local station = station_of(entry.stop)
    remote.call("utl", "configure_station", station.unit_number,
      { mode = "station", provide = false, request = true, request_threshold = 100 })
    for slot, item in ipairs(entry.items) do
      remote.call("utl", "set_request", station.unit_number, slot, { type = "item", name = item }, 400)
    end
  end

  -- 3. Flüssigkeiten: zwei Tanks am selben Bahnsteig, die Pumpen schaltet die Auftrags-Ausgabe.
  tanks.backer_name = "Tanklager"
  made.pumps = {}
  for _, entry in ipairs({ { fluid = "water", offset = -2 }, { fluid = "crude-oil", offset = 2 } }) do
    local pump, tank = tank_at(tanks, entry.offset, entry.fluid, true)
    made.pumps[entry.fluid] = pump
    if tank then
      tank.get_wire_connector(W.circuit_green, true)
        .connect_to(tanks.get_wire_connector(W.circuit_green, true))
    end
  end
  remote.call("utl", "configure_station", station_of(tanks).unit_number,
    { mode = "station", provide = true, request = false, provide_threshold = 1000 })

  oil.backer_name = "Öl-Verbraucher"
  tank_at(oil, 0, "crude-oil", false)
  local oil_station = station_of(oil)
  remote.call("utl", "configure_station", oil_station.unit_number,
    { mode = "station", provide = false, request = true, request_threshold = 1000 })
  remote.call("utl", "set_request", oil_station.unit_number, 1, { type = "fluid", name = "crude-oil" }, 15000)

  -- Zwei Züge auf dem Rundkurs; die Ausbuchtungen sorgen dafür, dass sie sich nicht behindern.
  made.train = train(depot, "cargo-wagon", "Depot")
  made.fluid_train = train(iron, "fluid-wagon", "Depot")

  -- Die Pumpen hängen an der Auftrags-Ausgabe des Tanklagers.
  -- Die Pumpen an die Auftrags-Ausgabe hängen: zuerst die nächstgelegene, die weiteren an ihre
  -- Vorgängerin – ein Schaltkabel reicht nur 9 Felder.
  local output = output_of(tanks)
  made.wired = 0
  local order = {}
  for fluid, pump in pairs(made.pumps) do order[#order + 1] = { fluid = fluid, pump = pump } end
  if output then
    table.sort(order, function(a, b)
      local function dist(pump)
        local dx = pump.position.x - output.position.x
        local dy = pump.position.y - output.position.y
        return dx * dx + dy * dy
      end
      return dist(a.pump) < dist(b.pump)
    end)
  end
  local previous
  for _, entry in ipairs(order) do
    if pump_on_signal(entry.pump, output, entry.fluid, previous) then
      made.wired = made.wired + 1
      previous = entry.pump
    end
  end

  made.surface = surface
  made.area = area
  made.start = { x = 81, y = 45 }
  made.failed = stats.failed
  return made
end

return Build
