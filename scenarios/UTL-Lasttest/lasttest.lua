--- UTL-Lasttest (Szenario und headless-Lasttest nutzen denselben Code):
--- City-Block-Gitter 12 × 12, 5 Depots × 72 Züge in reinen Depot-Blöcken, ein Depot mit 24
--- Flüssigkeitszügen, 64 Anbieter + 6 für Flüssigkeiten, übrige Plätze Abnehmer, 16 Tankstellen und
--- 6 Cleanup gleichmäßig verteilt, je Ware ein Lager. Be-/Entladen und Tanken mit echten
--- Greifarmen an Unendlich-Kisten (Anbieter: Nachschub, Abnehmer: Kisten vernichten alles); Lager
--- und Item-Cleanups nehmen an und geben ab (Stahlkisten, Greifarme an der Auftrags-Ausgabe).
--- Drei Netze in Spalten (West, Mitte, Ost), Mitte als Zentrum mit West und Ost verbunden;
--- Nachladen an.
---
--- Das Gleisnetz liegt im Szenario schon in der Karte (blueprint.zip, gebaut mit
--- tools/lasttest-map.sh); ohne Karte (headless-Lasttest) baut setup() alles selbst.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")

local Lasttest = {}

Lasttest.CFG = {
  grid = 12, -- 12 × 12 City Blocks
  -- Depots gebündelt in reinen Depot-Blöcken ohne Bahnhöfe (Abstellbahnhof mit 12 Gleisen je Block):
  -- oben links, oben rechts, unten links, unten rechts, Mitte; dazu ein Depot für Flüssigkeitszüge.
  -- Block = { Spalte, Zeile } ab 0.
  depots = {
    { name = "Depot 1", cars = 1, blocks = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 }, { 0, 2 }, { 1, 2 } } },
    { name = "Depot 2", cars = 2, blocks = { { 10, 0 }, { 11, 0 }, { 10, 1 }, { 11, 1 }, { 10, 2 }, { 11, 2 } } },
    { name = "Depot 3", cars = 2, blocks = { { 0, 9 }, { 1, 9 }, { 0, 10 }, { 1, 10 }, { 0, 11 }, { 1, 11 } } },
    { name = "Depot 4", cars = 3, blocks = { { 10, 9 }, { 11, 9 }, { 10, 10 }, { 11, 10 }, { 10, 11 }, { 11, 11 } } },
    { name = "Depot 5", cars = 4, blocks = { { 5, 4 }, { 6, 4 }, { 5, 5 }, { 6, 5 }, { 5, 6 }, { 6, 6 } } },
    { name = "Depot Flüssig", cars = 2, wagon = "fluid-wagon", blocks = { { 5, 0 }, { 6, 0 } } },
  },
  items = { "iron-plate", "copper-plate", "steel-plate", "plastic-bar", "electronic-circuit", "coal", "stone",
    "iron-gear-wheel" },
  -- Flüssigkeiten: Pumpen und Tanks an den Wagen, fahren nur mit den Zügen aus „Depot Flüssig“
  fluids = { "crude-oil", "petroleum-gas" },
  providers_per_fluid = 3,
  requesters_per_fluid = 6,
  fluid_request_amount = 50000,
  providers_per_item = 8,
  requesters_per_item = 8,
  fuel = 16, -- gleichmäßig über die Karte verteilt
  cleanup = 9, -- 3 × 3 verteilt; davon je Flüssigkeit eins mit Pumpen, die übrigen für alle Items
  request_amount = 8000, -- Zielbestand beim Abnehmer (Kiste bleibt leer → ständiger Bedarf)
  vanilla_limits = false, -- kein Zuglimit an den Haltestellen: alles über UTLs „max. Züge“
  storage = 8, -- Lager, 4 × 2 verteilt, reihum je Ware (Mindest/Höchst unten)
  storage_min = 1000,
  storage_max = 4000,
  cleanup_offer = "normal", -- Item-Cleanups bieten ihren Inhalt wieder an
  -- Netze nach Spalte der Haltestelle (Blöcke ab 0); `center` verbindet sich mit allen anderen
  networks = { { name = "West", to = 3 }, { name = "Mitte", to = 7, center = true }, { name = "Ost", to = 11 } },
  -- Abnehmer mit fester Zuglänge (Teile): nur Längen, deren Züge das Netz erreichen. Depot 1 = 2,
  -- Depot 2/3 = 3, Depot 4 = 4, Depot 5 = 5 Teile; West und Ost helfen sich nicht, Mitte beiden.
  lengths = { West = { 2, 3, 5 }, Mitte = { 2, 3, 4, 5 }, Ost = { 3, 4, 5 } },
}

--- Netz einer Haltestelle nach ihrer Spalte.
local function network_of(stop)
  local column = math.floor(stop.position.x / 224)
  for _, net in ipairs(Lasttest.CFG.networks) do
    if column <= net.to then return net.name end
  end
  return Lasttest.CFG.networks[#Lasttest.CFG.networks].name
end

local function L(message) log("[LOAD] " .. message) end

--- UTL-Einstellungen je Station (Haltestellen, Kisten und Greifarme baut builder.lua).
local function configure(spec)
  -- UTL-Station: bei der Combinator-Bauart ist der Combinator die Station, sonst die Haltestelle
  local station_entity = spec.combinator_entity or spec.stop
  local unit = station_entity.unit_number
  remote.call("utl", "configure_station", unit, { network = network_of(spec.stop) })
  if spec.kind == "depot" then
    remote.call("utl", "configure_station", unit, { mode = "depot", max_trains = 1 })
  elseif spec.kind == "fuel" then
    remote.call("utl", "configure_station", unit, { mode = "fuel", max_trains = 3 })
  elseif spec.kind == "cleanup" then
    -- Filter: Flüssigkeits-Cleanups nehmen nur ihre Flüssigkeit, die übrigen alle Items
    local fluid = spec.item and prototypes.fluid[spec.item] and spec.item
    remote.call("utl", "configure_station", unit, { mode = "cleanup", output = spec.offer and true or nil, max_trains = 3,
      cleanup = { all_items = not fluid, all_fluids = false, items = {}, fluids = { fluid or nil }, offer = spec.offer or false } })
  elseif spec.kind == "storage" then
    local CFG = Lasttest.CFG
    remote.call("utl", "configure_station", unit, { mode = "storage", output = true, max_trains = 3,
      storage = { limits = { { signal = { type = "item", name = spec.item }, min = CFG.storage_min, max = CFG.storage_max } },
        accept_leftover = true } })
  elseif spec.kind == "provider" then
    remote.call("utl", "configure_station", unit, { mode = "station", provide = true, request = false, max_trains = 3 })
  elseif spec.kind == "requester" then
    -- mit SR-Latch: erst anfordern, wenn höchstens 1000 da sind (bleibt sonst eine Weile voll)
    local threshold = spec.latch and Lasttest.CFG.request_amount - 1000 or 500
    remote.call("utl", "configure_station", unit, { mode = "station", provide = false, request = true,
      request_threshold = threshold, max_trains = 3,
      min_train_length = spec.min_length or 0, max_train_length = spec.max_length or 0 })
    if prototypes.fluid[spec.item] then
      remote.call("utl", "set_request", unit, 1, { type = "fluid", name = spec.item }, Lasttest.CFG.fluid_request_amount)
    else
      remote.call("utl", "set_request", unit, 1, { type = "item", name = spec.item }, Lasttest.CFG.request_amount)
    end
  end
end

--- Netz-Kombinatoren beim Start: je Netz einer pro Modus (misst ihre Last mit). Reihe je Netz,
--- nahe am Startpunkt; die Werte stehen in ihrem Fenster (und per Kabel für eigene Versuche).
local function place_readouts(built)
  local surface, start = built.surface, built.start
  if not start then return end
  local modes = { "stock", "storage", "shortage", "trains" }
  storage.readouts_placed = {}
  for row, net in ipairs(Lasttest.CFG.networks) do
    for column, mode in ipairs(modes) do
      local wanted = { start.x + 4 + 2 * column, start.y - 4 - 2 * row }
      local pos = surface.find_non_colliding_position("utl-network-combinator", wanted, 10, 1)
      local entity = pos and surface.create_entity({ name = "utl-network-combinator", position = pos, force = "player",
        raise_built = true })
      if entity then
        remote.call("utl", "configure_readout", entity.unit_number, { network = net.name, mode = mode })
        storage.readouts_placed[#storage.readouts_placed + 1] = entity
      end
    end
  end
  L(("%d Netz-Kombinatoren gesetzt"):format(#storage.readouts_placed))
end

--- Karten-Markierung für besondere Bahnhöfe, damit man sie auf der Karte (M) findet.
local function tag_of(spec)
  if spec.min_length then
    return { text = ("nur %d Teile"):format(spec.min_length), icon = { type = "item", name = "locomotive" } }
  elseif spec.latch then
    return { text = "SR-Latch", icon = { type = "virtual", name = "signal-check" } }
  elseif spec.kind == "storage" then
    return { text = "Lager", icon = { type = "item", name = spec.item } }
  elseif spec.kind == "cleanup" then
    return { text = spec.offer and "Cleanup (gibt zurück)" or "Cleanup", icon = { type = "item", name = "infinity-chest" } }
  end
end

--- Markierungen setzen, soweit die Karte dort schon aufgedeckt ist.
local function place_tags()
  local surface = game.surfaces["utl-lasttest"]
  local force = game.forces["player"]
  local pending = {}
  for _, tag in ipairs(storage.tags) do
    if not force.add_chart_tag(surface, tag) then pending[#pending + 1] = tag end
  end
  storage.tags = pending
  if #pending == 0 then L("Karten-Markierungen gesetzt") end
end

--- Netz bauen und in UTL einrichten (on_init). Liefert das Bau-Ergebnis.
function Lasttest.setup()
  local force = game.forces["player"]
  force.research_all_technologies() -- Auftrags-Ausgabe, Lager, drei Netze im Stern
  for name, value in pairs({ ["utl-storage"] = true, ["utl-cleanup-offer"] = true, ["utl-top-up"] = true,
    ["utl-station-output"] = true }) do
    remote.call("utl", "set_map_config", name, value)
  end
  -- Gleisnetz aus der Karte des Szenarios? Dann nur noch Stationen und Züge setzen.
  local cfg = {}
  for k, v in pairs(Lasttest.CFG) do cfg[k] = v end
  local surface = game.surfaces["utl-lasttest"]
  local prebuilt = surface and surface.count_entities_filtered({ name = "straight-rail", limit = 1 }) > 0
  if prebuilt then cfg.mode = "stations" end
  local started = game.tick
  local built = Builder.build(cfg)
  storage.kinds = {} -- [stop unit] = { kind, item }
  storage.count = { provider = 0, requester = 0, fuel = 0, cleanup = 0, fluid = 0, storage = 0, latch = 0, length = 0 }
  storage.areas = built.areas
  storage.start = built.start
  storage.wire = {} -- Bahnhöfe, deren Greifarme noch an die Auftrags-Ausgabe müssen
  storage.tags = {} -- Karten-Markierungen, die noch gesetzt werden müssen (Karte erst aufdecken)
  for _, spec in ipairs(built.stations) do
    configure(spec)
    storage.kinds[spec.stop.unit_number] = { kind = spec.kind, item = spec.item, latch = spec.latch,
      length = (spec.min_length or spec.max_length) and true or nil }
    if spec.bay then storage.wire[#storage.wire + 1] = { stop = spec.stop, pole = spec.bay.poles[1] } end
    local tag = tag_of(spec)
    if tag then
      tag.position = spec.stop.position
      storage.tags[#storage.tags + 1] = tag
    end
  end
  local center
  for _, net in ipairs(Lasttest.CFG.networks) do
    if net.center then center = net.name end
  end
  for _, net in ipairs(Lasttest.CFG.networks) do
    if net.name ~= center then
      L(("Netz %s ↔ %s: %s"):format(center, net.name, tostring(remote.call("utl", "link_networks", built.surface.index, center, net.name))))
    end
  end
  place_readouts(built)
  L(("Gleisnetz %s, Aufbau im Tick %d"):format(prebuilt and "aus der Karte" or "selbst gebaut", started))
  local s = built.stats
  L(("gebaut: %d City Blocks (%d × %d), %d Stationen, %d Züge, Nebengleis-Stücke %d (%d fehlgeschlagen), Signale %d (%d fehlgeschlagen), %d Geräte, %d Drähte fehlgeschlagen, %d Großmasten, %d Radare, %d Combinator-Stationen, %d Abstellbahnhöfe, %d × %d Felder")
    :format(s.blocks, built.blocks, built.blocks, #built.stations, #built.trains, s.rails, s.failed, s.signals,
      s.signals_failed, s.equipment, s.wires_failed, s.poles or 0, s.radars or 0, s.combinators or 0, s.yards or 0, built.size, built.size))
  -- Lage der Tankstellen und Cleanups als Block (Spalte, Zeile) – zeigt die Verteilung
  local where = { fuel = {}, cleanup = {}, storage = {} }
  for _, spec in ipairs(built.stations) do
    local list = where[spec.kind]
    if list then
      local p = spec.stop.position
      list[#list + 1] = ("%d/%d"):format(math.floor(p.x / 224), math.floor(p.y / 224))
    end
  end
  if s.wire_fail_at then L("Kabel fehlgeschlagen an:" .. s.wire_fail_at) end
  L("Tankstellen in Block " .. table.concat(where.fuel, " ") .. " | Cleanup in Block " .. table.concat(where.cleanup, " ")
    .. " | Lager in Block " .. table.concat(where.storage, " "))
  local goals = {}
  for _, spec in ipairs(built.stations) do goals[#goals + 1] = { train_stop = spec.stop } end
  local result = game.train_manager.request_train_path({ type = "all-goals-accessible", train = built.trains[1], goals = goals })
  L(("erreichbar vom ersten Zug: %d von %d Stationen"):format(result.amount_accessible, #goals))
  return built
end

--- Ankunft an einer Station zählen (Be-/Entladen machen die Greifarme).
function Lasttest.on_train_changed_state(event)
  local train = event.train
  if train.state ~= defines.train_state.wait_station or not train.station then return end
  local info = storage.kinds and storage.kinds[train.station.unit_number]
  local count = storage.count
  if not info or not count or info.kind == "depot" then return end
  count[info.kind] = (count[info.kind] or 0) + 1
  if info.latch then count.latch = (count.latch or 0) + 1 end
  if info.length then count.length = (count.length or 0) + 1 end
  if info.kind == "requester" and prototypes.fluid[info.item] then count.fluid = (count.fluid or 0) + 1 end
end

--- Rotes Kabel von der Auftrags-Ausgabe an den ersten Mast (die Ausgabe legt UTL beim Einstellen
--- oder im nächsten Heartbeat an). Liefert true, wenn alles verdrahtet ist.
local function wire_outputs()
  local pending, failed = {}, 0
  for _, entry in ipairs(storage.wire) do
    local stop, pole = entry.stop, entry.pole
    if stop.valid and pole and pole.valid then
      local p = stop.position
      local output = stop.surface.find_entities_filtered({ name = "utl-station-output",
        area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } } })[1]
      if not output then
        pending[#pending + 1] = entry
      elseif not output.get_wire_connector(defines.wire_connector_id.circuit_red, true)
          .connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red, true)) then
        failed = failed + 1
      end
    end
  end
  if failed > 0 then L(("%d Auftrags-Ausgaben nicht verdrahtet (zu weit)"):format(failed)) end
  storage.wire = pending
  if #pending == 0 then L("Auftrags-Ausgaben verdrahtet") end
  return #pending == 0
end

--- Jede Minute Zwischenstand ins Log.
function Lasttest.on_nth_tick_60(event)
  if storage.wire and #storage.wire > 0 then wire_outputs() end
  if storage.tags and #storage.tags > 0 then place_tags() end
  if storage.count and event.tick % 3600 == 0 then
    local states, empty, at_depot = {}, 0, 0
    for _, t in pairs(game.train_manager.get_trains({ surface = "utl-lasttest" })) do
      states[t.state] = (states[t.state] or 0) + 1
      local st = t.station
      if t.state == defines.train_state.wait_station and st and string.find(st.backer_name, "Depot", 1, true) then
        at_depot = at_depot + 1
      end
      local loco = t.front_stock
      if loco then
        local inv = loco.get_fuel_inventory()
        local burner = loco.burner
        if inv and inv.is_empty() and not (burner and burner.currently_burning) then empty = empty + 1 end
      end
    end
    local c = storage.count
    L(("min %d: frei %d, Lieferungen %d, Ankünfte Anbieter %d, Abnehmer %d (davon Flüssigkeit %d), Tankstelle %d, Cleanup %d, Lager %d, mit Latch %d, mit Zuglänge %d, Warnungen %d, ohne Treibstoff %d, an Depots wartend %d, Zustände %s")
      :format(event.tick / 3600, remote.call("utl", "idle_train_count"), remote.call("utl", "delivery_count"),
        c.provider, c.requester, c.fluid or 0, c.fuel, c.cleanup, c.storage or 0, c.latch or 0, c.length or 0, #remote.call("utl", "get_alerts"), empty, at_depot, serpent.line(states)))
    -- Netz-Kombinatoren: wie viele Signale geben sie aus (je Netz: Bestand/Lager/Fehlmenge/Züge)?
    local parts = {}
    for _, entity in ipairs(storage.readouts_placed or {}) do
      local r = entity.valid and remote.call("utl", "get_readout", entity.unit_number) --[[@as table?]]
      if r then
        local n = 0
        for _ in pairs(r.values) do n = n + 1 end
        parts[#parts + 1] = r.config.network:sub(1, 1) .. "/" .. r.config.mode .. "=" .. n
      end
    end
    if #parts > 0 then L("Netz-Kombinatoren (Signale): " .. table.concat(parts, " ")) end
  end
end

return Lasttest
