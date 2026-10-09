--- Normale UTL-Lieferung auf Wunsch eines Add-ons anlegen (Schnittstelle create_delivery). Sie läuft
--- danach wie jede andere: Reservierungen, Ladefilter, Statistik, Ereignisse.
local Registry = require("scripts.stations.registry")
local Deliveries = require("scripts.deliveries.deliveries")
local Depot = require("scripts.trains.depot")
local Select = require("scripts.dispatcher.select")
local Reach = require("scripts.dispatcher.reach")
local Util = require("scripts.lib.util")

local CreateDelivery = {}

local function usable_stop(station)
  local stop = station and station.stop
  return stop and stop.valid and stop.connected_rail and stop or nil
end

--- Freier UTL-Zug für die Fahrt: der genannte (`train_id`) oder der nächste zum Anbieter.
local function pick_train(provider, requester, key, train_id)
  local p_cfg, r_cfg = provider.config, requester.config
  local function fits(record)
    return record and Select.length_ok(p_cfg, record.length) and Select.length_ok(r_cfg, record.length)
      and Select.capacity_of(record, key, p_cfg.locked_slots) > 0 and Depot.is_ready(record)
  end
  if train_id then
    local record = Depot.get(train_id)
    return fits(record) and record or nil
  end
  local stop = provider.stop
  local best, best_distance = nil, nil
  for _, pool in ipairs(Select.pools_for(requester)) do
    for id in pairs(pool) do
      local record = Depot.get(id)
      if record and record.surface_index == stop.surface_index and record.force_index == stop.force_index and fits(record) then
        local distance = Util.dist2(record.position, stop.position)
        if not best_distance or distance < best_distance then best, best_distance = record, distance end
      end
    end
  end
  return best
end

--- `spec` = { provider = unit, requester = unit, type = "item" | "fluid", name, quality, amount,
--- train = Zug-ID (optional) }. Liefert die Lieferungs-ID oder nil und einen Grund („bad-spec“,
--- „bad-station“, „not-enough“, „no-train“, „unreachable“, „schedule“).
function CreateDelivery.create(spec)
  if type(spec) ~= "table" or type(spec.name) ~= "string" or type(spec.amount) ~= "number" or spec.amount < 1 then
    return nil, "bad-spec"
  end
  local provider, requester = Registry.get(spec.provider), Registry.get(spec.requester)
  if not (usable_stop(provider) and usable_stop(requester)) or provider == requester then return nil, "bad-station" end
  local key = Util.signal_key({ type = spec.type or "item", name = spec.name, quality = spec.quality })
  if not key then return nil, "bad-spec" end
  local available = ((provider.provide or {})[key] or 0) - Deliveries.outgoing(provider.unit, key)
  local amount = math.floor(spec.amount)
  if available < amount then return nil, "not-enough" end
  local record = pick_train(provider, requester, key, spec.train)
  if not record then return nil, "no-train" end
  local train = record.train
  if not (Reach.check(train, record.stop, provider.stop, true) and Reach.between(train, provider.stop, requester.stop, true)) then
    return nil, "unreachable"
  end
  local capacity = Select.capacity_of(record, key, provider.config.locked_slots)
  local delivery = Deliveries.create(record, provider, requester, { [key] = math.min(amount, capacity) }, nil)
  if not delivery then return nil, "schedule" end
  return delivery.id
end

return CreateDelivery
