--- Beispiel-Szenario: Marcels Rundkurs (Blaupause `rundkurs_scenarios`) mit zehn Bahnhöfen.
--- Alles Gleisliche kommt aus der Blaupause; hier werden nur die Rollen eingestellt und die
--- Ladestellen gebaut. Gezeigt wird, wie UTL der Ladeseite sagt, was geladen werden soll:
---   * „Mischlager“: EINE Kiste mit drei Waren, EIN Greifarm – seinen Filter setzt die
---     Auftrags-Ausgabe, und die Wagenfilter lassen ohnehin nur das Bestellte hinein.
---   * „Tanklager“: zwei Tanks, zwei Pumpen – geschaltet über die Auftrags-Ausgabe, damit nur
---     die bestellte Flüssigkeit fließt (Öl und Wasser haben eigene Abnehmer).
local Ring = require("__UTLogistics__/scenarios/UTL-Beispiele/rundkurs")

local Build = {}

local W = defines.wire_connector_id

local NAMES = {
  S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", T = "utl-train-stop", V = "train-stop",
  C = "utl-station-combinator",
}
local RAILS = { S = true, A = true, B = true, H = true }

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor.
local DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } },
  [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } },
  [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

--- Rollen der zehn Bahnhöfe, nach ihrer Lage in der Blaupause.
local ROLES = {
  ["65/3"] = { name = "Mischlager", kind = "provider",
    items = { "iron-plate", "copper-plate", "iron-gear-wheel" } },
  ["115/3"] = { name = "Werkstatt (Eisen + Kupfer)", kind = "requester",
    items = { "iron-plate", "copper-plate" } },
  ["69/19"] = { name = "Tankstelle", kind = "fuel" },
  ["115/19"] = { name = "Kupfer-Lager", kind = "requester", items = { "copper-plate" } },
  ["11/41"] = { name = "Depot", kind = "depot" },
  ["137/61"] = { name = "Depot", kind = "depot" },
  ["79/83"] = { name = "Tanklager", kind = "fluid_provider", fluids = { "water", "crude-oil" } },
  ["33/83"] = { name = "Öl-Verbraucher", kind = "fluid_requester", fluid = "crude-oil" },
  ["33/99"] = { name = "Wasser-Verbraucher", kind = "fluid_requester", fluid = "water" },
  ["83/99"] = { name = "Cleanup", kind = "cleanup" },
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

--- Liegt an dieser Stelle Gleis (oder ein Signal/eine Haltestelle)?
local function rail_here(position, half)
  return #surface.find_entities_filtered({
    area = { { position[1] - half, position[2] - half }, { position[1] + half, position[2] + half } },
    type = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
      "rail-signal", "rail-chain-signal", "train-stop" },
  }) > 0
end

--- Ein Objekt neben das Gleis setzen; liegt dort Gleis, rückt es weiter weg.
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

--- Platz eines Fahrzeugs hinter der Haltestelle: Die vordere Lok hält 3 Felder dahinter, der
--- erste Wagen steht 10 Felder dahinter. Ausgangspunkt ist das Gleis, an dem die Haltestelle
--- wirklich hängt – gerechnete Punkte liegen sonst schnell auf dem Gleis.
local function spot_at(stop, back)
  local d = DIRS[stop.direction] or DIRS[0]
  local rail = stop.connected_rail
  local base = rail and { rail.position.x, rail.position.y }
    or add({ stop.position.x, stop.position.y }, d.r, -2)
  return add(base, d.f, -back), d
end

--- Strom für eine Ladestelle. Liefert die beiden Masten zurück: Sie dienen zugleich als
--- Zwischenstationen für das Schaltkabel zur Haltestelle (ein Kabel reicht nur 9 Felder, die
--- Kiste steht aber 10 Felder hinter ihr).
local function power_at(at, d, along)
  local pole = place_beside("medium-electric-pole", add(add(at, d.r, 3.5), d.f, along), d, 0.5)
  local relay = place_beside("medium-electric-pole", add(add(at, d.r, 3.5), d.f, along + 5), d, 0.5)
  local eei = place_beside("electric-energy-interface", add(add(at, d.r, 6), d.f, along), d, 1)
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
  return pole, relay
end

--- Grünes Kabel von A nach B; liefert false, wenn die 9 Felder nicht reichen.
local function link(a, b)
  if not (a and b and a.valid and b.valid) then return false end
  return a.get_wire_connector(W.circuit_green, true).connect_to(b.get_wire_connector(W.circuit_green, true))
end

--- Kiste mit Greifarm. `supply` = Waren einer Unendlich-Kiste (Anbieter, Tankstelle); ohne
--- `supply` eine gewöhnliche Kiste (Abnehmer, Cleanup) – sie läuft voll, dann ist die
--- Anforderung erfüllt. `back` = 10 am Wagen, 3 an der vorderen Lok (Tankstelle).
local function chest_at(stop, supply, back)
  local spot, d = spot_at(stop, back or 10)
  local at = add(spot, d.f, -0.5)
  -- Richtung eines Greifarms = die Seite, von der er greift: beim Laden die Kiste, beim
  -- Entladen der Wagen.
  local grab = supply and d.r or { -d.r[1], -d.r[2] }
  local inserter = entity("bulk-inserter", add(at, d.r, 1.5), { direction = direction_of(grab) })
  local chest = place_beside(supply and "infinity-chest" or "steel-chest", add(at, d.r, 2.5), d, 0.5)
  local pole, relay = power_at(at, d, 0)
  if chest and supply then
    local list = {}
    for i, name in ipairs(supply) do
      list[i] = { index = i, name = name, count = name == "coal" and 200 or 4000, mode = "at-least" }
    end
    chest.infinity_container_filters = list
  end
  return chest, inserter, pole, relay
end

-- Drei Ladestellen entlang eines Wagens (Maße wie im Lasttest-Szenario).
local SLOTS = { -2.5, -0.5, 1.5 }

--- Je Ware eine eigene Unendlich-Kiste mit eigenem Greifarm am selben Wagen. Getrennte Kisten
--- sind wichtig: Ein Greifarm, der die falsche Ware in der Hand hat, bekommt sie nicht mehr los,
--- sobald der Wagen sie wegen der Ladefilter nicht annimmt – und lädt dann gar nichts mehr.
local function supply_at(stop, items)
  local spot, d = spot_at(stop, 10)
  local pole, relay = power_at(add(spot, d.f, -0.5), d, 0)
  local chests, inserters = {}, {}
  for i, item in ipairs(items) do
    local at = add(spot, d.f, SLOTS[i] or (SLOTS[#SLOTS] + 2 * (i - #SLOTS)))
    inserters[item] = entity("bulk-inserter", add(at, d.r, 1.5), { direction = direction_of(d.r) })
    local chest = place_beside("infinity-chest", add(at, d.r, 2.5), d, 0.5)
    if chest then
      chest.infinity_container_filters = { { index = 1, name = item, count = 4000, mode = "at-least" } }
      chests[item] = chest
    end
  end
  return chests, inserters, pole, relay
end

--- Der Anschluss eines Tanks zur Gleisseite liegt ein Feld neben seiner Mitte.
local function near_offset(r)
  if r[2] == 1 then return { 1, 0 } elseif r[2] == -1 then return { -1, 0 } elseif r[1] == 1 then return { 0, 1 } end
  return { 0, -1 }
end

--- Pumpe, Tank und (beim Anbieter) Unendlich-Rohr am Wagenplatz. Maße wie im Lasttest-Szenario.
--- Der Tank des Abnehmers ist zugleich die Senke: Er hängt am Bahnhof, also sieht UTL den
--- Bestand und bestellt nur, bis er voll genug ist.
local function tank_at(stop, offset, fluid, loads)
  local spot, d = spot_at(stop, 10)
  local back = { -d.f[1], -d.f[2] }
  local at = add(add(spot, back, -0.5), d.f, offset)
  local off = near_offset(d.r)
  local flow = loads and { -d.r[1], -d.r[2] } or d.r
  local pump = entity("pump", add(at, d.r, 2), { direction = direction_of(flow) })
  local tank = place_beside("storage-tank", add(add(at, d.r, 4.5), off, 1), d, 1.5)
  if loads and tank then
    local pipe = place_beside("infinity-pipe",
      add(add({ tank.position.x, tank.position.y }, d.r, 2), off, 1), d, 0.5)
    if pipe then pipe.set_infinity_pipe_filter({ name = fluid, percentage = 1, mode = "at-least" }) end
  end
  -- Strom direkt neben die Pumpe (ein Mittelmast versorgt 5 × 5 Felder).
  local pole = add(add(at, d.r, 2.5), d.f, 2)
  place_beside("medium-electric-pole", { pole[1] + 0.5, pole[2] + 0.5 }, d, 0.5)
  local eei = place_beside("electric-energy-interface", add(add(at, d.r, 3), d.f, 4.5), d, 1)
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
  return pump, tank
end

--- Auftrags-Ausgabe neben einer Haltestelle (die UTL selbst gesetzt hat).
local function output_of(stop)
  local p = stop.position
  return surface.find_entities_filtered({ name = "utl-station-output",
    area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } } })[1]
end

--- Pumpen an die Auftrags-Ausgabe hängen: zuerst die nächstgelegene, die weiteren an ihre
--- Vorgängerin – ein Schaltkabel reicht nur 9 Felder. `comparator`: „>“ beim Anbieter (hier wird
--- geladen), „<“ beim Abnehmer (hier kommt es an).
local function wire_pumps(stop, pumps, comparator)
  local output = stop and output_of(stop)
  if not output then return 0 end
  local order = {}
  for fluid, pump in pairs(pumps or {}) do order[#order + 1] = { fluid = fluid, pump = pump } end
  table.sort(order, function(a, b)
    local function dist(pump)
      local dx, dy = pump.position.x - output.position.x, pump.position.y - output.position.y
      return dx * dx + dy * dy
    end
    return dist(a.pump) < dist(b.pump)
  end)
  local wired, previous = 0, nil
  for _, entry in ipairs(order) do
    local source = previous or output
    if source.get_wire_connector(W.circuit_green, true)
        .connect_to(entry.pump.get_wire_connector(W.circuit_green, true)) then
      local behavior = entry.pump.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = {
        first_signal = { type = "fluid", name = entry.fluid, quality = "normal" },
        comparator = comparator,
        constant = 0,
      }
      wired, previous = wired + 1, entry.pump
    end
  end
  return wired
end

--- Die Greifarme des Anbieters an die Auftrags-Ausgabe hängen: Jeder läuft nur, wenn seine Ware
--- im laufenden Auftrag steht. Dafür das **rote** Kabel – das grüne trägt schon den Bestand der
--- Kisten zur Station, und der Auftrag darf dort nicht hineinlaufen.
--- Die Leitung geht über die beiden Masten der Ladestelle (ein Kabel reicht nur 9 Felder).
local function wire_inserters(stop, inserters, poles)
  local output = stop and output_of(stop)
  if not (output and poles and poles.pole and poles.relay) then return 0 end
  local function red(a, b)
    if not (a and b and a.valid and b.valid) then return false end
    return a.get_wire_connector(W.circuit_red, true).connect_to(b.get_wire_connector(W.circuit_red, true))
  end
  if not (red(output, poles.relay) and red(poles.relay, poles.pole)) then return 0 end
  local wired = 0
  for item, inserter in pairs(inserters or {}) do
    if red(poles.pole, inserter) then
      local behavior = inserter.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = {
        first_signal = { type = "item", name = item, quality = "normal" },
        comparator = ">",
        constant = 0,
      }
      wired = wired + 1
    end
  end
  return wired
end

local function train(stop, wagon_name)
  if not stop then return nil end
  local spot, d = spot_at(stop, 10)
  local back = { -d.f[1], -d.f[2] }
  local l1 = entity("locomotive", add(spot, back, -7), { direction = stop.direction })
  local wagon = entity(wagon_name, spot, { direction = stop.direction })
  local l2 = entity("locomotive", add(spot, back, 7), { direction = stop.direction })
  if not (l1 and wagon and l2) then return nil end
  for _, loco in ipairs({ l1, l2 }) do loco.insert({ name = "coal", count = 200 }) end
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "Depot", wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return l1.train
end

--- Gleise, Signale und Haltestellen der Blaupause setzen. Liefert Haltestellen nach Lage und
--- die Zuordnung Haltestelle → Station (bei der Combinator-Bauart ist der Combinator die
--- Station).
local function build_ring()
  local stops, combinators = {}, {}
  -- Erst alle Gleise, dann Signale und Haltestellen: Ein Signal ohne sein Gleis rutscht beim
  -- Setzen an das nächstbeste Gleis.
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

  -- Jeder Combinator gehört zu der normalen Haltestelle direkt neben ihm (die Kabel der
  -- Blaupause gehen beim Umwandeln in eine Lua-Tabelle verloren). Combinatoren ohne solche
  -- Haltestelle werden wieder abgeräumt.
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
      comb.get_wire_connector(W.combinator_output_red, true)
        .connect_to(found.get_wire_connector(W.circuit_red, true))
      station_of[found] = comb
    else
      comb.destroy()
    end
  end
  return stops, station_of
end

function Build.run()
  surface = game.surfaces["utl-beispiele"] or game.create_surface("utl-beispiele")
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  force = game.forces["player"]
  surface.request_to_generate_chunks({ 74, 50 }, 5)
  surface.force_generate_chunk_requests()

  local stops, station_of = build_ring()
  local made = { pumps = {}, drains = {}, stops = {}, inserters = {}, poles = {} }

  for key, role in pairs(ROLES) do
    local stop = stops[key]
    if stop then
      stop.backer_name = role.name
      local station = station_of[stop] or stop
      local unit = station.unit_number
      local input = station.name == "utl-station-combinator" and W.combinator_input_green or W.circuit_green
      made.stops[key] = stop

      --- Kiste/Tank an den Bahnhof: Nur so sieht UTL den Bestand. Reicht das Kabel nicht bis
      --- zur Haltestelle, läuft es über die Masten der Ladestelle.
      local function connect(source, pole, relay)
        if not source then return end
        if source.get_wire_connector(W.circuit_green, true)
            .connect_to(station.get_wire_connector(input, true)) then
          return
        end
        if link(source, pole) and link(pole, relay)
            and relay.get_wire_connector(W.circuit_green, true)
              .connect_to(station.get_wire_connector(input, true)) then
          return
        end
        stats.failed = stats.failed + 1
      end

      if role.kind == "depot" then
        remote.call("utl", "configure_station", unit, { mode = "depot" })
      elseif role.kind == "fuel" then
        chest_at(stop, { "coal" }, 3)
        remote.call("utl", "configure_station", unit, { mode = "fuel" })
      elseif role.kind == "cleanup" then
        chest_at(stop, nil)
        remote.call("utl", "configure_station", unit, { mode = "cleanup" })
      elseif role.kind == "provider" then
        local chests, inserters, pole, relay = supply_at(stop, role.items)
        made.inserters[key] = inserters
        made.poles[key] = { pole = pole, relay = relay }
        for _, chest in pairs(chests) do connect(chest, pole, relay) end
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = true, request = false, provide_threshold = 100 })
      elseif role.kind == "requester" then
        local rchest, _, rpole, rrelay = chest_at(stop, nil)
        connect(rchest, rpole, rrelay)
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = false, request = true, request_threshold = 100 })
        for slot, item in ipairs(role.items) do
          -- Zielbestand: klein gehalten, damit man die Fahrten in Ruhe verfolgen kann. Ist die
          -- Kiste voll genug, hat der Zug frei – zum Weiterspielen einfach ausräumen.
          remote.call("utl", "set_request", unit, slot, { type = "item", name = item }, 400)
        end
      elseif role.kind == "fluid_provider" then
        for i, fluid in ipairs(role.fluids) do
          local pump, tank = tank_at(stop, i == 1 and -2 or 2, fluid, true)
          made.pumps[fluid] = pump
          connect(tank)
        end
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = true, request = false, provide_threshold = 1000 })
      elseif role.kind == "fluid_requester" then
        local pump, tank = tank_at(stop, 0, role.fluid, false)
        made.drains[key] = { [role.fluid] = pump }
        connect(tank)
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = false, request = true, request_threshold = 1000 })
        remote.call("utl", "set_request", unit, 1, { type = "fluid", name = role.fluid }, 15000)
      end
    end
  end

  -- Zwei Züge, je einer in einem Depot; die Ausbuchtungen halten sie von der Strecke fern.
  made.train = train(made.stops["11/41"], "cargo-wagon")
  made.fluid_train = train(made.stops["137/61"], "fluid-wagon")

  made.surface = surface
  made.start = { x = 74, y = 50 }
  made.area = { { -8, -8 }, { 160, 112 } }
  made.failed = stats.failed
  return made
end

--- Pumpen und den Greifarm an die Auftrags-Ausgaben hängen. Ein paar Takte nach dem Aufbau
--- aufrufen: Bei der Combinator-Bauart erkennt UTL das Kabel zur Haltestelle erst im nächsten
--- Takt, vorher gibt es dort noch keine Ausgabe.
function Build.wire(made)
  surface = made.surface
  local wired = wire_pumps(made.stops["79/83"], made.pumps, ">")
  for key, drains in pairs(made.drains) do wired = wired + wire_pumps(made.stops[key], drains, "<") end
  return wired + wire_inserters(made.stops["65/3"], made.inserters["65/3"], made.poles["65/3"])
end

return Build
