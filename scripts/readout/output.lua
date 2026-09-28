--- Signale der Netz-Kombinatoren berechnen und schreiben. Heartbeat-Aufgabe mit festem Budget
--- (Round-Robin wie Reader.step); geschrieben wird nur, wenn sich die Werte geändert haben.
local Util = require("scripts.lib.util")
local Networks = require("scripts.stations.networks")
local Aggregate = require("scripts.readout.aggregate")
local Census = require("scripts.readout.census")
local Readouts = require("scripts.readout.readouts")

local Output = {}

local PER_HEARTBEAT = 10
local MAX = 2147483647 -- größter Signalwert (int32)

local TRAIN_SIGNALS = {
  { "utl-trains-total", "total" },
  { "utl-trains-free", "free" },
  { "utl-trains-busy", "busy" },
  { "utl-deliveries", "deliveries" },
  { "utl-trains-low-fuel", "low_fuel" },
  { "utl-trains-no-path", "no_path" },
  { "utl-trains-borrowed", "borrowed" },
  { "utl-trains-lent", "lent" },
}

--- Netze, die der Kombinator zusammenzählt: das gewählte, mit „verbundene Netze“ auch den Stern.
local function networks_of(entry, place)
  local cfg = entry.config
  if cfg.star then return Networks.related_list(place, cfg.network) end
  return { cfg.network }
end

local function add(values, key, amount)
  local n = (values[key] or 0) + amount
  values[key] = n ~= 0 and n or nil
end

--- Ware, die gerade in Zügen zu Abnehmern unterwegs ist (Option „unterwegs mitzählen“).
local function add_transit(values, place, names)
  local wanted = {}
  for _, name in ipairs(names) do wanted[name] = true end
  for _, delivery in pairs(storage.deliveries.active) do
    local state = delivery.state
    if (state == "to_requester" or state == "unloading") and wanted[Census.job_network(delivery)] then
      local train = delivery.train
      local front = train and train.valid and train.front_stock
      if front and Networks.place_of(front) == place then
        for key, amount in pairs(delivery.manifest) do add(values, key, amount) end
      end
    end
  end
end

--- Signale eines Kombinators: { [key] = Menge }; Schlüssel wie bei Stationen
--- („item|iron-plate|normal“) bzw. „virtual|<signal>|normal“ für die Zugzahlen.
function Output.compute(entry)
  local entity = entry.entity
  local place = Networks.place_of(entity)
  local names = networks_of(entry, place)
  local mode = entry.config.mode
  local values = {}
  if mode == "trains" then
    for _, name in ipairs(names) do
      local counts = Census.net(place, name)
      for _, def in ipairs(TRAIN_SIGNALS) do add(values, "virtual|" .. def[1] .. "|normal", counts[def[2]] or 0) end
    end
    return values
  end
  local provide, request = {}, {}
  for _, name in ipairs(names) do
    local net = Aggregate.net(place, name)
    if mode == "storage" then
      for key, amount in pairs(net.stock) do add(values, key, amount) end
    else
      for key, amount in pairs(net.provide) do add(provide, key, amount) end
      for key, amount in pairs(net.request) do add(request, key, amount) end
    end
  end
  if mode == "stock" then
    values = provide
    if entry.config.transit then add_transit(values, place, names) end
  elseif mode == "shortage" then
    -- Fehlmenge: was Abnehmer brauchen und im Netz niemand anbietet
    for key, amount in pairs(request) do
      local missing = amount - (provide[key] or 0)
      if missing > 0 then values[key] = missing end
    end
  end
  return values
end

local function same(a, b)
  if not (a and b) then return false end
  for key, value in pairs(a) do
    if b[key] ~= value then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

--- In den Kombinator schreiben (nur bei Änderung).
function Output.write(entry)
  local entity = entry.entity
  if not (entity and entity.valid) then return end
  local values = Output.compute(entry)
  if same(values, entry.last) then return end
  entry.last = values
  local behavior = entity.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then return end
  section.filters = {}
  local slot = 0
  for key, amount in pairs(values) do
    local kind, name, quality = Util.split_key(key)
    if kind and amount ~= 0 then
      slot = slot + 1
      section.set_slot(slot, {
        value = { type = kind, name = name, quality = quality, comparator = "=" },
        min = math.max(-MAX, math.min(MAX, math.floor(amount))),
      })
    end
  end
end

--- Heartbeat: Kombinatoren auffrischen – jeden höchstens einmal je EVERY Ticks, höchstens
--- PER_HEARTBEAT Neuberechnungen und SCAN Einträge je Heartbeat (Regel 5).
local EVERY = 60
local SCAN = 50
function Output.step()
  local readouts = Readouts.data()
  if readouts.count == 0 then return end
  Census.step()
  local by_unit = readouts.by_unit
  local unit = readouts.cursor
  if unit and not by_unit[unit] then unit = nil end
  local now = game.tick
  local entry
  local done = 0
  for _ = 1, SCAN do
    unit, entry = next(by_unit, unit)
    if not unit then break end
    if not entry.entity.valid then
      Readouts.remove(unit)
      unit = nil
      break
    end
    if now >= (entry.due or 0) then
      entry.due = now + EVERY
      Output.write(entry)
      done = done + 1
      if done >= PER_HEARTBEAT then break end
    end
  end
  readouts.cursor = unit
end

return Output
