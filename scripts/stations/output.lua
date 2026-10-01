--- Auftrags-Ausgabe: Neben jeder Station steht ein kleiner Konstant-Kombinator
--- (`utl-station-output`), an dem die laufenden Aufträge anliegen:
---   * beim Anbieter positiv – so viel soll hier geladen werden,
---   * beim Abnehmer negativ – so viel kommt hier an,
---   * „Züge unterwegs hierher“: Lieferzüge auf dem Weg zu dieser Station,
---   * am Depot steht stattdessen die Depot-Ausgabe (`utl-depot-output`, stations/depot-output.lua).
--- Damit lassen sich Filter-Greifarme, Pumpen und Anzeigen schalten. Bei Flüssigkeiten ist das
--- der einzige Weg, die richtige Pumpe zu öffnen (Wagen haben dort keine Filter).
---
--- Geschrieben wird nur, wenn sich für eine Station etwas geändert hat (`output_dirty`), und
--- höchstens ein paar Stationen je Heartbeat – kein Polling.
local C = require("scripts.core.constants")
local Config = require("scripts.core.config")
local Registry = require("scripts.stations.registry")
local Util = require("scripts.lib.util")
local Unlocks = require("scripts.core.unlocks")
local DepotOutput = require("scripts.stations.depot-output")

local Output = {}

-- Stationen je Takt: die Ausgabe ändert sich nur beim Anlegen und Abschließen von Lieferungen.
local PER_TICK = 20

-- Richtung der Haltestelle → Vektor nach rechts (dort steht die Ausgabe, weg vom Gleis).
local RIGHT = {
  [defines.direction.north] = { 1, 0 },
  [defines.direction.east] = { 0, 1 },
  [defines.direction.south] = { -1, 0 },
  [defines.direction.west] = { 0, -1 },
}

--- Platz für die Ausgabe: direkt an der Kante der Haltestelle (die ist 2 × 2 groß), also
--- 1,5 Felder neben ihr. Ist dort etwas im Weg – meist ein Gleis –, rückt sie feldweise weiter
--- nach außen und zur Not auf die andere Seite.
local function place_for(stop)
  local right = RIGHT[stop.direction] or RIGHT[defines.direction.north]
  local p = stop.position
  local spots = {}
  for _, step in ipairs({ 1.5, 2.5, 3.5 }) do
    spots[#spots + 1] = { x = p.x + right[1] * step, y = p.y + right[2] * step }
  end
  spots[#spots + 1] = { x = p.x - right[1] * 1.5, y = p.y - right[2] * 1.5 }
  return spots
end

--- Ausgabe einer Station holen oder anlegen. nil, wenn die Station keine Haltestelle hat oder
--- die Ausgabe abgeschaltet ist. Depots bekommen die Depot-Ausgabe; wechselt die Rolle, wird das
--- Bauteil getauscht (Kabel daran gehen dabei verloren).
function Output.ensure(station)
  local name = station.config.roles.depot and C.depot_output or C.station_output
  local other = name == C.depot_output and C.station_output or C.depot_output
  local existing = station.output
  if existing and existing.valid then
    if existing.name == name then return existing end
    existing.destroy()
  end
  station.output = nil
  local stop = station.stop
  if not (stop and stop.valid and station.config.output) then return nil end

  local surface = stop.surface
  local output
  for _, position in ipairs(place_for(stop)) do
    local area = { { position.x - 0.6, position.y - 0.6 }, { position.x + 0.6, position.y + 0.6 } }
    -- Schon vorhanden (Spielstand, Klon) oder als Geist aus einer Blaupause? Nicht die Ausgabe
    -- einer Nachbarstation übernehmen (dichte Haltestellenreihen) – selten, deshalb ohne Index.
    output = surface.find_entities_filtered({ area = area, name = name })[1]
    if output then
      for _, other in pairs(storage.stations.by_unit) do
        if other ~= station and other.output == output then
          output = nil
          break
        end
      end
    end
    if not output then
      for _, ghost in pairs(surface.find_entities_filtered({ area = area, ghost_name = { name, other } })) do
        if ghost.ghost_name == name then
          local _, revived = ghost.revive({ raise_revive = false })
          output = revived or output
        else
          ghost.destroy() -- Geist der anderen Ausgabe (Rolle seit der Blaupause geändert)
        end
      end
    end
    output = output or surface.create_entity({
      name = name, position = position, force = stop.force, raise_built = false,
    })
    if output then break end
  end
  if not output then return nil end
  output.operable = false   -- die Signale setzt UTL
  output.minable_flag = false
  output.destructible = false
  station.output = output
  return output
end

--- Ausgabe entfernen (Station weg oder abgeschaltet).
function Output.destroy(station)
  local output = station.output
  station.output = nil
  if output and output.valid then output.destroy() end
end

--- Lieferzüge, die gerade zu einer Station fahren: { [Station] = Anzahl } – zum Anbieter während
--- der Anfahrt, zum Abnehmer nach dem Laden. Ein Durchlauf je Heartbeat, nur wenn es etwas zu
--- schreiben gibt.
local function heading_counts()
  local counts = {}
  for _, delivery in pairs(storage.deliveries.active) do
    -- zum zweiten Anbieter: dort zählen (deliveries/reservations.lua, pickup_unit)
    local pickup = delivery.leg == 2 and delivery.second and delivery.second.unit or delivery.provider
    local unit = delivery.state == "to_provider" and pickup
      or delivery.state == "to_requester" and delivery.requester
    if unit then counts[unit] = (counts[unit] or 0) + 1 end
  end
  return counts
end

--- Aufträge einer Station als Signale schreiben. `heading` = heading_counts(), `depots` =
--- DepotOutput.cache() (sonst neu gezählt).
function Output.write(station, heading, depots)
  local output = Output.ensure(station)
  if not output then return end

  -- erst sammeln, dann nur bei Änderung schreiben (Depots werden alle 2 s neu vorgemerkt)
  local slots, parts = {}, {}
  local function put(key, amount)
    if amount == 0 then return end
    local kind, name, quality = Util.split_key(key)
    slots[#slots + 1] = { value = { type = kind, name = name, quality = quality, comparator = "=" }, min = amount }
    parts[#parts + 1] = key .. "=" .. amount
  end
  --- Eigenes Signal (Zug-Nummer, Länge, Wagen) setzen.
  local function put_signal(name, amount)
    if amount == 0 then return end
    slots[#slots + 1] = { value = { type = "virtual", name = name, quality = "normal", comparator = "=" }, min = amount }
    parts[#parts + 1] = name .. "=" .. amount
  end

  local deliveries = storage.deliveries
  for key, amount in pairs(deliveries.outgoing[station.unit] or {}) do put(key, amount) end
  for key, amount in pairs(deliveries.incoming[station.unit] or {}) do put(key, -amount) end
  if station.config.roles.depot then
    DepotOutput.write(station, put_signal, depots)
  else
    put_signal("utl-trains-incoming", (heading or heading_counts())[station.unit] or 0)
    -- Solange ein Lieferzug hier steht: seine Kennzahlen dazu (wie bei LTN).
    local train = deliveries.at_station[station.unit]
    if train then
      put_signal("utl-train-id", train.id)
      put_signal("utl-train-length", train.length)
      put_signal("utl-train-locos", train.locos)
      put_signal("utl-train-wagons", train.wagons)
      -- für eigene Schaltungen (z. B. Lade- und Entlade-Greifarme an einem Lager): wird hier gerade
      -- geladen oder entladen?
      put_signal("utl-loading", train.mode == "load" and 1 or 0)
      put_signal("utl-unloading", train.mode == "unload" and 1 or 0)
    end
  end

  local sig = output.unit_number .. "|" .. table.concat(parts, ";")
  if station.output_sig == sig then return end
  local behavior = output.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then return end
  section.filters = {}
  for i, slot in ipairs(slots) do section.set_slot(i, slot) end
  station.output_sig = sig
end

--- Eine Station zum Neuschreiben vormerken (aus deliveries.lua bei jeder Reservierung).
function Output.mark(unit)
  local dirty = storage.deliveries.output_dirty
  if dirty then dirty[unit] = true end
end

--- Heartbeat: vorgemerkte Stationen abarbeiten, höchstens PER_TICK je Lauf.
function Output.step()
  if not Config.get().station_output then return end
  local dirty = storage.deliveries.output_dirty
  DepotOutput.scan(Output.mark)
  if next(dirty) == nil then return end
  -- beides erst zählen, wenn es gebraucht wird (Depots brauchen kein `heading`, andere kein `depots`;
  -- die Depot-Ausgabe markiert alle 2 s alle Depots)
  local heading, depots = nil, nil
  local done = 0
  for unit in pairs(dirty) do
    dirty[unit] = nil
    local station = Registry.get(unit)
    if station and Unlocks.loading(Unlocks.force_of(station)) then
      if station.config.roles.depot then
        depots = depots or DepotOutput.cache()
      else
        heading = heading or heading_counts()
      end
      Output.write(station, heading, depots)
    end
    done = done + 1
    if done >= PER_TICK then return end
  end
end

--- Einstellung geändert oder Haltestelle neu verbunden: Ausgabe anlegen bzw. entfernen.
function Output.refresh(station)
  if station.config.output and Config.get().station_output and Unlocks.loading(Unlocks.force_of(station)) then
    Output.write(station)
  else
    Output.destroy(station)
  end
end

return Output
