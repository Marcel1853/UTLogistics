--- Zustandsanzeige an UTL-Haltestellen (Wunsch Marcel, 0.0.19): farbige Lampen (Start-Einstellung
--- „utl-station-lamps“) und Anzeigefelder am Kabel der Station (status-panel.lua, immer aktiv).
---
--- Über die zwei Lampen oben an der Haltestelle zeichnet UTL eingefärbte Lampen (Sprites aus
--- prototypes/sprites/stop-lamps.lua):
---   rot   = Haltestelle per Schaltung ausgeschaltet (alle Farben einstellbar, Karten-Einstellungen),
---   grün  = ein Zug steht da,
---   türkis = ein Zug wartet frei im Depot,
---   blau  = ein Zug ist hierher unterwegs (Fahrziel des Spiels oder UTL-Lieferung),
---   gelb  = nichts los.
---
--- Regel 5: umgefärbt wird bei Ereignissen – Zugzustand (Halt, an dem er steht, und sein Ziel, vorher
--- und nachher) und Lieferung gebucht/fertig (Reservations.count_train). Dazu eine langsame Runde mit
--- festem Budget für das, was kein Ereignis hat (Schaltung an/aus, neue Stationen). Ein Wechsel setzt
--- nur die Farbe der zwei vorhandenen Objekte; neu gezeichnet wird nur bei neuer Haltestelle/Richtung.
local Panel = require("scripts.stations.status-panel")

local Lamps = {}

local ENABLED = settings.startup["utl-station-lamps"].value

-- Farbsignale des Spiels und ihr Farbton für die Lampen; welcher Zustand welche Farbe hat, steht in den
-- Karten-Einstellungen („utl-status-color-…“)
local TINTS = {
  red = { r = 1, g = 0.12, b = 0.08 },
  green = { r = 0.15, g = 1, b = 0.25 },
  blue = { r = 0.2, g = 0.5, b = 1 },
  cyan = { r = 0.1, g = 0.95, b = 0.95 },
  yellow = { r = 1, g = 0.78, b = 0.15 },
  pink = { r = 1, g = 0.4, b = 0.8 },
  white = { r = 1, g = 1, b = 1 },
}

--- Farbname eines Zustands (incoming, stopped, depot, idle, off) laut Karten-Einstellung.
function Lamps.color_name(state)
  return storage.cfg["status_color_" .. state] or "yellow"
end

local function tint(state) return TINTS[Lamps.color_name(state)] or TINTS.yellow end

local D = defines.direction
local DIRECTIONS = { [D.north] = "north", [D.east] = "east", [D.south] = "south", [D.west] = "west" }

-- Haltestellen mit den Lampen der Vanilla-Haltestelle (UTL-Haltestelle ist eine Kopie davon)
local SHAPES = { ["train-stop"] = true, ["utl-train-stop"] = true }

local BUDGET = 20 -- Stationen je Runde

local function state_of(station, stop)
  local behavior = stop.get_control_behavior() --[[@as LuaTrainStopControlBehavior?]]
  if behavior and behavior.disabled then return "off" end
  if stop.get_stopped_train() then return station.config.roles.depot and "depot" or "stopped" end
  -- UTL-Lieferung hierher (zählt auch während der Fahrt zum Schienen-Wegpunkt davor)
  if (storage.deliveries.trains_at[station.unit] or 0) > 0 then return "incoming" end
  -- sonst nur ein Zug, dessen aktuelles Fahrziel diese Haltestelle ist (trains_count zählt jeden Zug,
  -- der sie irgendwo im Fahrplan hat – ein Pendelzug wäre nach der Abfahrt weiter „kommt“)
  for _, train in pairs(stop.get_train_stop_trains()) do
    if train.path_end_stop == stop then return "incoming" end
  end
  return "idle"
end

local function destroy(entry)
  for _, id in pairs(entry.ids) do
    local object = rendering.get_object_by_id(id)
    if object then object.destroy() end
  end
end

local function draw(stop, direction, color)
  local ids = {}
  for n = 1, 2 do
    local object = rendering.draw_sprite({
      sprite = "utl-stop-lamp-" .. direction .. "-" .. n,
      target = stop,
      surface = stop.surface,
      tint = color,
      -- über den Lampen des Spiels: die leuchten gelb, sobald ein Zug kommt oder steht, und lägen in
      -- „higher-object-above“ über unserer Farbe (im grafischen Test gesehen, 11.10.2026)
      render_layer = "wires-above",
    })
    ids[n] = object.id
  end
  return ids
end

--- Lampen einer Station anlegen, umfärben oder entfernen (kein Halt / andere Haltestellen-Art).
local function refresh_lamps(station, state)
  local by_station = storage.lamps.by_station
  local entry = by_station[station.unit]
  local stop = station.stop
  local direction = stop and stop.valid and SHAPES[stop.name] and DIRECTIONS[stop.direction]
  if not direction then
    if entry then
      destroy(entry)
      by_station[station.unit] = nil
    end
    return
  end
  if entry and (entry.stop ~= stop or entry.direction ~= direction or not rendering.get_object_by_id(entry.ids[1])) then
    destroy(entry)
    entry = nil
  end
  if not entry then
    by_station[station.unit] = { stop = stop, direction = direction, state = state, ids = draw(stop, direction, tint(state)) }
  elseif entry.state ~= state then
    entry.state = state
    for _, id in pairs(entry.ids) do
      local object = rendering.get_object_by_id(id)
      if object then object.color = tint(state) end
    end
  end
end

--- Anzeige einer Station auffrischen: Lampen (wenn eingeschaltet) und Anzeigefelder daneben.
function Lamps.refresh(station)
  -- Regel 5: ohne Lampen und ohne Anzeigefeld an dieser Station gibt es nichts zu zeigen
  if not ENABLED and not storage.lamps.panels[station.unit] then return end
  local stop = station.stop
  local state = stop and stop.valid and state_of(station, stop) or nil
  if ENABLED then refresh_lamps(station, state) end
  Panel.refresh(station, stop, state)
end

--- Station per unit_number (z. B. aus den Reservierungen).
function Lamps.refresh_unit(unit)
  local station = storage.stations.by_unit[unit]
  if station then Lamps.refresh(station) end
end

local function refresh_stop(stop)
  if not stop.valid then return end
  local unit = storage.stations.by_stop[stop.unit_number]
  if unit then Lamps.refresh_unit(unit) end
end

--- Zugzustand gewechselt: Halt, an dem er steht, und sein Ziel – vorher und jetzt.
function Lamps.on_train(train)
  if not train.valid then return end
  if not ENABLED and next(storage.lamps.panels) == nil then return end -- nichts anzuzeigen
  local trains = storage.lamps.trains
  local id = train.id
  local before = trains[id]
  local now = {}
  local here, target = train.station, train.path_end_stop
  if here then now[#now + 1] = here end
  if target and target ~= here then now[#now + 1] = target end
  trains[id] = #now > 0 and now or nil
  if before then for _, stop in pairs(before) do refresh_stop(stop) end end
  for _, stop in ipairs(now) do refresh_stop(stop) end
end

--- Station weg: Lampen entfernen (an einer abgerissenen Haltestelle verschwinden sie von selbst).
function Lamps.destroy(station)
  Panel.forget(station)
  local entry = storage.lamps.by_station[station.unit]
  if not entry then return end
  destroy(entry)
  storage.lamps.by_station[station.unit] = nil
end

--- Heartbeat-Aufgabe: einige Stationen reihum prüfen (Schaltung an/aus, neue Stationen) und
--- Einträge abgerissener Züge vergessen.
function Lamps.step()
  local lamps = storage.lamps
  local by_unit = storage.stations.by_unit
  local unit = lamps.cursor
  if unit and not by_unit[unit] then unit = nil end
  for _ = 1, BUDGET do
    local station
    unit, station = next(by_unit, unit)
    if not unit then break end
    Panel.scan(station)
    Lamps.refresh(station)
  end
  lamps.cursor = unit
  local train_id = lamps.train_cursor
  if train_id and not lamps.trains[train_id] then train_id = nil end
  for _ = 1, BUDGET do
    train_id = next(lamps.trains, train_id)
    if not train_id then break end
    if not game.train_manager.get_train_by_id(train_id) then lamps.trains[train_id] = nil end
  end
  lamps.train_cursor = train_id
end

--- Farb-Einstellung geändert: alles beim nächsten Auffrischen neu einfärben (Lampen-Runde).
function Lamps.colors_changed()
  for _, entry in pairs(storage.lamps.by_station) do entry.state = nil end
  for _, entry in pairs(storage.lamps.panels) do entry.state = nil end
end

--- Nach Mod-Updates / geänderter Start-Einstellung: ausgeschaltet → alle Lampen entfernen. Lampen
--- ohne Station (Station in der Zwischenzeit weg) ebenfalls.
function Lamps.on_configuration_changed()
  local lamps = storage.lamps
  for unit, entry in pairs(lamps.by_station) do
    if not ENABLED or not storage.stations.by_unit[unit] then
      destroy(entry)
      lamps.by_station[unit] = nil
    end
  end
end

return Lamps
