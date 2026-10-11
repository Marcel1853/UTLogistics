--- Farbige Haltestellen-Lampen (Wunsch Marcel, 0.0.19; Start-Einstellung „utl-station-lamps“).
---
--- Über die zwei Lampen oben an der Haltestelle zeichnet UTL eingefärbte Lampen (Sprites aus
--- prototypes/sprites/stop-lamps.lua):
---   rot   = Haltestelle per Schaltung ausgeschaltet,
---   grün  = ein Zug steht da (im Depot: Zug wartet frei),
---   blau  = ein Zug ist hierher unterwegs (Fahrziel des Spiels oder UTL-Lieferung),
---   gelb  = nichts los.
---
--- Regel 5: umgefärbt wird bei Ereignissen – Zugzustand (Halt, an dem er steht, und sein Ziel, vorher
--- und nachher) und Lieferung gebucht/fertig (Reservations.count_train). Dazu eine langsame Runde mit
--- festem Budget für das, was kein Ereignis hat (Schaltung an/aus, neue Stationen). Ein Wechsel setzt
--- nur die Farbe der zwei vorhandenen Objekte; neu gezeichnet wird nur bei neuer Haltestelle/Richtung.
local Lamps = {}

local ENABLED = settings.startup["utl-station-lamps"].value

local COLORS = {
  off = { r = 1, g = 0.12, b = 0.08 },
  stopped = { r = 0.15, g = 1, b = 0.25 },
  incoming = { r = 0.2, g = 0.5, b = 1 },
  idle = { r = 1, g = 0.78, b = 0.15 },
}

local D = defines.direction
local DIRECTIONS = { [D.north] = "north", [D.east] = "east", [D.south] = "south", [D.west] = "west" }

-- Haltestellen mit den Lampen der Vanilla-Haltestelle (UTL-Haltestelle ist eine Kopie davon)
local SHAPES = { ["train-stop"] = true, ["utl-train-stop"] = true }

local BUDGET = 20 -- Stationen je Runde

local function state_of(station, stop)
  local behavior = stop.get_control_behavior() --[[@as LuaTrainStopControlBehavior?]]
  if behavior and behavior.disabled then return "off" end
  if stop.get_stopped_train() then return "stopped" end
  if stop.trains_count > 0 or (storage.deliveries.trains_at[station.unit] or 0) > 0 then return "incoming" end
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
      render_layer = "higher-object-above",
    })
    ids[n] = object.id
  end
  return ids
end

--- Lampen einer Station anlegen, umfärben oder entfernen (kein Halt / andere Haltestellen-Art).
function Lamps.refresh(station)
  if not ENABLED then return end
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
  local state = state_of(station, stop)
  if not entry then
    by_station[station.unit] = { stop = stop, direction = direction, state = state, ids = draw(stop, direction, COLORS[state]) }
  elseif entry.state ~= state then
    entry.state = state
    for _, id in pairs(entry.ids) do
      local object = rendering.get_object_by_id(id)
      if object then object.color = COLORS[state] end
    end
  end
end

--- Station per unit_number (z. B. aus den Reservierungen).
function Lamps.refresh_unit(unit)
  if not ENABLED then return end
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
  if not (ENABLED and train.valid) then return end
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
  local entry = storage.lamps.by_station[station.unit]
  if not entry then return end
  destroy(entry)
  storage.lamps.by_station[station.unit] = nil
end

--- Heartbeat-Aufgabe: einige Stationen reihum prüfen (Schaltung an/aus, neue Stationen) und
--- Einträge abgerissener Züge vergessen.
function Lamps.step()
  if not ENABLED then return end
  local lamps = storage.lamps
  local by_unit = storage.stations.by_unit
  local unit = lamps.cursor
  if unit and not by_unit[unit] then unit = nil end
  for _ = 1, BUDGET do
    local station
    unit, station = next(by_unit, unit)
    if not unit then break end
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
  if not ENABLED then
    lamps.trains = {}
    lamps.cursor, lamps.train_cursor = nil, nil
  end
end

return Lamps
