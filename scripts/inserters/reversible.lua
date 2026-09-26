--- Wende-Greifarm: arbeitet so, wie er gebaut wurde; ist seine Schaltbedingung erfüllt, dreht UTL
--- ihn um (Greif- und Ablageseite getauscht). Die Bedingung wählt der Spieler selbst – Signal,
--- Vergleich, Zahl, rotes und/oder grünes Kabel. Standard: „utl-unloading > 0“, das Signal der
--- Auftrags-Ausgabe, solange ein Zug an der Station entlädt.
---
--- Es gibt kein Ereignis „Schaltsignal hat sich geändert“. Zwei Wege:
---   * Schreibt UTL eine Auftrags-Ausgabe neu (Zug kommt oder fährt), weckt es genau die
---     Wende-Greifarme im selben Schaltnetz (`wake_network`) – sie reagieren sofort.
---   * Für eigene Schaltungen ohne UTL-Signal schaut der Heartbeat reihum nach, mit kleinem Budget.
--- Gemessen (500 Stück): jeden Heartbeat 100 prüfen kostete Spitzen von ~0,5 ms – deshalb so.
local Heartbeat = require("scripts.core.heartbeat")

local Reversible = {}

local W = defines.wire_connector_id
local BUDGET = 40         -- Greifarme je Heartbeat reihum (Rückfall für eigene Schaltungen)
local DUE_BUDGET = 200    -- geweckte Greifarme je Heartbeat
local MIN_FLIP_TICKS = 60 -- höchstens eine Drehung je Sekunde (flackerndes Signal)

Reversible.COMPARATORS = { ">", "<", "=", "≥", "≤", "≠" }

local COMPARE = {
  [">"] = function(a, b) return a > b end,
  ["<"] = function(a, b) return a < b end,
  ["="] = function(a, b) return a == b end,
  ["≥"] = function(a, b) return a >= b end,
  ["≤"] = function(a, b) return a <= b end,
  ["≠"] = function(a, b) return a ~= b end,
}

function Reversible.default_cfg()
  return { signal = { type = "virtual", name = "utl-unloading" }, comparator = ">", constant = 0, red = true, green = true }
end

local function data()
  local d = storage.reversible
  if not d then
    d = { by_unit = {}, count = 0 }
    storage.reversible = d
  end
  d.by_net = d.by_net or {} -- [network_id] = { [unit] = true }: wer hängt an welchem Netz
  d.due = d.due or {}       -- [unit] = true: gleich prüfen (Netz hat sich geändert)
  return d
end

--- Gegenrichtung (16 Richtungen in 2.x).
local function opposite(direction)
  return (direction + 8) % 16
end

function Reversible.get(unit)
  return unit and data().by_unit[unit]
end

--- Neu gebauten Wende-Greifarm aufnehmen. `cfg` (optional) aus Blaupause/Kopie; `flipped` = stand
--- er in der Vorlage gerade umgedreht (dann ist seine Grundrichtung die Gegenrichtung).
function Reversible.add(entity, cfg, flipped)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  local d = data()
  local unit = entity.unit_number
  if not d.by_unit[unit] then d.count = d.count + 1 end
  local entry = {
    entity = entity,
    base = flipped and opposite(entity.direction) or entity.direction,
    flipped = false,
    last_flip = -MIN_FLIP_TICKS,
    cfg = cfg and table.deepcopy(cfg) or Reversible.default_cfg(),
  }
  if flipped then entity.direction = entry.base end
  d.by_unit[unit] = entry
  script.register_on_object_destroyed(entity)
  Heartbeat.update_registration()
  Reversible.update(entry, game.tick) -- gleich prüfen: ordnet ihn seinem Schaltnetz zu
  return entry
end

local function unindex(d, unit, entry)
  for _, id in pairs(entry.nets or {}) do
    local set = d.by_net[id]
    if set then
      set[unit] = nil
      if next(set) == nil then d.by_net[id] = nil end
    end
  end
  entry.nets = nil
end

function Reversible.remove(unit)
  local d = data()
  local entry = d.by_unit[unit]
  if not entry then return end
  unindex(d, unit, entry)
  d.due[unit] = nil
  d.by_unit[unit] = nil
  d.count = d.count - 1
  if d.cursor == unit then d.cursor = nil end
  Heartbeat.update_registration()
end

--- Summe des gewählten Signals auf den gewählten Kabeln. Merkt sich dabei, an welchen Netzen der
--- Greifarm hängt (für wake_network) – Kabel lösen kein Ereignis aus, deshalb bei jedem Blick.
function Reversible.value(entry)
  local entity, cfg = entry.entity, entry.cfg
  local red = entity.get_circuit_network(W.circuit_red)
  local green = entity.get_circuit_network(W.circuit_green)
  local red_id, green_id = red and red.network_id, green and green.network_id
  local nets = entry.nets
  if not nets or nets[1] ~= red_id or nets[2] ~= green_id then
    local d = data()
    local unit = entity.unit_number
    unindex(d, unit, entry)
    entry.nets = { red_id, green_id }
    for _, id in pairs(entry.nets) do
      d.by_net[id] = d.by_net[id] or {}
      d.by_net[id][unit] = true
    end
  end
  local signal = cfg.signal
  if not signal then return 0 end
  local sum = 0
  if red and cfg.red ~= false then sum = sum + red.get_signal(signal) end
  if green and cfg.green ~= false then sum = sum + green.get_signal(signal) end
  return sum
end

--- Soll er gerade umgedreht sein?
function Reversible.wanted(entry)
  local compare = COMPARE[entry.cfg.comparator] or COMPARE[">"]
  return compare(Reversible.value(entry), entry.cfg.constant or 0)
end

--- Richtung an den Sollzustand anpassen (mit Mindestabstand). Liefert true bei einer Drehung,
--- "later", wenn er sich drehen müsste, die Mindestzeit aber noch nicht um ist.
function Reversible.update(entry, tick)
  local entity = entry.entity
  if not entity.valid then return false end
  local want = Reversible.wanted(entry)
  if want == entry.flipped then return false end
  if tick - entry.last_flip < MIN_FLIP_TICKS then return "later" end
  entity.direction = want and opposite(entry.base) or entry.base
  entry.flipped = want
  entry.last_flip = tick
  return true
end

--- Spieler hat ihn von Hand gedreht: neue Grundrichtung merken.
function Reversible.rotated(entity)
  local entry = Reversible.get(entity.unit_number)
  if not entry then return end
  entry.base = entry.flipped and opposite(entity.direction) or entity.direction
end

--- Ein Schaltnetz hat sich geändert (z. B. Auftrags-Ausgabe neu geschrieben): alle Wende-Greifarme
--- daran beim nächsten Heartbeat prüfen.
function Reversible.wake_network(network_id)
  local d = storage.reversible
  local set = d and d.by_net and d.by_net[network_id]
  if not set then return end
  for unit in pairs(set) do d.due[unit] = true end
end

--- Heartbeat-Aufgabe: erst die geweckten, dann reihum ein paar weitere.
function Reversible.step()
  local d = data()
  if d.count == 0 then return end
  local by_unit, tick = d.by_unit, game.tick
  local done = 0
  for unit in pairs(d.due) do
    if done >= DUE_BUDGET then break end
    done = done + 1
    local entry = by_unit[unit]
    if entry and entry.entity.valid then
      -- Mindestzeit noch nicht um: geweckt lassen, sonst vergäße er die Drehung bis zum Rundgang
      if Reversible.update(entry, tick) ~= "later" then d.due[unit] = nil end
    else
      d.due[unit] = nil
      if entry then Reversible.remove(unit) end
    end
  end
  local unit = d.cursor
  if unit and not by_unit[unit] then unit = nil end
  for _ = 1, math.min(BUDGET, d.count) do
    unit = next(by_unit, unit)
    if not unit then unit = next(by_unit) end
    if not unit then break end
    local entry = by_unit[unit]
    if entry.entity.valid then
      if Reversible.update(entry, tick) == "later" then d.due[unit] = true end
    else
      Reversible.remove(unit)
    end
  end
  d.cursor = unit
end

--- Für Blaupausen: Tag „utl_rev“ = { cfg, flipped }.
function Reversible.tag(entity)
  local entry = Reversible.get(entity.unit_number)
  if not entry then return nil end
  return "utl_rev", { cfg = entry.cfg, flipped = entry.flipped }
end

--- Nach einem Mod-Update: ungültige Einträge entfernen, Zähler neu bestimmen.
function Reversible.rebuild()
  local d = data()
  local count = 0
  for unit, entry in pairs(d.by_unit) do
    if entry.entity and entry.entity.valid then count = count + 1 else d.by_unit[unit] = nil end
  end
  d.count = count
  d.cursor = nil
  d.by_net, d.due = {}, {} -- baut sich beim nächsten Blick auf jeden Greifarm neu auf
end

return Reversible
