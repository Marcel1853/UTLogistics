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
local DepotBlock = require("__UTLogistics__/scenarios/UTL-Lasttest/cityblock-depot")

local Builder = {}

-- Richtungen: f = Fahrtrichtung, r = rechts davon, dir = Richtung (16er), rail = Richtung gerader Gleise
local O = {
  N = { f = { 0, -1 }, r = { 1, 0 }, dir = 0, rail = 0, left = "W", back = "S" },
  E = { f = { 1, 0 }, r = { 0, 1 }, dir = 4, rail = 4, left = "N", back = "W" },
  S = { f = { 0, 1 }, r = { -1, 0 }, dir = 8, rail = 0, left = "E", back = "N" },
  W = { f = { -1, 0 }, r = { 0, -1 }, dir = 12, rail = 4, left = "S", back = "E" },
}

-- { Name, Richtung, dx, dy } – die ersten 4 Stücke; *_END = Lage des folgenden geraden Stücks
local DIVERGE = {
  N = { { "curved-rail-a", 2, 0, -3 }, { "half-diagonal-rail", 2, 2, -8 }, { "half-diagonal-rail", 2, 4, -12 }, { "curved-rail-a", 10, 6, -17 } },
  E = { { "curved-rail-a", 6, 3, 0 }, { "half-diagonal-rail", 6, 8, 2 }, { "half-diagonal-rail", 6, 12, 4 }, { "curved-rail-a", 14, 17, 6 } },
  S = { { "curved-rail-a", 10, 0, 3 }, { "half-diagonal-rail", 2, -2, 8 }, { "half-diagonal-rail", 2, -4, 12 }, { "curved-rail-a", 2, -6, 17 } },
  W = { { "curved-rail-a", 14, -3, 0 }, { "half-diagonal-rail", 6, -8, -2 }, { "half-diagonal-rail", 6, -12, -4 }, { "curved-rail-a", 6, -17, -6 } },
}
local MERGE = {
  N = { { "curved-rail-a", 8, 0, 3 }, { "half-diagonal-rail", 0, 2, 8 }, { "half-diagonal-rail", 0, 4, 12 }, { "curved-rail-a", 0, 6, 17 } },
  E = { { "curved-rail-a", 12, -3, 0 }, { "half-diagonal-rail", 4, -8, 2 }, { "half-diagonal-rail", 4, -12, 4 }, { "curved-rail-a", 4, -17, 6 } },
  S = { { "curved-rail-a", 0, 0, -3 }, { "half-diagonal-rail", 0, -2, -8 }, { "half-diagonal-rail", 0, -4, -12 }, { "curved-rail-a", 8, -6, -17 } },
  W = { { "curved-rail-a", 4, 3, 0 }, { "half-diagonal-rail", 4, 8, -2 }, { "half-diagonal-rail", 4, 12, -4 }, { "curved-rail-a", 12, 17, -6 } },
}

--- Richtung (16er) eines Einheitsvektors. Per Vergleich, nicht per Text: Lua rechnet mit
--- Kommazahlen, -0 würde als „-0“ geschrieben.
local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

local SPAN = 160     -- Abzweig bis Einmündung: Bahnsteig + 2 Warteplätze (Züge bis 5 Teile)
local GAP = 6        -- Platz für das Kettensignal vor dem Abzweig
local BLOCK = 224    -- Rastermaß der City Blocks

local stats = { rails = 0, failed = 0, signals = 0, signals_failed = 0, equipment = 0, wires_failed = 0, blocks = 0 }
local surface, force

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end
local function xy(position) return { position.x, position.y } end
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] end

local function rail(name, dir, pos)
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

local function entity(name, pos, extra)
  local spec = extra or {}
  spec.name, spec.position, spec.force = name, pos, force
  local e = surface.create_entity(spec)
  if e then stats.equipment = stats.equipment + 1 end
  return e
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

--- Greifarme, Unendlich-Kisten und Strom an einer Haltestelle.
--- `kind`: provider (Kiste → Wagen), requester/cleanup (Wagen → Kiste, die alles vernichtet),
--- fuel (Kohle → Lok). Kisten von Anbietern und Abnehmern werden mit der Station verdrahtet.
local function equip(stop, o, kind, item, signal_target)
  local f, r = O[o].f, O[o].r
  local a = { -f[1], -f[2] } -- vom Zugkopf nach hinten
  local base = add(xy(stop.position), r, -2)
  local fluid = item and prototypes.fluid[item] ~= nil
  local slots = kind == "fuel" and { 0 } or fluid and { 1, 2 } or { 1, 2, 3, 4 }
  local positions = kind == "fuel" and { -1.5, 0.5 } or { -2.5, -0.5, 1.5 }
  local chests = {}
  for _, k in ipairs(slots) do
    local center = add(base, a, 3 + 7 * k)
    entity("medium-electric-pole", add(add(center, r, 3.5), a, -3.5))
    if fluid then
      chests[#chests + 1] = fluid_equip(center, a, r, kind == "provider", item)
    end
    for _, t in ipairs(fluid and {} or positions) do
      local at = add(center, a, t)
      -- Richtung eines Greifarms = Seite, von der er greift (Bulk-Greifarme erlauben keine
      -- frei gesetzten Greif-/Ablagepositionen). Laden: von der Kiste (rechts), Entladen: vom Wagen.
      local loads = kind == "provider" or kind == "fuel"
      local grab = loads and r or { -r[1], -r[2] }
      local inserter = entity("bulk-inserter", add(at, r, 1.5), { direction = direction_of(grab) })
      local chest = entity("infinity-chest", add(at, r, 2.5))
      if inserter and chest then
        if loads then
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
  -- Anbieter und Abnehmer: Kisten in einer Kette verdrahten, die erste mit der Haltestelle bzw. dem
  -- Combinator-Eingang (Beispiel für Spieler: so liest die Station ihren Bestand).
  if (kind == "provider" or kind == "requester") and #chests > 0 then
    local G = defines.wire_connector_id.circuit_green
    for i = 2, #chests do
      if not chests[i - 1].get_wire_connector(G, true).connect_to(chests[i].get_wire_connector(G, true)) then
        stats.wires_failed = stats.wires_failed + 1
      end
    end
    -- an die Haltestelle (UTL-Haltestelle) bzw. an den Eingang des Combinators
    local target = signal_target or stop.get_wire_connector(G, true)
    if not chests[1].get_wire_connector(G, true).connect_to(target) then
      stats.wires_failed = stats.wires_failed + 1
      stats.wire_fail_at = (stats.wire_fail_at or "") .. " " .. stop.backer_name .. " (Abstand "
        .. math.floor(((chests[1].position.x - target.owner.position.x) ^ 2 + (chests[1].position.y - target.owner.position.y) ^ 2) ^ 0.5 * 10) / 10 .. ")"
    end
  end
end

--- Nebengleis mit Haltestelle, Abzweig bei `pa` (Hauptgleis) in Fahrtrichtung `o`.
local function siding(o, pa, spec)
  local f, r = O[o].f, O[o].r
  local pb = add(pa, f, SPAN)
  pieces(DIVERGE[o], pa)
  pieces(MERGE[o], pb)
  local from = add(add(pa, f, 20), r, 6)
  straight(o, from, SPAN - 40)
  signal(o, add(add(pa, f, 22.5), r, 7.5))            -- Einfahrt Nebengleis
  signal(o, add(add(pb, f, -21.5), r, 7.5))           -- Ausfahrt vor der Einmündung
  signal(o, add(add(pa, f, -(GAP / 2 + 0.5)), r, 1.5), true, true) -- Kettensignal vor dem Abzweig
  signal(o, add(add(pa, f, SPAN / 2 + 0.5), r, 1.5)) -- Hauptgleis zwischen Abzweig und Einmündung
  -- zwei Warteplätze hinter dem Bahnsteig (je eine Zuglänge), damit bis zu 3 Züge anstehen können
  signal(o, add(add(pb, f, -61.5), r, 7.5))
  signal(o, add(add(pb, f, -99.5), r, 7.5))
  -- Bauart: UTL-Haltestelle oder normale Haltestelle + UTL-Stations-Combinator daneben
  local stop = surface.create_entity({ name = spec.combinator and "train-stop" or "utl-train-stop",
    position = add(add(pb, f, -26), r, 8), direction = O[o].dir, force = force, raise_built = true })
  stop.backer_name = spec.combinator and spec.kind ~= "depot" and ("[item=utl-station-combinator] " .. spec.name)
    or spec.name
  stop.trains_limit = spec.kind == "depot" and 1 or 3 -- Bahnsteig + 2 Warteplätze
  spec.stop = stop
  local signal_target
  if spec.combinator then
    -- Anbieter: hinter der Haltestelle (nah an den Kisten); sonst davor.
    -- (Flüssigkeiten: Tanks liegen weiter außen – hinter der Haltestelle reicht das Kabel)
    local fluid = spec.item and prototypes.fluid[spec.item] ~= nil
    local along = (spec.kind == "provider" or fluid) and -2 or 2
    local combinator = surface.create_entity({ name = "utl-station-combinator",
      position = add(xy(stop.position), f, along), direction = O[o].dir, force = force, raise_built = true })
    spec.combinator_entity = combinator
    if combinator then
      stats.combinators = (stats.combinators or 0) + 1
      -- Ausgang → Haltestelle (so weiß UTL, welche Haltestelle zum Combinator gehört)
      combinator.get_wire_connector(defines.wire_connector_id.combinator_output_green, true)
        .connect_to(stop.get_wire_connector(defines.wire_connector_id.circuit_green, true))
      signal_target = combinator.get_wire_connector(defines.wire_connector_id.combinator_input_green, true)
    end
  end
  if spec.kind ~= "depot" then equip(stop, o, spec.kind, spec.item, signal_target) end
  -- Zugposition: Lok 3 Felder hinter der Haltestelle, Wagen je 7 Felder weiter
  local head = add(add(xy(stop.position), r, -2), f, -3)
  return { head = head, back = { -f[1], -f[2] }, dir = O[o].dir }
end

--- Einen Zug setzen: Lok mit `cars` Wagen dahinter, Fahrplan „zum Depot“. Bleibt ein Teil
--- stecken (unter den Hochgleisen der Depot-Blöcke ist kein Platz), wird alles wieder abgeräumt
--- und nil geliefert – der Aufrufer rückt den Zug dann ein paar Felder nach hinten.
local function train(front, cars, depot_name, wagon)
  local parts = {}
  -- Alle Teile mit auto_connect = false: sonst hängt sich ein Teil an einen fremden Zug daneben
  -- (an den Kreuzungen mit den Hochgleisen passiert das) und reißt ihn beim Abräumen auseinander –
  -- ein so geteilter Zug steht danach im Handbetrieb. Gekuppelt wird gleich von Hand.
  local loco = surface.create_entity({ name = "locomotive", position = front.head, direction = front.dir,
    force = force, auto_connect = false })
  if not loco then return nil end
  parts[1] = loco
  local function give_up()
    for _, part in ipairs(parts) do part.destroy() end
    stats.trains_retried = (stats.trains_retried or 0) + 1
    return nil
  end
  for i = 1, cars do
    local car = surface.create_entity({ name = wagon or "cargo-wagon", position = add(front.head, front.back, 7 * i),
      direction = front.dir, force = force, auto_connect = false })
    if not car then return give_up() end
    parts[#parts + 1] = car
    -- nach vorn an das Teil davor kuppeln
    if not car.connect_rolling_stock(defines.rail_direction.front) then return give_up() end
  end
  -- Sicherheitsnetz: der Zug muss genau aus Lok und seinen Wagen bestehen.
  if #loco.train.carriages ~= cars + 1 then return give_up() end
  loco.insert({ name = "coal", count = 150 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = depot_name, wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  loco.train.manual_mode = false -- sonst bleibt der Zug stehen, bis man ihn von Hand startet
  return loco.train
end

--- Wartestelle für den nächsten Zug: das erste Signal hinter dem Zug am Bahnsteig. Dort hält der
--- zweite Zug, bis der erste das Depotgleis verlässt. Liefert nil, wenn in Reichweite keins liegt
--- (dann bleibt es bei einem Zug im Gleis).
local function wait_spot(front, cars)
  local back = front.back
  local least = 7 * (cars + 1) + 4 -- hinter dem Zug am Bahnsteig
  local from = add(front.head, back, least)
  local to = add(front.head, back, 260)
  local area = { { math.min(from[1], to[1]) - 3, math.min(from[2], to[2]) - 3 },
    { math.max(from[1], to[1]) + 3, math.max(from[2], to[2]) + 3 } }
  local side_of = function(p) return math.abs(dot({ p.x - front.head[1], p.y - front.head[2] }, { -back[2], back[1] })) end
  --- Hängt das Signal an unserem Gleis? Die Hochgleise kreuzen die ebenerdigen Depotgleise, und
  --- ihre Signale stehen genau 1,5 Felder daneben – nach der Lage allein wären sie nicht von den
  --- eigenen zu unterscheiden. Deshalb über die Gleise gehen, an denen das Signal hängt.
  local function on_our_track(sig)
    for _, rail in pairs(sig.get_connected_rails()) do
      if side_of(rail.position) <= 0.6 then return true end
    end
    return false
  end
  local best
  for _, sig in pairs(surface.find_entities_filtered({ area = area, type = "rail-signal" })) do
    local along = dot({ sig.position.x - front.head[1], sig.position.y - front.head[2] }, back)
    if along >= least and (not best or along < best) and side_of(sig.position) <= 2.5 and on_our_track(sig) then
      best = along
    end
  end
  if not best then return nil end
  -- Züge stehen vor dem Signal; Gleise liegen auf ungeraden Feldern, also in Zweierschritten.
  return add(front.head, back, math.ceil((best + 1) / 2) * 2)
end

--- Reihenfolge der Stationen: je Depot 40 Plätze, dazwischen Tankstellen, Anbieter/Abnehmer
--- gemischt und Cleanup (wie in einer echten Fabrik gruppiert).
--- Anbieter und Abnehmer (Tankstellen und Cleanup verteilt assign() eigens über die Karte).
local function layout(cfg)
  local stations = {}
  for _, item in ipairs(cfg.items) do
    for k = 1, cfg.providers_per_item do stations[#stations + 1] = { kind = "provider", item = item, name = "Anbieter " .. item .. " " .. k } end
    for k = 1, cfg.requesters_per_item do stations[#stations + 1] = { kind = "requester", item = item, name = "Abnehmer " .. item .. " " .. k } end
  end
  for _, fluid in ipairs(cfg.fluids or {}) do
    for k = 1, cfg.providers_per_fluid do stations[#stations + 1] = { kind = "provider", item = fluid, name = "Anbieter " .. fluid .. " " .. k } end
    for k = 1, cfg.requesters_per_fluid do stations[#stations + 1] = { kind = "requester", item = fluid, name = "Abnehmer " .. fluid .. " " .. k } end
  end
  return stations
end

--- `count` Plätze gleichmäßig über die Karte: ein Raster aus Zielpunkten, je Punkt der nächste
--- freie Platz (`used` merkt belegte Plätze).
local function spread(places, count, used, span)
  local picked = {}
  if count <= 0 then return picked end
  local k = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / k)
  for i = 0, count - 1 do
    local tx = (i % k + 0.5) / k * span
    local ty = (math.floor(i / k) + 0.5) / rows * span
    local best, best_d
    for j, place in ipairs(places) do
      if not used[j] then
        local dx, dy = place.pa[1] - tx, place.pa[2] - ty
        local d = dx * dx + dy * dy
        if not best_d or d < best_d then best, best_d = j, d end
      end
    end
    if best then
      used[best] = true
      picked[#picked + 1] = best
    end
  end
  return picked
end

--- Jedem Platz eine Station zuordnen: Tankstellen und Cleanup im Raster verteilt, Anbieter und
--- Abnehmer mit festem Sprung über die restlichen Plätze gestreut (nicht zeilenweise, sonst
--- lägen alle Anbieter im Norden); übrige Plätze werden Abnehmer (Wunsch Marcel).
local function assign(cfg, places, span)
  local specs, used = {}, {}
  for _, j in ipairs(spread(places, cfg.fuel, used, span)) do specs[j] = { kind = "fuel", name = "Tankstelle" } end
  -- Cleanup: die ersten je Flüssigkeit eins mit Pumpen (nur diese Flüssigkeit), die übrigen für alle Items
  for n, j in ipairs(spread(places, cfg.cleanup, used, span)) do
    local fluid = (cfg.fluids or {})[n]
    specs[j] = fluid and { kind = "cleanup", item = fluid, name = "Cleanup " .. fluid } or { kind = "cleanup", name = "Cleanup" }
  end
  local free = {}
  for j = 1, #places do if not used[j] then free[#free + 1] = j end end
  local list = layout(cfg)
  local counters = {}
  local extra = 0
  while #list < #free do
    extra = extra + 1
    local item = cfg.items[((extra - 1) % #cfg.items) + 1]
    counters[item] = (counters[item] or cfg.requesters_per_item) + 1
    list[#list + 1] = { kind = "requester", item = item, name = "Abnehmer " .. item .. " " .. counters[item] }
  end
  local total = #free
  local function gcd(x, y) while y ~= 0 do x, y = y, x % y end return x end
  local step = math.max(1, math.floor(total * 0.618))
  while total > 1 and gcd(step, total) ~= 1 do step = step + 1 end
  for i = 0, total - 1 do specs[free[(i * step) % total + 1]] = list[i + 1] end
  return specs
end

local NAMES = { S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal", P = "big-electric-pole", R = "radar" }
local EXTRAS = { P = true, R = true } -- Masten/Radare erst nach den Bahnhöfen (die haben Vorrang)
-- Der Depot-Block bringt zusätzlich Rampen, Stützen und Hochgleise mit, dazu seine Haltestellen.
local DEPOT_NAMES = { U = "rail-support", M = "rail-ramp", E = "elevated-straight-rail",
  EA = "elevated-curved-rail-a", EB = "elevated-curved-rail-b", EH = "elevated-half-diagonal-rail",
  T = "utl-train-stop" }
for code, name in pairs(NAMES) do DEPOT_NAMES[code] = name end

-- Richtung (16er) → Himmelsrichtung, für die Haltestellen aus der Blaupause
local DIR_TO_O = { [0] = "N", [4] = "E", [8] = "S", [12] = "W" }

--- Strom für Radare und Masten eines Blocks: Energiequelle mit Mittelmast neben einem Großmast
--- der Blockmitte.
local function power(x0, y0)
  local eei = surface.create_entity({ name = "electric-energy-interface", position = { x0 + 48, y0 + 90 }, force = force })
  if eei then
    eei.power_production = 2000000
    eei.electric_buffer_size = 20000000
  end
  surface.create_entity({ name = "medium-electric-pole", position = { x0 + 48.5, y0 + 86.5 }, force = force })
end

--- Ein Depot-Block aus Marcels Blaupause „City Block 4 Depo“ (docs/blaupausen/cityblock_depo.txt):
--- ein City Block, dessen Inneres ein Abstellbahnhof mit 27 Haltestellen ist – zwölf ebenerdige
--- Gleise und fünfzehn über Rampen und Hochgleise angebundene. Liefert die Haltestellen mit der
--- Lage des ersten Zuges (`front`); die Züge selbst setzt build().
--- Liegt ein Punkt im Bereich eines Depot-Blocks? Dort baut nur die Depot-Blaupause.
local function in_boxes(x, y, boxes)
  for _, b in ipairs(boxes or {}) do
    if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then return true end
  end
  return false
end

--- Die Depot-Blöcke werden vor den gewöhnlichen City Blocks gebaut: Im Depot-Block gilt das
--- Signalbild der Blaupause (Marcel hat eigens Signale mitten in die Depotgleise gesetzt, damit
--- dahinter noch ein Zug Platz hat). Die gewöhnlichen Blöcke lassen diesen Bereich danach aus.
local function depot_block(X, Y, spec_of)
  local stops = {}
  for _, e in ipairs(DepotBlock) do
    local name = DEPOT_NAMES[e[1]]
    if e[1] == "T" then
      local spec = spec_of()
      local stop = surface.create_entity({ name = name, position = { X + e[2], Y + e[3] },
        direction = e[4], force = force, raise_built = true })
      if stop then
        stop.backer_name = spec.name
        -- Nur ein Zug darf den Bahnsteig anfahren; der zweite wartet dahinter, bis der erste
        -- weg ist. Mit einem höheren Limit würde er auffahren und ankuppeln.
        stop.trains_limit = 1
        spec.stop = stop
        -- Fahrtrichtung der Haltestelle: der Zug steht 2 Felder links und 3 Felder dahinter.
        local o = DIR_TO_O[e[4]]
        local f, r = O[o].f, O[o].r
        stops[#stops + 1] = { spec = spec,
          front = { head = add(add({ X + e[2], Y + e[3] }, r, -2), f, -3), back = { -f[1], -f[2] }, dir = O[o].dir } }
      end
    else
      -- e[5] = 1: das Objekt gehört zum Hochgleis (Signale der Hochbahn müssen an deren Ebene
      -- hängen, sonst sperren sie das Bodengleis und die Hochbahn bleibt ein einziger Block).
      local built = surface.create_entity({ name = name, position = { X + e[2], Y + e[3] },
        direction = e[4], force = force,
        rail_layer = e[5] == 1 and defines.rail_layer.elevated or nil })
      if built then
        if e[1] == "P" then stats.poles = (stats.poles or 0) + 1
        elseif e[1] == "R" then stats.radars = (stats.radars or 0) + 1
        elseif e[1] == "G" or e[1] == "K" then stats.signals = stats.signals + 1
        else stats.rails = stats.rails + 1 end
      else
        -- Der Depot-Block bringt die Korridore des City Blocks mit; an den Rändern stehen sie
        -- schon vom Nachbarblock. Solche Doppelstücke sind kein Fehler.
        stats.depot_dup = (stats.depot_dup or 0) + 1
      end
    end
  end
  power(X, Y)
  stats.blocks = stats.blocks + 1
  stats.yards = (stats.yards or 0) + 1
  return stops
end

--- Einen City Block mit Ecke (x0, y0) setzen. Überlappende Stücke des Nachbarblocks (gemeinsame
--- Korridore) gibt es schon – create_entity schlägt dann einfach fehl.
local function city_block(x0, y0, extras, depot_boxes)
  for _, e in ipairs(CityBlock) do
    if (EXTRAS[e[1]] or false) == extras and not in_boxes(x0 + e[2], y0 + e[3], depot_boxes) then
      local ok = surface.create_entity({ name = NAMES[e[1]], position = { x0 + e[2], y0 + e[3] }, direction = e[4], force = force })
      if extras and ok then stats[e[1] == "R" and "radars" or "poles"] = (stats[e[1] == "R" and "radars" or "poles"] or 0) + 1 end
    end
  end
  if extras then
    power(x0, y0)
  else
    stats.blocks = stats.blocks + 1
  end
end

--- Alle Bahnhofsplätze des Gitters (n × n Blöcke): je Korridorstück zwei (eine je Außenseite).
--- Senkrecht: Gleis x+35 nach Süden (Bahnhof westlich), x+61 nach Norden (östlich).
--- Waagerecht: Gleis y+35 nach Westen (nördlich), y+61 nach Osten (südlich).
local function slots(n, depot_boxes)
  local list = {}
  --- Liegt das Nebengleis (Abzweig bis Einmündung, 8 Felder breit) an einem Depot-Block?
  --- Dort sollen keine Bahnhöfe stehen – weder im Block noch in seinen Korridoren.
  local function at_depot(o, pa)
    local f, r = O[o].f, O[o].r
    local pb = add(add(pa, f, SPAN + 20), r, 10)
    local pc = add(add(pa, f, -10), r, -2)
    local x1, x2 = math.min(pb[1], pc[1]), math.max(pb[1], pc[1])
    local y1, y2 = math.min(pb[2], pc[2]), math.max(pb[2], pc[2])
    for _, b in ipairs(depot_boxes) do
      if x1 <= b[3] and x2 >= b[1] and y1 <= b[4] and y2 >= b[2] then return true end
    end
    return false
  end
  local function add_slot(o, pa)
    if not at_depot(o, pa) then list[#list + 1] = { o = o, pa = pa } end
  end
  for k = 0, n do
    for l = 0, n - 1 do
      local x, y0 = BLOCK * k, BLOCK * l
      add_slot("S", { x + 35, y0 + 81 })
      add_slot("N", { x + 61, y0 + 239 })
      local y, x0 = BLOCK * k, BLOCK * l
      add_slot("W", { x0 + 239, y + 35 })
      add_slot("E", { x0 + 81, y + 61 })
    end
  end
  -- zeilenweise sortieren: aufeinanderfolgende Stationen liegen beieinander
  table.sort(list, function(a, b)
    local ra, rb = math.floor(a.pa[2] / BLOCK), math.floor(b.pa[2] / BLOCK)
    if ra ~= rb then return ra < rb end
    if a.pa[1] ~= b.pa[1] then return a.pa[1] < b.pa[1] end
    return a.pa[2] < b.pa[2]
  end)
  return list
end

--- Signale des City Blocks auf der Bahnhofsseite des Außengleises entfernen (dort liegen jetzt
--- Abzweig und Einmündung; die Bahnhofs-Signale setzt siding()).
local function clear_signals(o, pa)
  local f, r = O[o].f, O[o].r
  local from = add(add(pa, f, -10), r, 1.5)
  local to = add(add(pa, f, SPAN + 6), r, 1.5)
  local area = { { math.min(from[1], to[1]) - 0.6, math.min(from[2], to[2]) - 0.6 },
    { math.max(from[1], to[1]) + 0.6, math.max(from[2], to[2]) + 0.6 } }
  for _, sig in pairs(surface.find_entities_filtered({ area = area, type = { "rail-signal", "rail-chain-signal" } })) do
    sig.destroy()
  end
end

--- Alles bauen. Liefert Oberfläche, Stationen, Züge und Bereich.
function Builder.build(cfg)
  surface = game.surfaces["utl-lasttest"] or game.create_surface("utl-lasttest")
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  force = game.forces["player"]
  local n = cfg.grid
  local size = BLOCK * n + 320
  surface.request_to_generate_chunks({ size / 2, size / 2 }, math.ceil(size / 64) + 1)
  surface.force_generate_chunk_requests()

  -- Depot-Blöcke sind reine Depot-Blöcke (Wunsch Marcel): an keiner ihrer vier Seiten liegen
  -- Bahnhöfe (die Nebengleise lägen im Blockinneren), und statt des gewöhnlichen City Blocks
  -- kommt Marcels Blaupause „City Block 4 Depo“ hinein.
  local depot_boxes, is_depot = {}, {}
  for _, depot in ipairs(cfg.depots) do
    for _, b in ipairs(depot.blocks) do
      local X, Y = BLOCK * b[1], BLOCK * b[2]
      is_depot[X .. ":" .. Y] = true
      depot_boxes[#depot_boxes + 1] = { X, Y, X + 320, Y + 320 }
    end
  end

  local built = { surface = surface, stations = {}, trains = {} }
  local count = 0
  local function next_combinator()
    count = count + 1
    return count % 4 == 0 -- jede vierte Station: normale Haltestelle + UTL-Combinator
  end

  -- Depots in ihren Blöcken: je Haltestelle stehen mehrere Züge hintereinander im Gleis.
  for d, depot in ipairs(cfg.depots) do
    for _, b in ipairs(depot.blocks) do
      local stops = depot_block(BLOCK * b[1], BLOCK * b[2], function()
        return { kind = "depot", depot = d, name = depot.name }
      end)
      for _, entry in ipairs(stops) do
        built.stations[#built.stations + 1] = entry.spec
        local front = entry.front
        for k = 1, depot.trains_per_stop or 2 do
          -- Der erste Zug steht am Bahnsteig, jeder weitere vor dem nächsten Signal dahinter.
          if k > 1 then
            local head = wait_spot(front, depot.cars)
            if not head then break end
            front = { head = head, back = front.back, dir = front.dir }
          end
          -- Passt der Zug nicht (Stütze, Hochgleis oder Zug davor im Weg), ein paar Felder weiter
          -- hinten versuchen. Gleise liegen auf ungeraden Feldern, deshalb in Zweierschritten.
          local placed
          for shift = 0, 12, 2 do
            local head = add(front.head, front.back, shift)
            placed = train({ head = head, back = front.back, dir = front.dir }, depot.cars, depot.name, depot.wagon)
            if placed then
              front = { head = head, back = front.back, dir = front.dir }
              break
            end
          end
          if placed then
            built.trains[#built.trains + 1] = placed
          else
            stats.trains_failed = (stats.trains_failed or 0) + 1
            stats.trains_fail_at = (stats.trains_fail_at or "") .. (" %s %d/%d"):format(depot.name, front.head[1], front.head[2])
          end
        end
      end
    end
  end

  -- Erst jetzt die gewöhnlichen City Blocks: Die Bereiche der Depot-Blöcke bleiben frei, sonst
  -- setzten sie Signale dorthin, wo die Blaupause bewusst keine hat.
  for kx = 0, n - 1 do
    for ky = 0, n - 1 do
      if not is_depot[(BLOCK * kx) .. ":" .. (BLOCK * ky)] then city_block(BLOCK * kx, BLOCK * ky, false, depot_boxes) end
    end
  end

  -- Stationen auf die Bahnhofsplätze (Reihenfolge der Plätze: zeilenweise)
  local places = slots(n, depot_boxes)
  local specs = assign(cfg, places, BLOCK * n)
  for i, place in ipairs(places) do
    local spec = specs[i]
    spec.combinator = next_combinator()
    clear_signals(place.o, place.pa)
    siding(place.o, place.pa, spec)
    built.stations[#built.stations + 1] = spec
  end

  for kx = 0, n - 1 do
    for ky = 0, n - 1 do
      if not is_depot[(BLOCK * kx) .. ":" .. (BLOCK * ky)] then city_block(BLOCK * kx, BLOCK * ky, true, depot_boxes) end
    end
  end

  force.bulk_inserter_capacity_bonus = 11
  built.stats = stats
  built.size = size
  built.blocks = n
  built.areas = { { { -40, -40 }, { size + 40, size + 40 } } }
  local first = built.stations[1].stop.position
  built.start = { x = first.x, y = first.y - 6 }
  return built
end

return Builder
