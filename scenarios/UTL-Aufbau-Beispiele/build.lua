--- Bausteine für die Aufbau-Beispiele: Gleise des Rundkurses, Ladestellen am Wagen, Strom, Schaltungen
--- aus Marcels Blaupausen-Buch „Circuits“, Anzeigefelder und Beschriftungen. Jedes Beispiel baut
--- mit diesen Bausteinen in seinem eigenen Bereich (Ursprung `origin`).
---
--- Maße wie im Szenario „UTL-Beispiele“: Der erste Wagen steht 10 Felder hinter dem Gleis der
--- Haltestelle; Greifarm 1,5 Felder neben dem Gleis, Kiste 2,5 Felder daneben.
local Ring = require("__UTLogistics__/scenarios/UTL-Beispiele/rundkurs")
local BOOK = require("__UTLogistics__/scenarios/UTL-Aufbau-Beispiele/circuits")

local Build = {}

local W = defines.wire_connector_id
Build.W = W

local NAMES = {
  S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", T = "utl-train-stop", V = "train-stop", C = "utl-station-combinator",
}
local RAILS = { S = true, A = true, B = true, H = true }

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor
Build.DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } }, [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } }, [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

local surface, force
local problems = {}

--- Für ein Beispiel: Oberfläche und Team setzen, Problemliste leeren.
function Build.begin(s, f)
  surface, force = s, f
  problems = {}
end

--- Was nicht gesetzt werden konnte (für das Protokoll).
function Build.problems() return problems end

function Build.add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end
local add = Build.add

--- Richtung (16er) zu einem Einheitsvektor.
function Build.direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

local function on_rail(position, half)
  return #surface.find_entities_filtered({
    area = { { position[1] - half, position[2] - half }, { position[1] + half, position[2] + half } },
    type = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "rail-signal",
      "rail-chain-signal", "train-stop" },
  }) > 0
end

--- Objekt setzen. Läge es auf einem Gleis, wird es nicht gesetzt und gemeldet (`check_rail`, Standard an).
function Build.entity(name, position, extra, check_rail)
  if check_rail ~= false and on_rail(position, 0.45) then
    problems[#problems + 1] = name .. " auf Gleis bei " .. position[1] .. "," .. position[2]
    return nil
  end
  local spec = { name = name, position = position, force = force }
  for k, v in pairs(extra or {}) do spec[k] = v end
  local made = surface.create_entity(spec)
  if not made then problems[#problems + 1] = name .. " bei " .. position[1] .. "," .. position[2] end
  return made
end
local entity = Build.entity

--- Greifarm bei `at`; `from` = Seite, von der er greift (er legt auf der Gegenseite ab).
function Build.inserter(at, from)
  return entity("bulk-inserter", at, { direction = Build.direction_of(from) })
end

function Build.green(a, b, b_connector)
  return a.get_wire_connector(W.circuit_green, true).connect_to(b.get_wire_connector(b_connector or W.circuit_green, true))
end

--- Rundkurs aus Marcels Blaupause „rundkurs_scenarios“ um `origin` verschoben (gerade Werte, sonst passt
--- das Gleisraster nicht). Liefert Haltestellen nach Lage in der Blaupause und Haltestelle → Station.
function Build.ring(origin)
  local stops, combinators = {}, {}
  for _, only_rails in ipairs({ true, false }) do
    for _, e in ipairs(Ring) do
      if (RAILS[e[1]] or false) == only_rails then
        local raise = e[1] == "T" or e[1] == "C"
        local made = entity(NAMES[e[1]], { origin[1] + e[2], origin[2] + e[3] }, { direction = e[4], raise_built = raise },
          false)
        if made and (e[1] == "T" or e[1] == "V") then stops[e[2] .. "/" .. e[3]] = made end
        if made and e[1] == "C" then combinators[#combinators + 1] = made end
      end
    end
  end
  -- Jeder Stations-Kombinator gehört zur normalen Haltestelle direkt neben ihm
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

--- Station an einer Haltestelle: Name setzen, liefert Haltestelle, Station (Haltestelle oder Kombinator)
--- und den Anschluss für Kabel zur Station.
function Build.station(stops, station_of, key, name)
  local stop = stops[key]
  stop.backer_name = name
  local st = station_of[stop] or stop
  local input = st.name == "utl-station-combinator" and W.combinator_input_green or W.circuit_green
  return stop, st, input
end

--- Wagenplatz: Mitte des ersten Wagens hinter der Haltestelle, dazu Vorwärts-/Rechtsvektor.
function Build.wagon_spot(stop)
  local d = Build.DIRS[stop.direction]
  local rail = stop.connected_rail
  local base = rail and { rail.position.x, rail.position.y } or add({ stop.position.x, stop.position.y }, d.r, -2)
  return add(add(base, d.f, -10), d.f, -0.5), d
end

--- Strom für eine Ladestelle: Energie-Schnittstelle und zwei Umspannwerke (Ladestelle und Schaltungen).
--- `spots` (optional) = { eei = {r, f}, ladestelle = {r, f}, schaltungen = {r, f} } in Feldern neben/entlang des
--- Gleises, wenn dort das nächste Gleis zu nah liegt.
function Build.power(at, d, spots)
  spots = spots or {}
  local function at_rf(rf) return add(add(at, d.r, rf[1]), d.f, rf[2]) end
  local eei = entity("electric-energy-interface", at_rf(spots.eei or { 7, 5 }))
  if eei then eei.power_production = 2000000; eei.electric_buffer_size = 20000000 end
  entity("substation", at_rf(spots.ladestelle or { 4, 5 }))
  entity("substation", at_rf(spots.schaltungen or { 9, -5 }))
end

--- Kiste per Kabel an die Station (über einen Mast – eine Leitung reicht nur 9 Felder).
function Build.wire_to_station(chest, at, d, st, input)
  local pole = entity("medium-electric-pole", add(add(at, d.r, 2.5), d.f, 5))
  if chest and pole then Build.green(chest, pole); Build.green(pole, st, input) end
end

--- Anzeigefeld per Kabel an der Station (UTL zeigt dort den Zustand).
function Build.panel(at, st, input)
  local p = entity("display-panel", at)
  if p then Build.green(p, st, input) end
end

--- Beschriftung über dem Boden (LocalisedString).
function Build.label(text, at)
  rendering.draw_text({ text = text, surface = surface, target = at, color = { 1, 1, 1 }, scale = 1.4,
    alignment = "center" })
end

--- Zug (Lok + Güterwagen + Lok) am Depot.
function Build.train(stop)
  local spot, d = Build.wagon_spot(stop)
  local back = { -d.f[1], -d.f[2] }
  spot = add(spot, d.f, 0.5)
  local l1 = entity("locomotive", add(spot, back, -7), { direction = stop.direction }, false)
  entity("cargo-wagon", spot, { direction = stop.direction }, false)
  local l2 = entity("locomotive", add(spot, back, 7), { direction = stop.direction }, false)
  if not (l1 and l2) then return end
  for _, l in ipairs({ l1, l2 }) do l.insert({ name = "coal", count = 200 }) end
  local s = l1.train.get_schedule()
  s.add_record({ station = "Depot", wait_conditions = { { type = "inactivity", ticks = 300 } } })
  s.go_to_station(1)
  l1.train.manual_mode = false
end

--- Ein Modul aus dem Buch „Circuits“ bauen (Index 1 = erstes Modul). `replace` ersetzt Platzhalter
--- (parameter-0/1) durch Signale, `constants` Vergleichswerte. Liefert die gebauten Objekte.
local book_stack
function Build.module(index, position, replace, constants)
  if not (book_stack and book_stack.valid) then
    book_stack = game.create_inventory(1)[1]
    book_stack.import_stack(BOOK)
  end
  local copy = game.create_inventory(1)[1]
  copy.set_stack(book_stack.get_inventory(defines.inventory.item_main)[index])
  local ents = copy.get_blueprint_entities()
  local function walk(t)
    if type(t) ~= "table" then return end
    if t.name and replace[t.name] then
      local r = replace[t.name]
      t.type, t.name, t.quality = r.type, r.name, "normal"
    end
    for k, v in pairs(t) do
      if k == "constant" and constants and constants[v] then t[k] = constants[v] end
      walk(v)
    end
  end
  walk(ents)
  copy.set_blueprint_entities(ents)
  local built = {}
  for _, ghost in pairs(copy.build_blueprint({ surface = surface, force = force, position = position,
    build_mode = defines.build_mode.forced })) do
    if ghost.valid then
      local _, e = ghost.revive()
      if e then
        e.disabled_by_script = false -- wiederbelebte Geister stehen sonst still
        built[#built + 1] = e
      else
        problems[#problems + 1] = "Modul " .. index
      end
    end
  end
  return built
end

function Build.find(list, name)
  for _, e in ipairs(list) do if e.name == name then return e end end
end

--- Taktgeber (Buch, Modul 1 „Clock module“): zählt C bis T (60 Ticks) hoch. Der Greifarm hängt am roten
--- Ausgang und arbeitet einmal je Takt (C = 1), mit `per_pulse` Gegenständen.
function Build.clock(position, ins, per_pulse)
  local built = Build.module(1, position, {
    ["parameter-0"] = { type = "virtual", name = "signal-C" },
    ["parameter-1"] = { type = "virtual", name = "signal-T" },
  })
  local decider = Build.find(built, "decider-combinator")
  local const = Build.find(built, "constant-combinator")
  if not (decider and const and ins) then problems[#problems + 1] = "Taktgeber"; return end
  -- Freigabe C = 1 und Takt T = 60 Ticks (die Blaupause lässt die Werte beim Setzen abfragen)
  local section = const.get_or_create_control_behavior().get_section(1)
  section.filters = {
    { value = { type = "virtual", name = "signal-C", quality = "normal" }, min = 1 },
    { value = { type = "virtual", name = "signal-T", quality = "normal" }, min = 60 },
  }
  decider.get_wire_connector(W.combinator_output_red, true).connect_to(ins.get_wire_connector(W.circuit_red, true))
  local b = ins.get_or_create_control_behavior() --[[@as LuaInserterControlBehavior]]
  b.circuit_enable_disable = true
  b.circuit_condition = { first_signal = { type = "virtual", name = "signal-C" }, comparator = "=", constant = 1 }
  ins.inserter_stack_size_override = per_pulse
end

--- SR-Latch „Auffüllen“ (Buch, Modul 2): ✓ an, sobald `item` am grünen Eingang unter `low` fällt, bis
--- `high` erreicht ist. Der Greifarm `ins` arbeitet, solange ✓ anliegt. Liefert den Entscheider.
function Build.topup_latch(position, item, low, high, ins)
  local built = Build.module(2, position, {
    ["parameter-0"] = { type = "item", name = item },
    ["parameter-1"] = { type = "virtual", name = "signal-check" },
  }, { [50] = low, [100] = high })
  local decider = Build.find(built, "decider-combinator")
  if not (decider and ins) then problems[#problems + 1] = "SR-Latch"; return nil end
  decider.get_wire_connector(W.combinator_output_red, true).connect_to(ins.get_wire_connector(W.circuit_red, true))
  local b = ins.get_or_create_control_behavior() --[[@as LuaInserterControlBehavior]]
  b.circuit_enable_disable = true
  b.circuit_condition = { first_signal = { type = "virtual", name = "signal-check" }, comparator = ">", constant = 0 }
  return decider
end

return Build
