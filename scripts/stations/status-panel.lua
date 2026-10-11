--- Anzeigefeld an der Station (Wunsch Marcel, 0.0.19): Ein Vanilla-Anzeigefeld, das per Kabel (rot oder
--- grün) direkt an der UTL-Station hängt – Haltestelle oder Stations-Kombinator –, übernimmt UTL und
--- zeigt dort den Zustand: Symbol als farbiges Signal (blau = Zug kommt, grün = Zug steht da, türkis =
--- Zug wartet im Depot, gelb = nichts los, rot = ausgeschaltet; einstellbar), Text ohne Wörter: Zug, Nummer und Ware als Rich-Text, z. B.
--- „[train=134] #134 [item=iron-ore]16k“. Wörter gehen nicht: der Text ist ein einfacher String für alle
--- Spieler (keine Übersetzung).
---
--- Am Kabel lassen sich Text und Symbol laut API nicht direkt setzen; UTL schreibt deshalb die eine
--- Nachricht des Feldes, mit einer Bedingung, die immer stimmt („✓ = 0“, das Signal kommt an der
--- Station nicht vor). Übernommen wird nur ein Feld ohne eigene Nachrichten (ein neues Feld hat eine leere) – selbst eingerichtete
--- Felder bleiben unberührt. Kabel ab → UTL leert seine Nachricht wieder.
local Util = require("scripts.lib.util")
local flib_format = require("__flib__.format")

local Panel = {}

-- Bedingung, die immer stimmt: Signal ✓ gleich 0
local ALWAYS = { first_signal = { type = "virtual", name = "signal-check" }, comparator = "=", constant = 0 }

-- Symbol = Farbsignal des Spiels, Farbe je Zustand aus den Karten-Einstellungen
local function icon(state)
  return { type = "virtual", name = "signal-" .. (storage.cfg["status_color_" .. state] or "yellow") }
end

local function wares(manifest)
  local parts = {}
  for key, amount in pairs(manifest or {}) do
    local kind, name, quality = Util.split_key(key)
    local tag = kind == "fluid" and "fluid" or "item"
    local q = (kind ~= "fluid" and quality and quality ~= "normal") and (",quality=" .. quality) or ""
    parts[#parts + 1] = "[" .. tag .. "=" .. name .. q .. "]" .. flib_format.number(amount, true)
    if #parts >= 2 then break end
  end
  return table.concat(parts, " ")
end

local function train_text(train_id)
  return "[train=" .. train_id .. "] #" .. train_id
end

local function delivery_text(delivery, train_id)
  local text = train_text(train_id)
  if delivery then text = text .. " " .. wares(delivery.manifest) end
  return text
end

--- Text zum Zustand: welcher Zug kommt bzw. steht da, mit welcher Ware.
local function text_of(station, stop, state)
  local deliveries = storage.deliveries
  if state == "stopped" or state == "depot" then
    local train = stop.get_stopped_train()
    if not train then return "" end
    local id = deliveries.by_train[train.id]
    return delivery_text(id and deliveries.active[id], train.id)
  elseif state == "incoming" then
    local first, count = nil, 0
    for id in pairs(deliveries.by_requester[station.unit] or {}) do
      local delivery = deliveries.active[id]
      if delivery then
        count = count + 1
        first = first or delivery
      end
    end
    if not first then
      for _, delivery in pairs(deliveries.active) do
        if delivery.provider == station.unit and not delivery.provider_released then
          count = count + 1
          first = first or delivery
        end
      end
    end
    if not first then
      -- kein UTL-Lieferzug: Zug, der die Haltestelle als Ziel hat (eigener Fahrplan)
      for _, train in pairs(stop.get_train_stop_trains()) do
        if train.path_end_stop == stop then return train_text(train.id) end
      end
      return ""
    end
    local text = delivery_text(first, first.train_id)
    if count > 1 then text = text .. " +" .. (count - 1) end
    return text
  end
  return ""
end

--- Anzeigefelder, die per Kabel direkt an `entity` hängen.
local function wired_panels(entity, into)
  if not (entity and entity.valid) then return end
  for _, connector in pairs(entity.get_wire_connectors(false)) do
    for _, connection in pairs(connector.connections) do
      local owner = connection.target.owner
      if owner.type == "display-panel" then into[owner.unit_number] = owner end
    end
  end
end

--- Hat das Feld eigene Nachrichten? Ein neues Feld hat schon eine leere Nachricht ({}) – die zählt nicht.
local function has_own_messages(behavior)
  for _, record in pairs(behavior.records) do
    if (record.text and record.text ~= "") or record.icon or record.condition then return true end
  end
  return false
end

local function release(panel)
  storage.lamps.adopted[panel.unit_number] = nil
  local behavior = panel.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior?]]
  if behavior then behavior.records = {} end
end

--- Anzeigefelder am Kabel der Station suchen (Lampen-Runde). Neu übernommene Felder zeigen ihren Text
--- dauerhaft über dem Feld.
function Panel.scan(station)
  local all = storage.lamps.panels
  local adopted = storage.lamps.adopted
  local found = {}
  wired_panels(station.entity, found)
  if station.stop ~= station.entity then wired_panels(station.stop, found) end
  local known = all[station.unit]
  -- Kabel ab: Nachricht wieder leeren
  for _, old in ipairs(known and known.list or {}) do
    if old.valid and not found[old.unit_number] and adopted[old.unit_number] then release(old) end
  end
  local list = {}
  for number, panel in pairs(found) do
    local behavior = panel.get_or_create_control_behavior() --[[@as LuaDisplayPanelControlBehavior]]
    if adopted[number] or not has_own_messages(behavior) then
      if not adopted[number] then
        adopted[number] = true
        panel.display_panel_always_show = true
      end
      list[#list + 1] = panel
    end
  end
  if #list == 0 then
    all[station.unit] = nil
    return
  end
  -- neue Liste: beim nächsten Auffrischen alle Felder neu beschreiben
  all[station.unit] = { list = list }
end

--- Felder einer Station auf den Zustand setzen (nur wenn sich Text oder Zustand geändert hat).
function Panel.refresh(station, stop, state)
  local entry = storage.lamps.panels[station.unit]
  if not entry then return end
  local text = state and text_of(station, stop, state) or ""
  if entry.text == text and entry.state == state then return end
  entry.text, entry.state = text, state
  local records = state and { { text = text, icon = icon(state), condition = ALWAYS } } or {}
  for _, panel in ipairs(entry.list) do
    if panel.valid then
      local behavior = panel.get_control_behavior() --[[@as LuaDisplayPanelControlBehavior?]]
      if behavior then behavior.records = records end
    end
  end
end

--- Station weg: übernommene Felder leeren.
function Panel.forget(station)
  local entry = storage.lamps.panels[station.unit]
  if not entry then return end
  for _, panel in ipairs(entry.list) do
    if panel.valid then release(panel) end
  end
  storage.lamps.panels[station.unit] = nil
end

return Panel
