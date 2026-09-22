--- Szenario „UTL-Netzverbund“: 2 × 2 City Blocks mit vier Netzen – zum Anschauen, wie verbundene
--- Netze sich helfen. Gleise, Nebengleise und Bahnhöfe baut der Baukasten des Lasttests.
---
---   * Stern „Eisen“: Zentrum mit Depot (4 Züge), Tankstelle und Cleanup.
---     Partner „Kupfer“ hat kein eigenes Depot – seine Aufträge fahren die Eisen-Züge.
---     Partner „Kohle“ hat ein eigenes Depot (2 Züge); die helfen Eisen, aber nie Kupfer,
---     denn Partner helfen sich nicht untereinander.
---   * „Stein“ ist mit niemandem verbunden: eigenes Depot (2 Züge), eigene Tankstelle.
--- Je Abnehmer höchstens ein Zug gleichzeitig und mehr Züge als Abnehmer – sonst meldet UTL bei
--- dem Dauerbedarf der Unendlich-Kisten bald „kein freier Zug“.
---
--- Jedes Netz liegt in seinem Teil der Karte (Eisen in der Mitte), damit man die Wege sieht.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local Verbund = {}

Verbund.SURFACE = "utl-netzverbund"

-- Stationen je Netz; `anchor` = Kartenpunkt, um den die Bahnhöfe des Netzes liegen (Karte 448 × 448).
local NETS = {
  { name = "Eisen", item = "iron-plate", anchor = { 224, 224 }, depots = 4, providers = 1, requesters = 2,
    fuel = 1, cleanup = 1 },
  { name = "Kupfer", item = "copper-plate", anchor = { 60, 60 }, depots = 0, providers = 1, requesters = 2 },
  { name = "Kohle", item = "coal", anchor = { 390, 60 }, depots = 2, providers = 1, requesters = 2 },
  { name = "Stein", item = "stone", anchor = { 224, 440 }, depots = 2, providers = 1, requesters = 1, fuel = 1 },
}
Verbund.LINKS = { { "Eisen", "Kupfer" }, { "Eisen", "Kohle" } }

--- Liste der Stationen, jede mit Netz und Wunschort.
local function wanted()
  local list = {}
  for _, net in ipairs(NETS) do
    local function add(kind, label, count, extra)
      for k = 1, count or 0 do
        local spec = { kind = kind, network = net.name, anchor = net.anchor, item = net.item,
          name = net.name .. " · " .. label .. ((count > 1 and kind ~= "depot") and (" " .. k) or "") }
        for key, value in pairs(extra or {}) do spec[key] = value end
        list[#list + 1] = spec
      end
    end
    add("depot", "Depot", net.depots, { cars = 2, item = nil })
    add("provider", "Anbieter", net.providers)
    add("requester", "Abnehmer", net.requesters)
    add("fuel", "Tankstelle", net.fuel, { item = nil })
    add("cleanup", "Cleanup", net.cleanup, { item = nil })
  end
  return list
end

--- Plätze belegen: jede Station auf den freien Platz, der ihrem Netz am nächsten liegt.
local function assign(places)
  local specs = {}
  for _, spec in ipairs(wanted()) do
    local best, best_d
    for j, place in ipairs(places) do
      if not specs[j] then
        local dx, dy = place.pa[1] - spec.anchor[1], place.pa[2] - spec.anchor[2]
        local d = dx * dx + dy * dy
        if not best_d or d < best_d then best, best_d = j, d end
      end
    end
    if best then specs[best] = spec end
  end
  return specs
end

local CFG = { grid = 2, depots = {}, assign = assign }

local function configure(spec)
  local unit = (spec.combinator_entity or spec.stop).unit_number
  local net = { network = spec.network }
  if spec.kind == "depot" then
    remote.call("utl", "configure_station", unit, { mode = "depot" })
  elseif spec.kind == "fuel" then
    remote.call("utl", "configure_station", unit, { mode = "fuel" })
  elseif spec.kind == "cleanup" then
    remote.call("utl", "configure_station", unit, { mode = "cleanup" })
  elseif spec.kind == "provider" then
    remote.call("utl", "configure_station", unit, { mode = "station", provide = true, request = false, max_trains = 2 })
  elseif spec.kind == "requester" then
    remote.call("utl", "configure_station", unit,
      { mode = "station", provide = false, request = true, request_threshold = 500, max_trains = 1 })
    remote.call("utl", "set_request", unit, 1, { type = "item", name = spec.item }, 4000)
  end
  remote.call("utl", "configure_station", unit, net)
end

-- Erklärtexte (utl-sign.verbund-…): je Netz eins, Depots einen eigenen.
-- Rechtsvektor je Fahrtrichtung der Haltestelle (Anzeigefeld zwischen Nebengleis und Hauptgleis)
local RIGHT = { [0] = { 1, 0 }, [4] = { 0, 1 }, [8] = { -1, 0 }, [12] = { 0, -1 } }

local function sign(spec, placed)
  local group = spec.network .. (spec.kind == "depot" and ":depot" or "")
  if placed[group] then return end -- je Netz ein Schild, dazu eins am Depot
  placed[group] = true
  local stop = spec.stop
  local r = RIGHT[stop.direction] or RIGHT[0]
  local key = "verbund-" .. (spec.kind == "depot" and "depot-" or "") .. string.lower(spec.network)
  Signs.place(stop.surface, { stop.position.x - 5 * r[1], stop.position.y - 5 * r[2] }, key,
    { type = "virtual", name = "utl-network" })
end

--- Netz bauen, Stationen einstellen, Sterne verbinden. Liefert das Bau-Ergebnis.
--- `surface_name` (optional): auf einer anderen Oberfläche bauen (Szenario UTL-Planeten-Test).
function Verbund.setup(surface_name)
  CFG.surface = surface_name or Verbund.SURFACE
  local built = Builder.build(CFG)
  local surface_index = built.surface.index
  local placed = {}
  for _, spec in ipairs(built.stations) do
    configure(spec)
    sign(spec, placed)
  end
  -- Verbinden ohne Forschungsgrenze: das Szenario erforscht ohnehin alles, aber die Force kann
  -- beim ersten Tick noch ohne Forschung sein → Grenze über eine erforschte Stufe III
  local force = game.forces["player"]
  force.technologies["utl-networks-3"].researched = true
  for _, link in ipairs(Verbund.LINKS) do
    local ok = remote.call("utl", "link_networks", surface_index, link[1], link[2])
    log(("[VERBUND] %s ↔ %s: %s"):format(link[1], link[2], tostring(ok)))
  end
  log(("[VERBUND] gebaut: %d Stationen, %d Züge, Gleise %d (%d fehlgeschlagen), Signale %d (%d fehlgeschlagen), Kabel fehlgeschlagen %d")
    :format(#built.stations, #built.trains, built.stats.rails, built.stats.failed, built.stats.signals,
      built.stats.signals_failed, built.stats.wires_failed))
  log(("[VERBUND] %d Anzeigefelder"):format(built.surface.count_entities_filtered({ name = "display-panel" })))
  -- Start beim Eisen-Depot
  for _, spec in ipairs(built.stations) do
    if spec.network == "Eisen" and spec.kind == "depot" then
      built.start = { x = spec.stop.position.x, y = spec.stop.position.y - 6 }
      break
    end
  end
  return built
end

return Verbund
