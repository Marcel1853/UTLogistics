--- Ereignisse für andere Mods: Zug kommt an einer UTL-Station an bzw. fährt ab. Entsteht nur aus
--- on_train_changed_state (kein Polling); ohne Empfänger kostet raise_event fast nichts.
local Registry = require("scripts.stations.registry")
local Held = require("scripts.trains.held")
local PublicEvents = require("scripts.api.public-events")
local util = require("util")

local TrainEvents = {}

local WAIT = defines.train_state.wait_station

local function data(train, unit, stop, delivery_id)
  local station = Registry.get(unit)
  local cfg = station and station.config
  return {
    train = train,
    train_id = train.id,
    station = unit,
    stop = stop and stop.valid and stop or nil,
    mode = cfg and cfg.mode or nil,
    roles = cfg and util.table.deepcopy(cfg.roles) or nil,
    delivery_id = delivery_id,
    held_by = Held.owner(train.id),
  }
end

--- Nach der Verarbeitung von on_train_changed_state. `delivery_id` = Lieferung vor der
--- Verarbeitung (bei der Abfahrt vom Abnehmer ist sie danach schon fertig).
function TrainEvents.state_changed(event, delivery_id)
  local train = event.train
  if not train.valid then return end
  local id = train.id
  local waiting_at = storage.trains.waiting_at
  if event.old_state == WAIT then
    local unit = waiting_at[id]
    if unit then
      waiting_at[id] = nil
      local station = Registry.get(unit)
      PublicEvents.raise_data("on_train_departed", data(train, unit, station and station.stop, delivery_id))
    end
  end
  if train.state == WAIT then
    local stop = train.station
    local unit = stop and storage.stations.by_stop[stop.unit_number]
    if unit then
      waiting_at[id] = unit
      local delivery = storage.deliveries.by_train[id]
      PublicEvents.raise_data("on_train_arrived", data(train, unit, stop, delivery or delivery_id))
    end
  end
end

return TrainEvents
