--- Ladefilter: Solange ein Zug für eine Lieferung unterwegs ist, stehen die Slots seiner
--- Güterwagen auf den Waren des Auftrags, der Rest ist gesperrt. Damit lädt ein gewöhnlicher
--- Greifarm aus einer Kiste mit mehreren Waren nur das, was bestellt ist.
---
--- Grundsätze:
---   * Wagen, an denen der Spieler selbst Filter oder eine Sperre gesetzt hat, bleiben unberührt.
---   * Gemerkt wird nur, was UTL selbst gesetzt hat – aufgeräumt wird genau das.
---   * Flüssigkeiten haben keine Slots; dort hilft erst die Auftrags-Ausgabe.
local Config = require("scripts.core.config")
local Util = require("scripts.lib.util")

local Filters = {}

local CARGO = defines.inventory.cargo_wagon

--- Waren des Auftrags mit ihrem Slotbedarf, nach Menge sortiert (größter Posten zuerst).
local function wanted_slots(manifest)
  local list = {}
  for key, amount in pairs(manifest) do
    local stack = Util.stack_size(key)
    if stack and amount > 0 then
      local kind, name, quality = Util.split_key(key)
      list[#list + 1] = {
        key = key,
        filter = { name = name, quality = quality, comparator = "=" },
        slots = math.ceil(amount / stack),
        amount = amount,
        kind = kind,
      }
    end
  end
  table.sort(list, function(a, b)
    if a.amount ~= b.amount then return a.amount > b.amount end
    return a.key < b.key
  end)
  return list
end

--- Darf UTL diesen Wagen anfassen? Nein, wenn der Spieler dort schon Filter oder eine Sperre hat.
local function usable(inventory, entry)
  if not (inventory and inventory.valid and inventory.supports_filters()) then return false end
  if entry then return true end -- von UTL selbst gesetzt
  if inventory.is_filtered() then return false end
  if inventory.supports_bar() and inventory.get_bar() <= #inventory then return false end
  return true
end

--- Filter und Sperre für einen Zug setzen. `locked` = gesperrte Slots je Wagen (Stationswert),
--- die freibleiben sollen. Liefert die Liste der Wagen mit den gesetzten Slots.
--- Slots, die wegen Restladung nicht gesetzt werden konnten, stehen in `pending`.
--- Jede Ware bekommt **in jedem Wagen** Slots (nicht Wagen für Wagen): Steht an jedem Wagenplatz eine
--- Kiste mit Greifarm, lädt jeder Greifarm mit – sonst bekäme nur der erste Wagen Filter, und die Ware
--- an den hinteren Wagen käme nie in den Zug. Je Wagen bis zum Doppelten seines Anteils: Hat eine
--- Kiste weniger, gleichen die anderen Wagen aus. Die Menge begrenzt die Ladebedingung im Fahrplan.
local function apply_plan(train, manifest, locked)
  local list = wanted_slots(manifest)
  if #list == 0 then return nil end

  local wagons = {}
  for _, wagon in pairs(train.cargo_wagons) do
    local inventory = wagon.get_inventory(CARGO)
    if usable(inventory, nil) then wagons[#wagons + 1] = { wagon = wagon, inventory = inventory } end
  end
  if #wagons == 0 then return nil end
  for _, item in ipairs(list) do
    item.per_wagon = math.min(item.slots, 2 * math.ceil(item.slots / #wagons))
  end

  local result = {}
  for _, w in ipairs(wagons) do
    local inventory = w.inventory
    local entry = { wagon = w.wagon, slots = {}, pending = {} }
    local free = #inventory - (locked or 0)
    inventory.sort_and_merge()
    local used = 0
    for _, item in ipairs(list) do
      for _ = 1, item.per_wagon do
        if used >= free then break end
        used = used + 1
        if inventory.set_filter(used, item.filter) then
          entry.slots[used] = true
        else
          entry.pending[used] = item.filter -- Slot belegt: bei der Ankunft erneut versuchen
        end
      end
    end
    -- Hinter den Filtern ist Schluss: so kommt nichts Fremdes in die übrigen Slots.
    if inventory.supports_bar() then
      entry.bar = used + 1
      inventory.set_bar(entry.bar)
    end
    result[#result + 1] = entry
  end
  return result
end

--- Filter für eine Lieferung setzen (beim Losschicken). `locked` kommt vom Anbieter.
function Filters.apply(delivery, locked)
  local cfg = Config.get()
  if not (cfg and cfg.wagon_filters) then return end
  local train = delivery.train
  if not (train and train.valid) then return end
  local entries = apply_plan(train, delivery.manifest, locked)
  if not entries then return end
  delivery.filters = entries
  storage.trains.filtered[delivery.train_id] = entries
end

--- Nachbessern, was wegen Restladung nicht gesetzt werden konnte (bei der Ankunft am Anbieter).
function Filters.repair(delivery)
  local entries = delivery.filters
  if not entries then return end
  for _, entry in ipairs(entries) do
    local wagon = entry.wagon
    local inventory = wagon.valid and wagon.get_inventory(CARGO)
    if inventory then
      for slot, filter in pairs(entry.pending) do
        if inventory.set_filter(slot, filter) then
          entry.slots[slot] = true
          entry.pending[slot] = nil
        end
      end
    end
  end
end

--- Zug hat neue Wagen bekommen (Weltraumaufzug: die Wagen werden auf der anderen Oberfläche geklont,
--- samt Filtern). Einträge mit ungültigem Wagen auf den Wagen umhängen, der dieselben Filter trägt.
function Filters.rehome(entries, train)
  if not (entries and train and train.valid) then return end
  local taken = {}
  for _, entry in ipairs(entries) do
    if not (entry.wagon and entry.wagon.valid) then
      for _, wagon in pairs(train.cargo_wagons) do
        local match = false
        if not taken[wagon.unit_number] and next(entry.slots) ~= nil then
          local inventory = wagon.get_inventory(CARGO)
          if inventory then
            match = true
            for slot in pairs(entry.slots) do
              if not inventory.get_filter(slot) then match = false break end
            end
          end
        end
        if match then
          entry.wagon = wagon
          taken[wagon.unit_number] = true
          break
        end
      end
    end
  end
end

--- Alles zurücknehmen, was UTL gesetzt hat.
local function clear_entries(entries)
  for _, entry in ipairs(entries or {}) do
    local wagon = entry.wagon
    local inventory = wagon.valid and wagon.get_inventory(CARGO)
    if inventory then
      for slot in pairs(entry.slots) do inventory.set_filter(slot, nil) end
      if entry.bar and inventory.supports_bar() then inventory.set_bar() end
    end
  end
end

--- Ende der Lieferung (fertig oder abgebrochen).
function Filters.clear(delivery)
  clear_entries(delivery.filters)
  delivery.filters = nil
  storage.trains.filtered[delivery.train_id] = nil
end

--- Sicherheitsnetz: Zug umgebaut, im Depot angekommen oder von Hand übernommen.
function Filters.reset(train_id)
  local entries = storage.trains.filtered[train_id]
  if not entries then return end
  clear_entries(entries)
  storage.trains.filtered[train_id] = nil
end

return Filters
