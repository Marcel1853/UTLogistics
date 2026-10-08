--- Neue Zug-ID für denselben Zug (Weltraumaufzug von Space Exploration: auf der anderen Oberfläche
--- entsteht ein neuer Zug; Add-ons, die Wagen an- oder abkuppeln: trains/train-change.lua). Alle
--- UTL-Einträge ziehen auf die neue ID um, statt die Lieferung wie bei einem Umbau abzubrechen.
--- Ohne passende Mod wird das nie aufgerufen.
local Depot = require("scripts.trains.depot")
local Filters = require("scripts.trains.wagon-filters")
local Held = require("scripts.trains.held")

local Rekey = {}

local function move(tbl, old, new)
  local value = tbl and tbl[old]
  if value ~= nil then
    tbl[old] = nil
    tbl[new] = value
  end
  return value
end

--- Fährt dieser Zug (alte ID) gerade durch einen Aufzug? Dann darf on_train_created nichts abbrechen.
function Rekey.in_transfer(train_id)
  local transfer = storage.trains.transfer
  return transfer ~= nil and transfer[train_id] ~= nil
end

--- Darf UTL diesen Zug (alte ID) beim Umbau oder im Handbetrieb nicht anfassen? Ja, wenn er gerade
--- umzieht (Aufzug, Umbau durch ein Add-on) oder ein anderer Mod ihn festhält.
function Rekey.protected(train_id)
  return Rekey.in_transfer(train_id) or Held.is(train_id)
end

function Rekey.start(train_id)
  local trains = storage.trains
  trains.transfer = trains.transfer or {}
  trains.transfer[train_id] = game.tick
end

--- Aufzug-Fahrten vergessen, deren Ende nie gemeldet wurde (Zug im Aufzug zerstört, fremde Mod
--- meldet nur den Beginn) – sonst verhinderte `in_transfer` dauerhaft Abbruch und Aufräumen.
function Rekey.sweep(max_age)
  local transfer = storage.trains.transfer
  if not transfer then return end
  local saved = storage.trains.change_records
  for id, tick in pairs(transfer) do
    if game.tick - tick > max_age then
      transfer[id] = nil
      saved[id] = nil -- gesicherter Fahrplan (train-change.lua)
    end
  end
end

--- Umzug `old_id` → `train` (fertiger neuer Zug).
function Rekey.move(old_id, train)
  local trains, deliveries = storage.trains, storage.deliveries
  if trains.transfer then trains.transfer[old_id] = nil end
  if not (train and train.valid) or train.id == old_id then return end
  local new_id = train.id
  Depot.remove(old_id) -- ein Zug im Depot-Pool fährt nicht durch einen Aufzug; sicherheitshalber
  local home = move(trains.home, old_id, new_id)
  if home then home.train = train end
  move(trains.service, old_id, new_id)
  move(trains.visiting, old_id, new_id)
  local waiting = move(trains.cargo_waiting, old_id, new_id)
  if waiting then waiting.train = train end
  move(trains.pending, old_id, new_id)
  move(trains.waiting_at, old_id, new_id)
  move(trains.held, old_id, new_id)
  local filtered = move(trains.filtered, old_id, new_id)
  Filters.rehome(filtered, train)
  local id = move(deliveries.by_train, old_id, new_id)
  local delivery = id and deliveries.active[id]
  if delivery then
    delivery.train_id = new_id
    delivery.train = train
    if delivery.filters and delivery.filters ~= filtered then Filters.rehome(delivery.filters, train) end
  end
  for _, at in pairs(deliveries.at_station) do
    if at.id == old_id then at.id = new_id end
  end
  local stats = storage.statistics
  move(stats and stats.trains, old_id, new_id)
end

return Rekey
