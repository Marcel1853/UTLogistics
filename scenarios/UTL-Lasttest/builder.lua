--- Baut das Testnetz auf einer eigenen Oberfläche mit Labor-Boden:
---   * Gitter aus „City Block 4“ (ohne Brücken) aus Marcels Blaupausen-Buch „Schienensystem“:
---     4-gleisige Korridore (2 je Richtung, Rechtsverkehr), Kreuzungen mit Kettensignalen,
---     Rastermaß 224. Züge können an jeder Kreuzung abbiegen und nehmen den kürzesten Weg.
---   * Bahnhöfe auf Nebengleisen am jeweils äußeren Korridorgleis, eins je Seite und
---     Korridorstück (zwischen zwei Kreuzungen), mit Ketten-/Blocksignalen.
---   * Anbieter/Abnehmer/Tankstelle/Cleanup mit Unendlich-Kisten, Greifarmen und Strom.
---
--- Abzweig-/Einmündungsstücke (Factorio 2.x) wurden per Suche im Spiel ermittelt (docs/PLAN.md).
--- Angaben relativ zu einem geraden Gleisstück (ungerade Koordinaten).
local CityBlock = require("__UTLogistics__/scenarios/UTL-Lasttest/cityblock")
local Places = require("__UTLogistics__/scenarios/UTL-Lasttest/places")
local Equipment = require("__UTLogistics__/scenarios/UTL-Lasttest/equipment")
local Blocks = require("__UTLogistics__/scenarios/UTL-Lasttest/blocks")

local Builder = {}

local Track = require("__UTLogistics__/scenarios/UTL-Lasttest/track-pieces")
local O, RIGHT, E_TO_SE, SE_TO_E, DIAGONAL_SE, DIVERGE, MERGE = Track.O, Track.RIGHT, Track.E_TO_SE, Track.SE_TO_E, Track.DIAGONAL_SE, Track.DIVERGE, Track.MERGE

local direction_of = Equipment.direction_of

local SPAN = 160     -- Abzweig bis Einmündung: Bahnsteig + 2 Warteplätze (Züge bis 5 Teile)
local GAP = 6        -- Platz für das Kettensignal vor dem Abzweig
local BLOCK = 224    -- Rastermaß der City Blocks
local YARD_TRACKS = 12 -- Depotgleise je Abstellbahnhof (passt in das Blockinnere)
local YARD_LENGTH = 48 -- Länge eines Depotgleises (Züge bis 5 Teile)

local stats = { rails = 0, failed = 0, signals = 0, signals_failed = 0, equipment = 0, wires_failed = 0, blocks = 0 }
local surface, force
-- Was gebaut wird: `tracks` = Gleise und Signale, `stations` = Haltestellen, Geräte, Züge, Masten.
-- Das Szenario UTL-Lasttest hat das Gleisnetz schon in der Karte und baut nur noch die Stationen.
local tracks, stations = true, true
-- Zuglimit (Vanilla) an Depots, Tankstellen und Cleanups setzen? Der Lasttest regelt das über
-- UTLs „max. Züge“ (cfg.vanilla_limits = false), die übrigen Szenarien behalten das Zuglimit.
local vanilla_limits = true

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end
local function xy(position) return { position.x, position.y } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] end

local function rail(name, dir, pos)
  if not tracks then return nil end
  local e = surface.create_entity({ name = name, position = pos, direction = dir % 16, force = force })
  if e then stats.rails = stats.rails + 1 else stats.failed = stats.failed + 1 end
  return e
end

local function pieces(list, base)
  for _, p in ipairs(list) do rail(p[1], p[2], { base[1] + p[3], base[2] + p[4] }) end
end

--- Gerade von `from` in Fahrtrichtung `o` über `length` Felder (beide Enden eingeschlossen).
local function straight(o, from, length)
  for k = 0, length, 2 do rail("straight-rail", O[o].rail, add(from, O[o].f, k)) end
end

--- Signal rechts vom Gleis für Fahrtrichtung `o`, gesucht entlang des Gleises.
--- `chain` = Kettensignal (vor Abzweigen: Zug fährt nur los, wenn sein Weg dahinter frei ist).
local function signal(o, pos, count_failure, chain, only_back, only_forward)
  if not tracks then return true end
  local dir = (O[o].dir + 8) % 16
  local name = chain and "rail-chain-signal" or "rail-signal"
  local offsets = only_back and { 0, -1, -2, -3, -4 } or only_forward and { 0, 1, 2, 3, 4 }
    or { 0, 1, -1, 2, -2, 3, -3, 4, -4 }
  for _, d in ipairs(offsets) do
    local p = add(pos, O[o].f, d)
    if surface.can_place_entity({ name = name, position = p, direction = dir, force = force }) then
      surface.create_entity({ name = name, position = p, direction = dir, force = force })
      stats.signals = stats.signals + 1
      return true
    end
  end
  if count_failure ~= false then stats.signals_failed = stats.signals_failed + 1 end
  return false
end

--- Nebengleis mit Haltestelle, Abzweig bei `pa` (Hauptgleis) in Fahrtrichtung `o`.
local function siding(o, pa, spec)
  local f, r = O[o].f, O[o].r
  local pb = add(pa, f, SPAN)
  pieces(DIVERGE[o], pa)
  pieces(MERGE[o], pb)
  local from = add(add(pa, f, 20), r, 6)
  straight(o, from, SPAN - 40)
  -- Signale wie in Marcels Blaupause docs/blaupausen/kreisel_signale.txt: Abzweig und Einmündung
  -- liegen kurz vor bzw. hinter einem Kreisel. Vor der Einmündung (Hauptgleis und Ausfahrt) und
  -- zwischen Einmündung und Kreisel Kettensignale, damit kein Zug in der Einmündung stehen bleibt
  -- und das Hauptgleis zustellt; hinter dem Abzweig ein Blocksignal, damit ein wartender Zug auf dem
  -- Hauptgleis den Abzweig frei lässt.
  signal(o, add(add(pa, f, -(GAP / 2 + 0.5)), r, 1.5), true, true) -- Kettensignal vor dem Abzweig
  signal(o, add(add(pa, f, 9.5), r, 1.5))                          -- Hauptgleis hinter dem Abzweig
  signal(o, add(add(pa, f, 18.5), r, 7.5))                         -- Einfahrt Nebengleis
  signal(o, add(add(pa, f, SPAN / 2 + 0.5), r, 1.5))               -- Hauptgleis zwischen Abzweig und Einmündung
  signal(o, add(add(pb, f, -9.5), r, 1.5), true, true)             -- Hauptgleis vor der Einmündung
  signal(o, add(add(pb, f, -21.5), r, 7.5), true, true)            -- Ausfahrt vor der Einmündung
  signal(o, add(add(pb, f, 1.5), r, 1.5), true, true)              -- zwischen Einmündung und Kreisel
  -- zwei Warteplätze hinter dem Bahnsteig (je eine Zuglänge), damit bis zu 3 Züge anstehen können
  signal(o, add(add(pb, f, -61.5), r, 7.5))
  signal(o, add(add(pb, f, -99.5), r, 7.5))
  if not stations then return nil end
  -- Bauart: UTL-Haltestelle oder normale Haltestelle + UTL-Stations-Combinator daneben
  local stop = surface.create_entity({ name = spec.combinator and "train-stop" or "utl-train-stop",
    position = add(add(pb, f, -26), r, 8), direction = O[o].dir, force = force, raise_built = true })
  stop.backer_name = spec.combinator and spec.kind ~= "depot" and ("[item=utl-station-combinator] " .. spec.name)
    or spec.name
  -- Zuglimit (Vanilla) nur an Depots (ein Zug je Gleis), Tankstellen und Cleanups (Bahnsteig + 2
  -- Warteplätze) und nur, wenn gewünscht. Anbieter, Abnehmer und Lager regelt immer UTLs
  -- „max. Züge“ – der Lasttest prüft den Mod, nicht Vanilla (Wunsch Marcel).
  if vanilla_limits and spec.kind == "depot" then
    stop.trains_limit = 1
  elseif vanilla_limits and (spec.kind == "fuel" or spec.kind == "cleanup") then
    stop.trains_limit = 3
  end
  spec.stop = stop
  local signal_target
  if spec.combinator then
    -- Anbieter: hinter der Haltestelle (nah an den Kisten); sonst davor.
    -- (Flüssigkeiten: Tanks liegen weiter außen – hinter der Haltestelle reicht das Kabel)
    local fluid = spec.item and prototypes.fluid[spec.item] ~= nil
    local along = (spec.kind == "provider" or fluid) and -2 or 2
    local combinator = surface.create_entity({ name = "utl-station-combinator",
      position = add(xy(stop.position), f, along), direction = O[o].dir, force = force })
    spec.combinator_entity = combinator
    if combinator then
      stats.combinators = (stats.combinators or 0) + 1
      -- Ausgang → Haltestelle (so weiß UTL, welche Haltestelle zum Combinator gehört)
      combinator.get_wire_connector(defines.wire_connector_id.combinator_output_green, true)
        .connect_to(stop.get_wire_connector(defines.wire_connector_id.circuit_green, true))
      -- erst jetzt melden: UTL ordnet den Combinator beim Bau über dieses Kabel der Haltestelle zu
      script.raise_script_built({ entity = combinator })
      signal_target = combinator.get_wire_connector(defines.wire_connector_id.combinator_input_green, true)
    end
  end
  if spec.kind ~= "depot" then
    spec.bay = Equipment.equip({ surface = surface, force = force, stats = stats }, stop, f, r, spec, signal_target)
  end
  -- Zugposition: Lok 3 Felder hinter der Haltestelle, Wagen je 7 Felder weiter
  local head = add(add(xy(stop.position), r, -2), f, -3)
  return { head = head, back = { -f[1], -f[2] }, dir = O[o].dir }
end

--- Liefert die Depot-Haltestellen (mit Zugposition).
local function yard(X, Y, spec_of)
  local row = Y + 101             -- Zufahrt (waagerecht)
  local ya = row + 14             -- Abzweig am Korridorgleis
  local K = YARD_TRACKS
  local row_exit = row + 20 + 6 * (K - 1)
  -- Blocksignale des City Blocks an Ein- und Ausfahrt entfernen
  for _, area in ipairs({
    { { X + 62, ya - 24 }, { X + 63, ya + 10 } },
    { { X + 257, row_exit - 4 }, { X + 258, row_exit + 24 } },
  }) do
    if not tracks then break end
    for _, sig in pairs(surface.find_entities_filtered({ area = area, type = { "rail-signal", "rail-chain-signal" } })) do sig.destroy() end
  end
  -- Einfahrt
  signal("N", { X + 62.5, ya + 4.5 }, true, true, true)            -- Kettensignal vor dem Abzweig
  pieces(RIGHT.N, { X + 61, ya })
  local xd = X + 77
  straight("E", { X + 75, row }, 2)
  signal("E", { X + 75.5, row + 1.5 }, true, true)                  -- vor der Weichenstraße
  pieces(E_TO_SE, { xd, row })
  local d0 = { xd + 11, row + 5 }
  for j = 0, 3 * (K - 1) do rail("straight-rail", DIAGONAL_SE, add(d0, { 1, 1 }, 2 * j)) end
  -- Sammelstraße
  local c0 = { xd + 22 + YARD_LENGTH + 11, row + 15 }
  for j = 0, 3 * (K - 1) do rail("straight-rail", DIAGONAL_SE, add(c0, { 1, 1 }, 2 * j)) end
  local clast = add(c0, { 1, 1 }, 6 * (K - 1))
  pieces(SE_TO_E, clast)
  local x_exit = clast[1] + 11
  straight("E", { x_exit, row_exit }, X + 245 - x_exit)
  signal("E", { X + 243.5, row_exit + 1.5 }, true, true)            -- vor der Einmündung in den Korridor
  pieces(RIGHT.E, { X + 245, row_exit })
  -- Signal des Korridors vor der Einmündung der Ausfahrt: Kettensignal
  if tracks then
    local at = { X + BLOCK + 33.5, Y + 159.5 }
    for _, sig in pairs(surface.find_entities_filtered({ type = "rail-signal",
      area = { { at[1] - 0.6, at[2] - 0.6 }, { at[1] + 0.6, at[2] + 0.6 } } })) do
      sig.destroy()
      signal("S", at, true, true)
    end
  end
  -- Depotgleise
  local stops = {}
  for k = 0, K - 1 do
    local dk = add(d0, { 1, 1 }, 6 * k)
    pieces(SE_TO_E, dk)
    local yk, xs = row + 10 + 6 * k, xd + 22 + 6 * k
    local xe = xs + YARD_LENGTH
    straight("E", { xs, yk }, YARD_LENGTH)
    pieces(E_TO_SE, { xe, yk })
    signal("E", { xs + 1.5, yk + 1.5 })                             -- Einfahrt Depotgleis
    signal("E", { xe - 0.5, yk + 1.5 }, true, true)                 -- Ausfahrt Depotgleis (vor der Sammelstraße)
    if stations then
      local spec = spec_of(k)
      local stop = surface.create_entity({ name = spec.combinator and "train-stop" or "utl-train-stop",
        position = { xe - 3, yk + 2 }, direction = O.E.dir, force = force, raise_built = true })
      stop.backer_name = spec.name
      if vanilla_limits then stop.trains_limit = 1 end
      spec.stop = stop
      if spec.combinator then
        spec.combinator_entity = surface.create_entity({ name = "utl-station-combinator",
          position = { xe - 5, yk + 2 }, direction = O.E.dir, force = force })
        if spec.combinator_entity then
          stats.combinators = (stats.combinators or 0) + 1
          spec.combinator_entity.get_wire_connector(defines.wire_connector_id.combinator_output_green, true)
            .connect_to(stop.get_wire_connector(defines.wire_connector_id.circuit_green, true))
          script.raise_script_built({ entity = spec.combinator_entity }) -- erst verkabelt melden
        end
      end
      stops[#stops + 1] = { spec = spec, front = { head = { xe - 6, yk }, back = { -1, 0 }, dir = O.E.dir } }
    end
  end
  stats.yards = (stats.yards or 0) + 1
  return stops
end

local NAMES = { S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", P = "big-electric-pole", R = "radar" }
local EXTRAS = { P = true, R = true } -- Masten/Radare erst nach den Bahnhöfen (die haben Vorrang)

--- Einen City Block mit Ecke (x0, y0) setzen. Überlappende Stücke des Nachbarblocks (gemeinsame
--- Korridore) gibt es schon – create_entity schlägt dann einfach fehl.
local function city_block(x0, y0, extras)
  if not extras then stats.blocks = stats.blocks + 1 end
  if (extras and not stations) or (not extras and not tracks) then return end
  for _, e in ipairs(CityBlock) do
    if (EXTRAS[e[1]] or false) == extras then
      local ok = surface.create_entity({ name = NAMES[e[1]], position = { x0 + e[2], y0 + e[3] }, direction = e[4], force = force })
      if extras and ok then stats[e[1] == "R" and "radars" or "poles"] = (stats[e[1] == "R" and "radars" or "poles"] or 0) + 1 end
    end
  end
  if extras then
    -- Strom für Radare und Masten: Energiequelle mit Mittelmast neben einem Großmast der Blockmitte
    local eei = surface.create_entity({ name = "electric-energy-interface", position = { x0 + 48, y0 + 90 }, force = force })
    if eei then
      eei.power_production = 2000000
      eei.electric_buffer_size = 20000000
    end
    surface.create_entity({ name = "medium-electric-pole", position = { x0 + 48.5, y0 + 86.5 }, force = force })
  end
end

--- Signale des City Blocks auf der Bahnhofsseite des Außengleises entfernen (dort liegen jetzt
--- Abzweig und Einmündung; die Bahnhofs-Signale setzt siding()).
local function clear_signals(o, pa)
  if not tracks then return end
  local f, r = O[o].f, O[o].r
  local from = add(add(pa, f, -10), r, 1.5)
  local to = add(add(pa, f, SPAN + 6), r, 1.5)
  local area = { { math.min(from[1], to[1]) - 0.6, math.min(from[2], to[2]) - 0.6 },
    { math.max(from[1], to[1]) + 0.6, math.max(from[2], to[2]) + 0.6 } }
  for _, sig in pairs(surface.find_entities_filtered({ area = area, type = { "rail-signal", "rail-chain-signal" } })) do
    sig.destroy()
  end
end

--- Kreisel-Seiten ohne Bahnhof (Kartenrand, Depot-Blöcke): wie an den übrigen Kreiseln das
--- Ausfahrtsignal hinter die Einmündung des Kreisels setzen (sonst steht es davor) und das
--- Einfahrt-Kettensignal vor den ersten Abzweig. `used` = Schlüssel der gebauten Nebengleise.
local function plain_crossings(n, ox, oy, used)
  local limit = BLOCK * n + 100
  local function inside(p) return p[1] >= ox and p[2] >= oy and p[1] <= ox + limit and p[2] <= oy + limit end
  local function fix(o, pa)
    if used[o .. ":" .. pa[1] .. ":" .. pa[2]] then return end
    local f, r = O[o].f, O[o].r
    local old = add(add(pa, f, -7.5), r, 1.5)
    if inside(old) then
      for _, sig in pairs(surface.find_entities_filtered({ type = "rail-signal",
        area = { { old[1] - 0.6, old[2] - 0.6 }, { old[1] + 0.6, old[2] + 0.6 } } })) do
        sig.destroy()
        signal(o, add(add(pa, f, -3.5), r, 1.5), false)
      end
    end
    -- Einfahrt: das Kettensignal des Kreisels liegt hinter seinem ersten Abzweig → davor verschieben
    local entry = add(add(pa, f, SPAN + 5.5), r, 1.5)
    if inside(entry) then
      for _, sig in pairs(surface.find_entities_filtered({ type = "rail-chain-signal",
        area = { { entry[1] - 0.6, entry[2] - 0.6 }, { entry[1] + 0.6, entry[2] + 0.6 } } })) do
        sig.destroy()
        signal(o, add(add(pa, f, SPAN + 1.5), r, 1.5), false, true)
      end
    end
  end
  for k = 0, n do
    for l = -1, n do
      local x, y0 = BLOCK * k + ox, BLOCK * l + oy
      fix("S", { x + 35, y0 + 81 })
      fix("N", { x + 61, y0 + 239 })
      local y, x0 = BLOCK * k + oy, BLOCK * l + ox
      fix("W", { x0 + 239, y + 35 })
      fix("E", { x0 + 81, y + 61 })
    end
  end
end

--- Alles bauen. Liefert Oberfläche, Stationen, Züge und Bereich.
--- Optional (andere Szenarien): `cfg.surface` = Name der Oberfläche; `cfg.assign(places, span)`
--- belegt die Bahnhofsplätze selbst (Liste von Specs je Platz, nil = Platz bleibt frei); ein Spec
--- mit kind = "depot" und `cars` wird ein Depot auf dem Nebengleis mit einem Zug.
--- `cfg.mode`: "track" = nur Gleise und Signale, "stations" = nur alles andere (das Gleisnetz liegt
--- schon in der Karte, gebaut mit "track" aus demselben `cfg`), sonst alles.
function Builder.build(cfg)
  tracks, stations = cfg.mode ~= "stations", cfg.mode ~= "track"
  vanilla_limits = cfg.vanilla_limits ~= false
  local name = cfg.surface or "utl-lasttest"
  surface = game.surfaces[name] or game.create_surface(name)
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  -- Team des Bauwerks: `cfg.force` gilt für alles, `depot.force`/`spec.force` je Station
  -- (Szenario UTL-Teams baut damit vier Teams auf eine Karte).
  local base = game.forces[cfg.force or "player"] or game.forces["player"]
  force = base
  local n = cfg.grid
  -- Versatz auf der Oberfläche: mehrere Raster nebeneinander (Szenario UTL-Teams baut so vier
  -- getrennte City-Block-Raster, die sich nicht berühren).
  local ox, oy = (cfg.origin or {})[1] or 0, (cfg.origin or {})[2] or 0
  stats = { rails = 0, failed = 0, signals = 0, signals_failed = 0, equipment = 0, wires_failed = 0, blocks = 0 }
  local size = BLOCK * n + 320
  surface.request_to_generate_chunks({ ox + size / 2, oy + size / 2 }, math.ceil(size / 64) + 1)
  surface.force_generate_chunk_requests()

  for kx = 0, n - 1 do
    for ky = 0, n - 1 do city_block(BLOCK * kx + ox, BLOCK * ky + oy, false) end
  end

  -- Depot-Blöcke sind reine Depot-Blöcke (Wunsch Marcel): an keiner ihrer vier Seiten liegen
  -- Bahnhöfe (die Nebengleise lägen im Blockinneren).
  local skip = {}
  for _, depot in ipairs(cfg.depots) do
    for _, b in ipairs(depot.blocks) do
      local X, Y = BLOCK * b[1] + ox, BLOCK * b[2] + oy
      skip["N:" .. (X + 61) .. ":" .. (Y + 239)] = true
      skip["S:" .. (X + BLOCK + 35) .. ":" .. (Y + 81)] = true
      skip["E:" .. (X + 81) .. ":" .. (Y + 61)] = true
      skip["W:" .. (X + 239) .. ":" .. (Y + BLOCK + 35)] = true
    end
  end

  local built = { surface = surface, stations = {}, trains = {} }
  local count = 0
  local function next_combinator()
    count = count + 1
    return count % 4 == 0 -- jede vierte Station: normale Haltestelle + UTL-Combinator
  end

  -- Depots in ihren Blöcken
  for d, depot in ipairs(cfg.depots) do
    force = game.forces[depot.force or ""] or base
    for _, b in ipairs(depot.blocks) do
      local stops = yard(BLOCK * b[1] + ox, BLOCK * b[2] + oy, function()
        return { kind = "depot", depot = d, name = depot.name, combinator = next_combinator() }
      end)
      for _, entry in ipairs(stops) do
        built.stations[#built.stations + 1] = entry.spec
        local t = Equipment.train({ surface = surface, force = force }, entry.front, depot.cars, depot.name, depot.wagon)
        if t then built.trains[#built.trains + 1] = t end
      end
    end
  end

  -- Stationen auf die Bahnhofsplätze (Reihenfolge der Plätze: zeilenweise)
  local places = Places.slots(n, skip, ox, oy)
  local specs = cfg.assign and cfg.assign(places, BLOCK * n) or Places.assign(cfg, places, BLOCK * n)
  local used = {}
  for i, place in ipairs(places) do
    local spec = specs[i]
    if spec then
      used[place.o .. ":" .. place.pa[1] .. ":" .. place.pa[2]] = true
      force = game.forces[spec.force or ""] or base
      -- Bahnhöfe, die annehmen und abgeben, schaltet die Auftrags-Ausgabe der UTL-Haltestelle
      spec.combinator = next_combinator() and not (spec.kind == "storage" or spec.offer)
      clear_signals(place.o, place.pa)
      local front = siding(place.o, place.pa, spec)
      built.stations[#built.stations + 1] = spec
      if front and spec.kind == "depot" and spec.cars then
        local t = Equipment.train({ surface = surface, force = force }, front, spec.cars, spec.name, spec.wagon)
        if t then built.trains[#built.trains + 1] = t end
      end
    end
  end

  if tracks then
    plain_crossings(n, ox, oy, used)
    stats.signals_merged = Blocks.fit(surface, { { ox - 40, oy - 40 }, { ox + size + 40, oy + size + 40 } }, { ox, oy })
  end

  for kx = 0, n - 1 do
    for ky = 0, n - 1 do city_block(BLOCK * kx + ox, BLOCK * ky + oy, true) end
  end

  force = base
  force.bulk_inserter_capacity_bonus = 11
  built.stats = stats
  built.size = size
  built.blocks = n
  built.areas = { { { ox - 40, oy - 40 }, { ox + size + 40, oy + size + 40 } } }
  local first = built.stations[1] and built.stations[1].stop
  built.start = first and { x = first.position.x, y = first.position.y - 6 }
  return built
end

return Builder
