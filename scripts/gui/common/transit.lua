--- „Unterwegs“ mit Zug-Nummern (Wunsch Marcel, 0.0.19): Welcher Zug bringt bzw. holt was? Hilft beim
--- Nachsehen, wenn eine Station auf einen Zug wartet, der nicht kommt.
---
--- Nur für die Anzeige: ein Durchlauf über alle laufenden Lieferungen, je Tick einmal gemerkt (das
--- Manager-Fenster fragt für viele Stationen nacheinander). Der Merker liegt bewusst nicht in storage –
--- er ändert nichts am Spiel und wird in jedem Tick neu gebaut.
local Reservations = require("scripts.deliveries.reservations")
local Widgets = require("scripts.gui.common.widgets")
local flib_format = require("__flib__.format")

local Transit = {}

local MAX_LINES = 5 -- so viele Züge je Ware im Tooltip, danach „…“

local cache_tick, cache = nil, nil

local function entry_of(index, unit)
  local entry = index[unit]
  if not entry then
    entry = { incoming = {}, outgoing = {}, ids = {}, seen = {} }
    index[unit] = entry
  end
  return entry
end

local function note(index, unit, side, train_id, wares)
  local entry = entry_of(index, unit)
  for key, amount in pairs(wares) do
    local list = entry[side][key]
    if not list then
      list = {}
      entry[side][key] = list
    end
    list[#list + 1] = { id = train_id, amount = amount }
  end
  if not entry.seen[train_id] then
    entry.seen[train_id] = true
    entry.ids[#entry.ids + 1] = train_id
  end
end

--- [unit] = { incoming = { [key] = { {id, amount}, … } }, outgoing = …, ids = { Zug-IDs sortiert } }.
local function index()
  if cache_tick == game.tick and cache then return cache end
  local result = {}
  for _, delivery in pairs(storage.deliveries.active) do
    local id = delivery.train_id
    note(result, delivery.requester, "incoming", id, delivery.manifest)
    if not delivery.provider_released then
      note(result, delivery.provider, "outgoing", id, Reservations.first_share(delivery))
    end
    local second = delivery.second
    if second and not second.released then note(result, second.unit, "outgoing", id, second.manifest) end
  end
  for _, entry in pairs(result) do table.sort(entry.ids) end
  cache_tick, cache = game.tick, result
  return result
end

--- Zug-Nummern, die gerade zu dieser Station unterwegs sind (bringen oder holen), z. B. „80, 134“.
function Transit.ids_text(unit)
  local entry = index()[unit]
  if not entry or #entry.ids == 0 then return nil end
  local parts = {}
  for i, id in ipairs(entry.ids) do
    if i > 8 then
      parts[#parts + 1] = "…"
      break
    end
    parts[#parts + 1] = tostring(id)
  end
  return table.concat(parts, ", ")
end

--- Tooltip-Zeilen „Zug 134: 16 000“ für eine Ware.
local function train_lines(list)
  local lines = { "" }
  for i, item in ipairs(list or {}) do
    if i > MAX_LINES then
      lines[#lines + 1] = "\n…"
      break
    end
    lines[#lines + 1] = { "", "\n", { "utl-gui.transit-train", item.id, flib_format.number(item.amount) } }
  end
  return lines
end

--- Slots „kommt per Zug“ (blau) und „für Züge reserviert“ (gelb), im Tooltip mit Zug-Nummern.
function Transit.add_slots(grid, unit)
  local deliveries = storage.deliveries
  local entry = index()[unit]
  for _, side in ipairs({ { "incoming", "utl-gui.transit-incoming" }, { "outgoing", "utl-gui.transit-outgoing" } }) do
    local name, key_text = side[1], side[2]
    for key, count in pairs(deliveries[name][unit] or {}) do
      local trains = entry and entry[name][key]
      Widgets.add_slot(grid, key, count, name, { "", { key_text, flib_format.number(count) }, train_lines(trains) })
    end
  end
end

return Transit
