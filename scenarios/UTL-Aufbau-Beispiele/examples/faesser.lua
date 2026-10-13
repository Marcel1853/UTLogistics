--- Beispiel „Fässer-Recycling“ (Frage von hechang27 im Mod-Portal, 13.10.2026): recycelte Fässer sollen vor
--- neuen genutzt werden, neue nur gebaut werden, wenn zu wenige da sind – ohne eigenes Netz.
---
---   Fabrik (115/19)         Abnehmer Fässer; verbraucht 4 Fässer je Sekunde (Taktgeber → Greifarm → Vernichtung)
---   Fabrik-Leergut (69/19)  aktiver Anbieter, Anbieter-Priorität 1; 3 Fässer je Sekunde kommen als Leergut heraus
---   Fässer neu (115/3)      Anbieter, Priorität 0; Montagemaschine baut Fässer aus Stahl; der Greifarm in die
---                           Kiste läuft nur, solange das SR-Latch „Auffüllen“ am Netz-Kombinator ✓ ausgibt:
---                           an unter 200, aus über 400 Fässern im Netz
---   Depot (11/41, 137/61)   je ein Zug
---
--- Weil nur 3 von 4 Fässern zurückkommen, wird das Leergut knapp; dann – und nur dann – entstehen neue.
--- Die Vernichtungs-Kiste gibt es nur hier im Beispiel (im echten Spiel wäre das die weitere Verarbeitung).
local Build = require("__UTLogistics__/scenarios/UTL-Aufbau-Beispiele/build")

local Example = {}

Example.key = "faesser"
Example.size = { 160, 112 } -- Fläche des Rundkurses

local CONSUME = 4 -- Fässer je Sekunde in der Fabrik
local RETURN = 3  -- davon als Leergut zurück
local NETWORK = "faesser"

local add = Build.add

--- Baut das Beispiel mit Ursprung `origin`; liefert den Punkt, an dem Spieler hingesetzt werden.
function Example.build(origin)
  local stops, station_of = Build.ring(origin)
  local function cfg(st, changes)
    changes.network = NETWORK
    remote.call("utl", "configure_station", st.unit_number, changes)
  end

  for _, key in ipairs({ "11/41", "137/61" }) do
    local stop, st = Build.station(stops, station_of, key, "Depot")
    cfg(st, { mode = "depot" })
    Build.train(stop)
  end

  -- Fabrik: Zug entlädt in die Kiste, ein Greifarm verbraucht im Takt
  do
    local stop, st, input = Build.station(stops, station_of, "115/19", "Fabrik")
    local at, d = Build.wagon_spot(stop)
    local inward = { -d.r[1], -d.r[2] }
    Build.inserter(add(at, d.r, 1.5), inward)
    local chest = Build.entity("steel-chest", add(at, d.r, 2.5))
    local use = Build.inserter(add(at, d.r, 3.5), inward)
    local void = Build.entity("infinity-chest", add(at, d.r, 4.5))
    if void then void.remove_unfiltered_items = true end
    Build.power(at, d)
    Build.wire_to_station(chest, at, d, st, input)
    Build.clock(add(add(at, d.r, 4), d.f, -4), use, CONSUME)
    Build.panel(add(add(at, d.r, 2.5), d.f, 7), st, input)
    cfg(st, { mode = "station", provide = false, request = true, request_threshold = 40 })
    remote.call("utl", "set_request", st.unit_number, 1, { type = "item", name = "barrel" }, 200)
    Build.label({ "utl-aufbau.faesser-fabrik", CONSUME }, add(add(at, d.r, 9), d.f, 0))
  end

  -- Leergut: kommt im Takt in die Kiste, aktiver Anbieter mit Priorität 1
  do
    local stop, st, input = Build.station(stops, station_of, "69/19", "Fabrik-Leergut")
    local at, d = Build.wagon_spot(stop)
    Build.inserter(add(at, d.r, 1.5), d.r)
    local chest = Build.entity("steel-chest", add(at, d.r, 2.5))
    local back = Build.inserter(add(at, d.r, 3.5), d.r)
    local source = Build.entity("infinity-chest", add(at, d.r, 4.5))
    if source then source.infinity_container_filters = { { index = 1, name = "barrel", count = 100, mode = "exactly" } } end
    Build.power(at, d)
    Build.wire_to_station(chest, at, d, st, input)
    Build.clock(add(add(at, d.r, 4), d.f, -4), back, RETURN)
    Build.panel(add(add(at, d.r, 2.5), d.f, 7), st, input)
    -- Mindestmenge 100: Liegt weniger Leergut da, holt der Zug neue Fässer (sonst reichten schon kleine Reste)
    cfg(st, { mode = "station", provide = true, request = false, active_provider = true, provide_threshold = 100,
      provide_priority = 1 })
    Build.label({ "utl-aufbau.faesser-leergut", RETURN }, add(add(at, d.r, 9), d.f, 0))
  end

  -- Neue Fässer: Montagemaschine, Stahl links daneben; Ausgabe-Greifarm nur bei ✓ vom SR-Latch
  do
    local stop, st, input = Build.station(stops, station_of, "115/3", "Fässer neu")
    local at, d = Build.wagon_spot(stop)
    local back = { -d.f[1], -d.f[2] }
    Build.inserter(add(at, d.r, 1.5), d.r)
    local chest = Build.entity("steel-chest", add(at, d.r, 2.5))
    local out = Build.inserter(add(at, d.r, 3.5), d.r)
    Build.entity("assembling-machine-3", add(at, d.r, 5.5), { recipe = "barrel" })
    local machine_row = add(at, d.r, 5.5)
    Build.inserter(add(machine_row, back, 2), back)     -- Stahl → Maschine (links neben der Maschine)
    local steel = Build.entity("infinity-chest", add(machine_row, back, 3))
    if steel then steel.infinity_container_filters = { { index = 1, name = "steel-plate", count = 100, mode = "exactly" } } end
    -- 8 Felder neben diesem Gleis liegt schon das nächste: Strom enger an die Ladestelle
    Build.power(at, d, { eei = { 6, 9 }, ladestelle = { 4, 5 }, schaltungen = { 4, -10 } })
    Build.wire_to_station(chest, at, d, st, input)
    local combi = Build.entity("utl-network-combinator", add(add(at, d.r, 4), d.f, -7), { raise_built = true })
    if combi then remote.call("utl", "configure_readout", combi.unit_number, { network = NETWORK, mode = "stock" }) end
    local latch = Build.topup_latch(add(add(at, d.r, 6), d.f, -7), "barrel", 200, 400, out)
    if combi and latch then
      combi.get_wire_connector(Build.W.circuit_green, true)
        .connect_to(latch.get_wire_connector(Build.W.combinator_input_green, true))
    end
    Build.panel(add(add(at, d.r, 2.5), d.f, 7), st, input)
    cfg(st, { mode = "station", provide = true, request = false, provide_threshold = 40, provide_priority = 0 })
    Build.label({ "utl-aufbau.faesser-neu" }, add(add(at, d.r, 11), d.f, 0))
  end

  Build.label({ "utl-aufbau.faesser-title" }, add(origin, { 74, 30 }, 1))
  return add(origin, { 92, 12 }, 1)
end

return Example
