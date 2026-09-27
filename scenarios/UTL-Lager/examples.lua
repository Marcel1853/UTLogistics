--- Szenario „UTL-Lager“: vier kleine Beispiele auf eigenen Strecken unterhalb des Rundkurses, jedes
--- in einem eigenen Netz (stören sich nicht untereinander und nicht mit dem Rundkurs):
---   A „Zwei Lager“      – zu voll gibt einmal an zu leer, dann Ruhe; danach Kisten zurücksetzen
---   B „Restladung“      – kein Cleanup im Netz: der Zug bringt den Rest ins Lager, das ihn als
---                         Reserve wieder anbietet
---   C „Cleanup-Stufen“  – Anbieter (näher) und Cleanup (weiter weg); die Stufe wechselt je Lieferung
---   D „Zwei Waren“      – Lager mit Grenzen für Eisen und Kupfer, auf Wunsch beides in einer Fahrt
--- Gesteuert wird nur, was ein Spieler sonst von Hand täte (Kisten zurücksetzen, Rest in den Zug,
--- Stufe umstellen, Kohle nachfüllen); das Erklärfenster sagt es jeweils.
local Lines = require("__UTLogistics__/scenarios/UTL-Lager/lines")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local Examples = {}

local W = defines.wire_connector_id
local IRON = { type = "item", name = "iron-plate" }
local COPPER = { type = "item", name = "copper-plate" }
local KEY = { iron = "item|iron-plate|normal", copper = "item|copper-plate|normal" }
local LINES = { two = 161, rest = 201, tiers = 241, multi = 281 }
Examples.TIERS = { "reserve", "normal", "first" }

local function configure(stop, cfg) remote.call("utl", "configure_station", stop.unit_number, cfg) end

local function count(bay, item)
  local n = 0
  for _, chest in pairs(bay.chests) do
    if chest.valid then n = n + chest.get_item_count(item) end
  end
  return n
end
Examples.count = count

local function depot(line, network, name)
  local stop = Lines.stop(line, name, -3, true)
  configure(stop, { mode = "depot", network = network })
  return stop
end

--- Lade- und Entlade-Greifarm mit Umlade-Greifarm dazwischen (wie am Lager im Rundkurs), am
--- Wagenplatz einer Haltestelle nach Osten. Geschaltet über utl-loading.
local function two_way(stop, line)
  local x = stop.position.x - Lines.X0
  local y, cy = line + 1.5, line + 2.5
  local function switched(cx, direction, comparator)
    local e = Lines.entity("bulk-inserter", cx, y, { direction = direction })
    local cb = e.get_or_create_control_behavior()
    cb.circuit_enable_disable = true
    cb.circuit_condition = { first_signal = { type = "virtual", name = "utl-loading" }, comparator = comparator, constant = 0 }
    return e
  end
  local unloader = switched(x - 11.5, 0, "=")
  local loader = switched(x - 9.5, 8, ">")
  Lines.entity("bulk-inserter", x - 10.5, cy, { direction = 12 })
  local a = Lines.entity("steel-chest", x - 11.5, cy)
  local b = Lines.entity("steel-chest", x - 9.5, cy)
  b.get_wire_connector(W.circuit_green, true).connect_to(a.get_wire_connector(W.circuit_green, true))
  local pole, relay = Lines.power(stop, a, line, true)
  return { chests = { a, b }, inserters = { unloader, loader }, pole = pole, relay = relay }
end

function Examples.build(surface, force)
  Lines.use(surface, force)
  surface.request_to_generate_chunks({ Lines.X0, 220 }, 5)
  surface.force_generate_chunk_requests()
  for _, line in pairs(LINES) do Lines.rails(line) end
  local ex = {}

  -- A: zwei Lager
  local L = LINES.two
  local a = { name = "two", depot = depot(L, "Zwei Lager", "Depot A") }
  a.full = Lines.stop(L, "Lager voll", 29, true)
  a.empty = Lines.stop(L, "Lager leer", -29, false)
  configure(a.full, { mode = "storage", network = "Zwei Lager",
    storage = { limits = { { signal = IRON, min = 200, max = 800 } }, accept_leftover = false } })
  configure(a.empty, { mode = "storage", network = "Zwei Lager",
    storage = { limits = { { signal = IRON, min = 400, max = 800 } }, accept_leftover = false } })
  a.full_bay = Lines.bay(a.full, L, Lines.columns(29, true), true, "steel-chest", { { ["iron-plate"] = 800 } })
  a.empty_bay = Lines.bay(a.empty, L, Lines.columns(-29, false), false, "steel-chest")
  a.train = Lines.train(L, -8, "Depot A")
  a.round, a.calm = 1, nil
  ex.two = a

  -- B: Restladung ins Lager
  L = LINES.rest
  local b = { name = "rest", depot = depot(L, "Restladung", "Depot B") }
  b.storage = Lines.stop(L, "Lager nimmt Rest", 29, true)
  configure(b.storage, { mode = "storage", network = "Restladung", storage = { limits = {}, accept_leftover = true } })
  b.bay = two_way(b.storage, L)
  b.requester = Lines.stop(L, "Kupfer-Abnehmer", -29, false)
  configure(b.requester, { mode = "station", network = "Restladung", provide = false, request = true, request_threshold = 50 })
  remote.call("utl", "set_request", b.requester.unit_number, 1, COPPER, 200)
  Lines.bay(b.requester, L, Lines.columns(-29, false), false, "infinity-chest", nil, true)
  b.train, b.wagon = Lines.train(L, -8, "Depot B")
  b.wagon.insert({ name = "copper-plate", count = 300 })
  b.given, b.taken = 1, 0
  ex.rest = b

  -- C: Cleanup-Stufen
  L = LINES.tiers
  local c = { name = "tiers", depot = depot(L, "Cleanup-Stufen", "Depot C") }
  c.provider = Lines.stop(L, "Kupfer-Anbieter", 13, true)
  configure(c.provider, { mode = "station", network = "Cleanup-Stufen", provide = true, request = false, provide_threshold = 50 })
  Lines.bay(c.provider, L, Lines.columns(13, true), true, "infinity-chest", { { ["copper-plate"] = 1000 } })
  c.cleanup = Lines.stop(L, "Cleanup (weiter weg)", 29, true)
  c.tier = 1
  configure(c.cleanup, { mode = "cleanup", network = "Cleanup-Stufen", provide_threshold = 50,
    cleanup = { offer = Examples.TIERS[1] } })
  c.cleanup_bay = Lines.bay(c.cleanup, L, Lines.columns(29, true), true, "steel-chest", { { ["copper-plate"] = 400 } })
  c.requester = Lines.stop(L, "Abnehmer C", -29, false)
  configure(c.requester, { mode = "station", network = "Cleanup-Stufen", provide = false, request = true, request_threshold = 50 })
  remote.call("utl", "set_request", c.requester.unit_number, 1, COPPER, 200)
  Lines.bay(c.requester, L, Lines.columns(-29, false), false, "infinity-chest", nil, true)
  c.train = Lines.train(L, -8, "Depot C")
  c.results = {}
  ex.tiers = c

  -- D: Lager mit zwei Waren
  L = LINES.multi
  local d = { name = "multi", depot = depot(L, "Zwei Waren", "Depot D") }
  d.provider = Lines.stop(L, "Anbieter Eisen + Kupfer", 29, true)
  configure(d.provider, { mode = "station", network = "Zwei Waren", provide = true, request = false, provide_threshold = 50 })
  Lines.bay(d.provider, L, Lines.columns(29, true), true, "infinity-chest",
    { { ["iron-plate"] = 1000 }, { ["copper-plate"] = 1000 } })
  d.storage = Lines.stop(L, "Lager zwei Waren", -29, false)
  configure(d.storage, { mode = "storage", network = "Zwei Waren", storage = { accept_leftover = false, limits = {
    { signal = IRON, min = 200, max = 600 }, { signal = COPPER, min = 100, max = 300 } } } })
  d.bay = Lines.bay(d.storage, L, Lines.columns(-29, false), false, "steel-chest",
    { { ["iron-plate"] = 600 }, { ["copper-plate"] = 300 } })
  d.train = Lines.train(L, -8, "Depot D")
  d.trips, d.both, d.seen = 0, 0, {}
  ex.multi = d

  -- Schilder am Anfang jeder Strecke
  for key, line in pairs(LINES) do
    Signs.place(surface, { Lines.X0 - 20, line - 7 }, "lager-ex-" .. key, IRON)
  end
  return ex
end

--- Rote Kabel der Auftrags-Ausgabe an die geschalteten Greifarme (Beispiel B). false, solange die
--- Ausgabe noch fehlt (UTL legt sie einen Moment nach dem Einstellen an).
function Examples.wire(ex)
  local b = ex.rest
  local p = b.storage.position
  local output = b.storage.surface.find_entities_filtered({ name = "utl-station-output", area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } } })[1]
  if not output then return false end
  local R = W.circuit_red
  output.get_wire_connector(R, true).connect_to(b.bay.relay.get_wire_connector(R, true))
  b.bay.relay.get_wire_connector(R, true).connect_to(b.bay.pole.get_wire_connector(R, true))
  for _, inserter in ipairs(b.bay.inserters) do b.bay.pole.get_wire_connector(R, true).connect_to(inserter.get_wire_connector(R, true)) end
  return true
end

local function front(train) return train and train.valid and train.front_stock or nil end

local function refuel(train)
  if not (train and train.valid) then return end
  for _, list in pairs(train.locomotives) do
    for _, loco in pairs(list) do
      local fuel = loco.get_fuel_inventory()
      if fuel and fuel.get_item_count("coal") < 20 then fuel.insert({ name = "coal", count = 50 }) end
    end
  end
end

--- Einmal pro Sekunde: Ablauf steuern und je Beispiel die Anzeige fürs Fenster liefern:
--- { current, follow, big, note }.
function Examples.tick(ex, deliveries)
  local by = {}
  for _, d in pairs(deliveries) do by[d.network or ""] = d end
  local view = {}

  -- A
  local a = ex.two
  refuel(a.train)
  local da, full, empty = by["Zwei Lager"], count(a.full_bay, "iron-plate"), count(a.empty_bay, "iron-plate")
  local step = 2
  if da then
    step = 3
    a.calm = nil
  elseif empty >= 400 then
    step = 4
    a.calm = a.calm or game.tick
    if game.tick - a.calm > 40 * 60 then
      -- neue Runde: „Lager voll“ wieder auf 1600, „Lager leer“ ausräumen
      for _, chest in pairs(a.full_bay.chests) do chest.clear_items_inside(); chest.insert({ name = "iron-plate", count = 800 }) end
      for _, chest in pairs(a.empty_bay.chests) do chest.clear_items_inside() end
      a.round, a.calm, a.reset = a.round + 1, nil, game.tick
    end
  end
  if a.reset and game.tick - a.reset < 5 * 60 then step = 5 end
  view.two = { current = step, follow = front(da and a.train) or a.empty,
    big = { "utl-lager.two-big", full, empty }, note = { "utl-lager.two-note", a.round } }

  -- B
  local b = ex.rest
  refuel(b.train)
  local db = by["Restladung"]
  local stock = count(b.bay, "copper-plate")
  local cargo = b.train.valid and b.train.get_item_count() or 0
  local at = b.train.valid and b.train.station
  step = 4
  if db and db.provider == b.storage.unit_number then
    step = 5
    if not b.counted then b.counted, b.taken = true, b.taken + 1 end
  else
    b.counted = false
    if at == b.storage and not db then
      step = 3
    elseif cargo > 0 and not db then
      step = (at == b.depot) and 1 or 2
    elseif stock < 50 and not db and at == b.depot then
      -- Lager leer, Zug frei: neuer Rest „vom letzten Auftrag“
      b.wait = b.wait or game.tick
      if game.tick - b.wait > 10 * 60 then
        b.wagon.insert({ name = "copper-plate", count = 300 })
        b.given, b.wait = b.given + 1, nil
      end
    end
  end
  view.rest = { current = step, follow = front(b.train), big = { "utl-lager.rest-big", stock },
    note = { "utl-lager.rest-note", b.given, b.taken } }

  -- C
  local c = ex.tiers
  refuel(c.train)
  local dc = by["Cleanup-Stufen"]
  -- Lieferung beendet (aus der Liste verschwunden; das Entladen ist kürzer als eine Sekunde):
  -- Ergebnis merken, nächste Stufe, Cleanup wieder auffüllen
  local before = c.tier
  if c.active and (not dc or dc.id ~= c.active.id) then
    c.results[c.active.tier] = c.active.provider == c.cleanup.unit_number and "cleanup" or "provider"
    c.tier = c.tier % #Examples.TIERS + 1
    configure(c.cleanup, { cleanup = { offer = Examples.TIERS[c.tier] } })
    for _, chest in pairs(c.cleanup_bay.chests) do chest.clear_items_inside(); chest.insert({ name = "copper-plate", count = 400 }) end
  end
  if dc and (not c.active or dc.id ~= c.active.id) then
    -- eine Anschlussfahrt entsteht beim Entladen, also noch unter der vorigen Stufe
    c.active = { id = dc.id, provider = dc.provider, tier = dc.chained and before or c.tier }
  elseif not dc then
    c.active = nil
  end
  local function who(i) return c.results[i] and { "utl-lager.tiers-" .. c.results[i] } or "–" end
  view.tiers = { current = c.tier, follow = front(dc and c.train) or c.cleanup,
    big = { "utl-lager.tiers-big", { "utl-gui.cleanup-offer-" .. Examples.TIERS[c.tier] } },
    note = { "utl-lager.tiers-note", who(1), who(2), who(3) } }

  -- D
  local d = ex.multi
  refuel(d.train)
  -- die „Fabrik“: verbraucht beides gleichmäßig (4 Eisen, 2 Kupfer je Sekunde, passend zu den
  -- Grenzen) – so fallen beide Waren zugleich unter Mindest und kommen in einer Fahrt
  local need = { ["iron-plate"] = 4, ["copper-plate"] = 2 }
  for _, chest in pairs(d.bay.chests) do
    for item, n in pairs(need) do
      if n > 0 and chest.valid then need[item] = n - chest.remove_item({ name = item, count = n }) end
    end
  end
  local dd = by["Zwei Waren"]
  step = 4
  if dd then
    local n = 0
    for _ in pairs(dd.manifest or {}) do n = n + 1 end
    step = n > 1 and 3 or 2
    if not d.seen[dd.id] then
      d.seen[dd.id] = true
      d.trips = d.trips + 1
      if n > 1 then d.both = d.both + 1 end
    end
  end
  view.multi = { current = step, follow = front(dd and d.train) or d.storage,
    big = { "utl-lager.multi-big", count(d.bay, "iron-plate"), count(d.bay, "copper-plate") },
    note = { "utl-lager.multi-note", d.trips, d.both } }
  return view
end

return Examples
