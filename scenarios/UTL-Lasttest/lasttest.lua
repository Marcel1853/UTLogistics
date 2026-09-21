--- UTL-Lasttest (Szenario und headless-Lasttest nutzen denselben Code):
--- City-Block-Gitter 12 × 12, 5 Depots × 72 Züge in reinen Depot-Blöcken, ein Depot mit 24
--- Flüssigkeitszügen, 64 Anbieter + 6 für Flüssigkeiten, übrige Plätze Abnehmer, 16 Tankstellen und
--- 6 Cleanup gleichmäßig verteilt. Be-/Entladen und Tanken mit echten Greifarmen an
--- Unendlich-Kisten (Anbieter: Nachschub, Abnehmer/Cleanup: Kisten vernichten alles).
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
  cleanup = 6, -- davon je Flüssigkeit eins mit Pumpen, die übrigen für alle Items
  request_amount = 8000, -- Zielbestand beim Abnehmer (Kiste bleibt leer → ständiger Bedarf)
}

local function L(message) log("[LOAD] " .. message) end

--- UTL-Einstellungen je Station (Haltestellen, Kisten und Greifarme baut builder.lua).
local function configure(spec)
  -- UTL-Station: bei der Combinator-Bauart ist der Combinator die Station, sonst die Haltestelle
  local station_entity = spec.combinator_entity or spec.stop
  local unit = station_entity.unit_number
  if spec.kind == "depot" then
    remote.call("utl", "configure_station", unit, { mode = "depot" })
  elseif spec.kind == "fuel" then
    remote.call("utl", "configure_station", unit, { mode = "fuel" })
  elseif spec.kind == "cleanup" then
    -- Filter: Flüssigkeits-Cleanups nehmen nur ihre Flüssigkeit, die übrigen alle Items
    local fluid = spec.item and prototypes.fluid[spec.item] and spec.item
    remote.call("utl", "configure_station", unit, { mode = "cleanup",
      cleanup = { all_items = not fluid, all_fluids = false, items = {}, fluids = { fluid or nil } } })
  elseif spec.kind == "provider" then
    remote.call("utl", "configure_station", unit, { mode = "station", provide = true, request = false, max_trains = 3 })
  elseif spec.kind == "requester" then
    remote.call("utl", "configure_station", unit,
      { mode = "station", provide = false, request = true, request_threshold = 500, max_trains = 3 })
    if prototypes.fluid[spec.item] then
      remote.call("utl", "set_request", unit, 1, { type = "fluid", name = spec.item }, Lasttest.CFG.fluid_request_amount)
    else
      remote.call("utl", "set_request", unit, 1, { type = "item", name = spec.item }, Lasttest.CFG.request_amount)
    end
  end
end

--- Netz bauen und in UTL einrichten (on_init). Liefert das Bau-Ergebnis.
function Lasttest.setup()
  local built = Builder.build(Lasttest.CFG)
  storage.kinds = {} -- [stop unit] = { kind, item }
  storage.count = { provider = 0, requester = 0, fuel = 0, cleanup = 0, fluid = 0 }
  storage.areas = built.areas
  storage.start = built.start
  for _, spec in ipairs(built.stations) do
    configure(spec)
    storage.kinds[spec.stop.unit_number] = { kind = spec.kind, item = spec.item }
  end
  local s = built.stats
  L(("gebaut: %d City Blocks (%d × %d), %d Stationen, %d Züge, Nebengleis-Stücke %d (%d fehlgeschlagen), Signale %d (%d fehlgeschlagen), %d Geräte, %d Drähte fehlgeschlagen, %d Großmasten, %d Radare, %d Combinator-Stationen, %d Abstellbahnhöfe, %d × %d Felder")
    :format(s.blocks, built.blocks, built.blocks, #built.stations, #built.trains, s.rails, s.failed, s.signals,
      s.signals_failed, s.equipment, s.wires_failed, s.poles or 0, s.radars or 0, s.combinators or 0, s.yards or 0, built.size, built.size))
  -- Lage der Tankstellen und Cleanups als Block (Spalte, Zeile) – zeigt die Verteilung
  local where = { fuel = {}, cleanup = {} }
  for _, spec in ipairs(built.stations) do
    local list = where[spec.kind]
    if list then
      local p = spec.stop.position
      list[#list + 1] = ("%d/%d"):format(math.floor(p.x / 224), math.floor(p.y / 224))
    end
  end
  if s.wire_fail_at then L("Kabel fehlgeschlagen an:" .. s.wire_fail_at) end
  L("Tankstellen in Block " .. table.concat(where.fuel, " ") .. " | Cleanup in Block " .. table.concat(where.cleanup, " "))
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
  if info.kind == "requester" and prototypes.fluid[info.item] then count.fluid = (count.fluid or 0) + 1 end
end

--- Jede Minute Zwischenstand ins Log.
function Lasttest.on_nth_tick_60(event)
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
    L(("min %d: frei %d, Lieferungen %d, Ankünfte Anbieter %d, Abnehmer %d (davon Flüssigkeit %d), Tankstelle %d, Cleanup %d, Warnungen %d, ohne Treibstoff %d, an Depots wartend %d, Zustände %s")
      :format(event.tick / 3600, remote.call("utl", "idle_train_count"), remote.call("utl", "delivery_count"),
        c.provider, c.requester, c.fluid or 0, c.fuel, c.cleanup, #remote.call("utl", "get_alerts"), empty, at_depot, serpent.line(states)))
  end
end

return Lasttest
