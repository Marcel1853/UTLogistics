--- Auftrags-Ausgabe: Neben jeder Station steht ein kleiner Konstant-Kombinator
--- (`utl-station-output`), an dem die laufenden Aufträge anliegen:
---   * beim Anbieter positiv – so viel soll hier geladen werden,
---   * beim Abnehmer negativ – so viel kommt hier an.
--- Damit lassen sich Filter-Greifarme, Pumpen und Anzeigen schalten. Bei Flüssigkeiten ist das
--- der einzige Weg, die richtige Pumpe zu öffnen (Wagen haben dort keine Filter).
---
--- Geschrieben wird nur, wenn sich für eine Station etwas geändert hat (`output_dirty`), und
--- höchstens ein paar Stationen je Heartbeat – kein Polling.
local C = require("scripts.core.constants")
local Config = require("scripts.core.config")
local Registry = require("scripts.stations.registry")
local Util = require("scripts.lib.util")

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
--- die Ausgabe abgeschaltet ist.
function Output.ensure(station)
  local existing = station.output
  if existing and existing.valid then return existing end
  local stop = station.stop
  if not (stop and stop.valid and station.config.output) then return nil end

  local surface = stop.surface
  local output
  for _, position in ipairs(place_for(stop)) do
    local area = { { position.x - 0.6, position.y - 0.6 }, { position.x + 0.6, position.y + 0.6 } }
    -- Schon vorhanden (Spielstand, Klon) oder als Geist aus einer Blaupause?
    output = surface.find_entities_filtered({ area = area, name = C.station_output })[1]
    if not output then
      for _, ghost in pairs(surface.find_entities_filtered({ area = area, ghost_name = C.station_output })) do
        local _, revived = ghost.revive({ raise_revive = false })
        output = revived or output
      end
    end
    output = output or surface.create_entity({
      name = C.station_output, position = position, force = stop.force, raise_built = false,
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

--- Aufträge einer Station als Signale schreiben.
function Output.write(station)
  local output = Output.ensure(station)
  if not output then return end
  local behavior = output.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then return end
  section.filters = {}

  local slot = 0
  local function put(key, amount)
    if amount == 0 then return end
    local kind, name, quality = Util.split_key(key)
    slot = slot + 1
    section.set_slot(slot, {
      value = { type = kind, name = name, quality = quality, comparator = "=" },
      min = amount,
    })
  end
  --- Eigenes Signal (Zug-Nummer, Länge, Wagen) setzen.
  local function put_signal(name, amount)
    if amount == 0 then return end
    slot = slot + 1
    section.set_slot(slot, { value = { type = "virtual", name = name, quality = "normal", comparator = "=" }, min = amount })
  end

  local deliveries = storage.deliveries
  for key, amount in pairs(deliveries.outgoing[station.unit] or {}) do put(key, amount) end
  for key, amount in pairs(deliveries.incoming[station.unit] or {}) do put(key, -amount) end

  -- Solange ein Lieferzug hier steht: seine Kennzahlen dazu (wie bei LTN).
  local train = deliveries.at_station[station.unit]
  if train then
    put_signal("utl-train-id", train.id)
    put_signal("utl-train-length", train.length)
    put_signal("utl-train-locos", train.locos)
    put_signal("utl-train-wagons", train.wagons)
  end
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
  local done = 0
  for unit in pairs(dirty) do
    dirty[unit] = nil
    local station = Registry.get(unit)
    if station then Output.write(station) end
    done = done + 1
    if done >= PER_TICK then return end
  end
end

--- Einstellung geändert oder Haltestelle neu verbunden: Ausgabe anlegen bzw. entfernen.
function Output.refresh(station)
  if station.config.output and Config.get().station_output then
    Output.write(station)
  else
    Output.destroy(station)
  end
end

return Output
