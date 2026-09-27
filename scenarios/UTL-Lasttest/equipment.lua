--- Greifarme, Kisten, Pumpen und Strom an einer Haltestelle des Lasttests (von builder.lua gerufen).
--- `ctx` = { surface, force, stats } des gerade laufenden Baus.
local Equipment = {}

local W = defines.wire_connector_id

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end
local function xy(position) return { position.x, position.y } end

--- Richtung (16er) eines Einheitsvektors. Per Vergleich, nicht per Text: Lua rechnet mit
--- Kommazahlen, -0 würde als „-0“ geschrieben.
local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end
Equipment.direction_of = direction_of

local ctx

local function entity(name, pos, extra)
  local spec = extra or {}
  spec.name, spec.position, spec.force = name, pos, ctx.force
  local e = ctx.surface.create_entity(spec)
  if e then ctx.stats.equipment = ctx.stats.equipment + 1 end
  return e
end

local function connect(a, b, id_a, id_b)
  if not (a and b) then return false end
  local ok = a.get_wire_connector(id_a or W.circuit_green, true).connect_to(b.get_wire_connector(id_b or id_a or W.circuit_green, true))
  if not ok then ctx.stats.wires_failed = ctx.stats.wires_failed + 1 end
  return ok
end

--- Pumpe, Tank und Unendlich-Rohr an einem Flüssigkeitswagen (Mitte `center` auf der Gleisachse).
--- Laden: Rohr (Nachschub) → Tank → Pumpe → Wagen; Entladen: Wagen → Pumpe → Tank → Rohr (leert).
--- Der Tank-Anschluss zur Gleisseite liegt ein Feld neben seiner Mitte (im Spiel ermittelt).
local function near_offset(r)
  if r[2] == 1 then return { 1, 0 } elseif r[2] == -1 then return { -1, 0 } elseif r[1] == 1 then return { 0, 1 } end
  return { 0, -1 }
end

local function fluid_equip(center, a, r, loads, fluid)
  local at = add(center, a, -0.5)
  local off = near_offset(r)
  local tank_pos = add(add(at, r, 4.5), off, 1)
  entity("pump", add(at, r, 2), { direction = direction_of(loads and { -r[1], -r[2] } or r) })
  local tank = entity("storage-tank", tank_pos)
  local pipe = entity("infinity-pipe", add(add(tank_pos, r, 2), off, 1))
  if pipe then
    pipe.set_infinity_pipe_filter({ name = fluid, percentage = loads and 1 or 0, mode = loads and "at-least" or "exactly" })
  end
  return tank
end

--- Greifarm, der über die Auftrags-Ausgabe (rotes Kabel) geschaltet wird.
local LOADING = { type = "virtual", name = "utl-loading" }
local function switched(pos, grab, comparator)
  local inserter = entity("bulk-inserter", pos, { direction = direction_of(grab) })
  if inserter then
    local behavior = inserter.get_or_create_control_behavior()
    behavior.circuit_enable_disable = true
    behavior.circuit_condition = { first_signal = LOADING, comparator = comparator, constant = 0 }
  end
  return inserter
end

--- Bahnhof, der annimmt und abgibt (Lager, Cleanup mit Angebot), wie im Szenario UTL-Lager:
--- Entlade-Greifarm → Stahlkiste → Umlade-Greifarm → Stahlkiste → Lade-Greifarm. Entladen bei
--- utl-loading = 0, Laden bei utl-loading > 0. Liefert Kisten und geschaltete Greifarme.
local function two_way(center, a, r, out)
  local u = add(center, a, -2.5)
  local l = add(center, a, -0.5)
  out.switched[#out.switched + 1] = switched(add(u, r, 1.5), { -r[1], -r[2] }, "=")
  out.switched[#out.switched + 1] = switched(add(l, r, 1.5), r, ">")
  out.chests[#out.chests + 1] = entity("steel-chest", add(u, r, 2.5))
  entity("fast-inserter", add(add(center, a, -1.5), r, 2.5), { direction = direction_of({ -a[1], -a[2] }) })
  out.chests[#out.chests + 1] = entity("steel-chest", add(l, r, 2.5))
end

--- Abfluss hinter den Kisten eines Abnehmers, geschaltet über ein SR-Latch wie in Marcels Blaupause
--- „SR-Latch (limit)“ (docs/blaupausen/schaltungen_takt_sr-latch.txt): ein Entscheider, Ausgang rot
--- auf den eigenen Eingang zurück. Ab `high` im Bahnhof gibt er signal-check aus und hält es, bis
--- nur noch `low` da sind. Die Abfluss-Greifarme laufen bei signal-check ≠ 0, gedrosselt auf
--- `hand` Stück je Griff – so bleibt der Bahnhof eine Weile voll und leert sich dann nach und nach.
Equipment.LATCH = { high = 2000, low = 200, hand = 2 }
local CHECK = { type = "virtual", name = "signal-check" }

local function latch(first_center, a, r, chests, item)
  local signal = { type = "item", name = item }
  local decider = entity("decider-combinator", add(add(first_center, a, 0.5), r, 4), { direction = direction_of(r) })
  if not decider then return end
  local G, R = { red = false, green = true }, { red = true, green = false }
  decider.get_or_create_control_behavior().parameters = {
    conditions = {
      { first_signal = signal, comparator = "≥", constant = Equipment.LATCH.high, first_signal_networks = G },
      { first_signal = CHECK, comparator = "=", constant = 0, first_signal_networks = R, compare_type = "and" },
      { first_signal = signal, comparator = ">", constant = Equipment.LATCH.low, first_signal_networks = G, compare_type = "or" },
      { first_signal = CHECK, comparator = "≠", constant = 0, first_signal_networks = R, compare_type = "and" },
    },
    outputs = { { signal = CHECK, copy_count_from_input = false, constant = 1 } },
  }
  connect(chests[1], decider, W.circuit_green, W.combinator_input_green)          -- Bestand
  connect(decider, decider, W.combinator_output_red, W.combinator_input_red)      -- Rückkopplung
  local previous, previous_id = decider, W.combinator_output_red --[[@as defines.wire_connector_id]]
  for _, chest in ipairs(chests) do
    local p = chest.position
    local drain = entity("fast-inserter", { p.x + r[1], p.y + r[2] }, { direction = direction_of({ -r[1], -r[2] }) })
    local void = entity("infinity-chest", { p.x + 2 * r[1], p.y + 2 * r[2] })
    if drain and void then
      void.remove_unfiltered_items = true
      drain.inserter_stack_size_override = Equipment.LATCH.hand
      local behavior = drain.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = { first_signal = CHECK, comparator = "≠", constant = 0 }
      connect(previous, drain, previous_id, W.circuit_red)
      previous, previous_id = drain, W.circuit_red
    end
  end
end

--- Ausstattung je Art: provider (Kiste → Wagen), requester/cleanup (Wagen → Kiste, die alles
--- vernichtet), fuel (Kohle → Lok), storage bzw. cleanup mit `spec.offer` (annehmen und abgeben).
--- Kisten von Anbietern, Abnehmern und Lagern werden mit der Station verdrahtet (grün: Bestand).
--- Liefert bei geschalteten Bahnhöfen { poles, inserters } für das rote Kabel der Auftrags-Ausgabe.
function Equipment.equip(c, stop, f, r, spec, signal_target)
  ctx = c
  local kind, item = spec.kind, spec.item
  local a = { -f[1], -f[2] } -- vom Zugkopf nach hinten
  local base = add(xy(stop.position), r, -2)
  local fluid = item and prototypes.fluid[item] ~= nil
  local both = kind == "storage" or (kind == "cleanup" and spec.offer)
  local slots = kind == "fuel" and { 0 } or fluid and { 1, 2 } or { 1, 2, 3, 4 }
  if spec.max_length and not fluid then
    -- feste Zuglänge: nur so viele Wagenplätze, wie der Zug Wagen hat (sieht man am Bahnhof)
    slots = {}
    for k = 1, spec.max_length - 1 do slots[k] = k end
  end
  local positions = kind == "fuel" and { -1.5, 0.5 } or { -2.5, -0.5, 1.5 }
  local chests = {}
  local out = { chests = chests, switched = {}, poles = {} }
  for _, k in ipairs(slots) do
    local center = add(base, a, 3 + 7 * k)
    out.poles[#out.poles + 1] = entity("medium-electric-pole", add(add(center, r, 3.5), a, -3.5))
    if fluid then
      chests[#chests + 1] = fluid_equip(center, a, r, kind == "provider", item)
    elseif both then
      two_way(center, a, r, out)
    end
    for _, t in ipairs((fluid or both) and {} or positions) do
      local at = add(center, a, t)
      -- Richtung eines Greifarms = Seite, von der er greift (Bulk-Greifarme erlauben keine
      -- frei gesetzten Greif-/Ablagepositionen). Laden: von der Kiste (rechts), Entladen: vom Wagen.
      local loads = kind == "provider" or kind == "fuel"
      local grab = loads and r or { -r[1], -r[2] }
      local inserter = entity("bulk-inserter", add(at, r, 1.5), { direction = direction_of(grab) })
      local chest = entity(spec.latch and "steel-chest" or "infinity-chest", add(at, r, 2.5))
      if inserter and chest then
        if spec.latch then
          -- Stahlkiste: Inhalt bleibt, bis der Abfluss (latch) ihn holt
        elseif loads then
          chest.infinity_container_filters = { { index = 1, name = kind == "fuel" and "coal" or item,
            count = kind == "fuel" and 50 or 2000, mode = "at-least" } }
        else
          chest.remove_unfiltered_items = true -- vernichtet alles, was hineinkommt
        end
        chests[#chests + 1] = chest
      end
    end
  end
  local last = add(base, a, 3 + 7 * slots[#slots])
  entity("medium-electric-pole", add(add(last, r, 3.5), a, 3.5))
  local first = add(base, a, 3 + 7 * slots[1])
  local eei = entity("electric-energy-interface", add(add(first, r, 5), a, -4))
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
  -- Kisten in einer Kette verdrahten, die erste mit der Haltestelle bzw. dem Combinator-Eingang
  -- (Beispiel für Spieler: so liest die Station ihren Bestand).
  if (kind == "provider" or kind == "requester" or both) and #chests > 0 then
    for i = 2, #chests do connect(chests[i - 1], chests[i]) end
    local target = signal_target or stop.get_wire_connector(W.circuit_green, true)
    if not chests[1].get_wire_connector(W.circuit_green, true).connect_to(target) then
      ctx.stats.wires_failed = ctx.stats.wires_failed + 1
      ctx.stats.wire_fail_at = (ctx.stats.wire_fail_at or "") .. " " .. stop.backer_name
    end
  end
  if spec.latch and #chests > 0 then latch(add(base, a, 3 + 7 * slots[1]), a, r, chests, item) end
  if both then
    -- rotes Kabel: Mast zu Mast, jeder Greifarm an den Mast seines Wagenplatzes
    for i, pole in ipairs(out.poles) do
      if i > 1 then connect(out.poles[i - 1], pole, W.circuit_red) end
      connect(pole, out.switched[2 * i - 1], W.circuit_red)
      connect(pole, out.switched[2 * i], W.circuit_red)
    end
    return out
  end
end

--- Zug aus Lok und `cars` Wagen an `front` (Kopf, Richtung nach hinten, Fahrtrichtung) mit
--- Fahrplan zum Depot `depot_name`.
function Equipment.train(c, front, cars, depot_name, wagon)
  local surface, force = c.surface, c.force
  local loco = surface.create_entity({ name = "locomotive", position = front.head, direction = front.dir, force = force })
  if not loco then return nil end
  for i = 1, cars do
    surface.create_entity({ name = wagon or "cargo-wagon", position = add(front.head, front.back, 7 * i),
      direction = front.dir, force = force })
  end
  loco.insert({ name = "coal", count = 150 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = depot_name, wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  return loco.train
end

return Equipment
