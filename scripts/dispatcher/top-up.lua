--- Nachladen (Kartenwert „utl-top-up“, Standard aus): Wächst der Bedarf eines Abnehmers, während
--- ein Zug für ihn noch zum Anbieter fährt oder dort lädt, kommt die Menge auf die **laufende**
--- Ladeliste statt in eine zweite Fahrt. Das spart Züge, verlängert aber den Aufenthalt am
--- Anbieter – deshalb ist es abschaltbar und standardmäßig aus.
---
--- Bedingungen: dieselbe Lieferung (also derselbe Anbieter), der Anbieter hat die Ware noch frei,
--- im Zug ist Platz, und die Menge lohnt sich (Schwelle des Abnehmers). Items dürfen dazukommen,
--- Flüssigkeiten nur dieselbe Sorte – ein Flüssigkeitswagen fasst nur eine.
local Deliveries = require("scripts.deliveries.deliveries")
local Registry = require("scripts.stations.registry")
local Depot = require("scripts.trains.depot")
local Schedule = require("scripts.trains.schedule")
local Filters = require("scripts.trains.wagon-filters")
local TeamConfig = require("scripts.core.team-config")
local Unlocks = require("scripts.core.unlocks")
local Util = require("scripts.lib.util")
local Log = require("scripts.lib.log")

local TopUp = {}

--- Lieferungen, die noch beladen werden können.
local function open_state(delivery)
  return (delivery.state == "to_provider" or delivery.state == "loading") and not delivery.provider_released
end

--- Belegter Platz der bisherigen Ladeliste: Slots für Items, Menge für Flüssigkeiten.
local function used_space(manifest)
  local slots, fluid = 0, 0
  for key, amount in pairs(manifest) do
    local size = Util.stack_size(key)
    if size then slots = slots + math.ceil(amount / size) else fluid = fluid + amount end
  end
  return slots, fluid
end

--- Wie viel von `key` passt noch zusätzlich in den Zug?
local function free_for(train, manifest, key, locked)
  local slots, wagons, fluid = Depot.measure(train)
  local used_slots, used_fluid = used_space(manifest)
  local size = Util.stack_size(key)
  if size then
    local free = (slots - wagons * (locked or 0)) - used_slots
    return free > 0 and free * size or 0
  end
  -- Flüssigkeit: nur dieselbe Sorte, und nur was in die Tanks passt
  for other in pairs(manifest) do
    if other ~= key and not Util.stack_size(other) then return 0 end
  end
  return math.max(0, fluid - used_fluid)
end

--- Passt die laufende Lieferung zu dieser Anfrage?
local function candidate(delivery, request)
  if not open_state(delivery) then return nil end
  local train = delivery.train
  if not (train and train.valid) then return nil end
  local provider = Registry.get(delivery.provider)
  local stop = provider and provider.stop
  if not (provider and stop and stop.valid and provider.config.roles.provider) then return nil end
  local available = (provider.provide[request.key] or 0) - Deliveries.outgoing(delivery.provider, request.key)
  if available <= 0 then return nil end
  return provider, available
end

--- Versuch, den Bedarf einer Anfrage auf eine laufende Lieferung zu legen.
--- Liefert true, wenn nachgeladen wurde (dann braucht die Anfrage keinen neuen Zug).
function TopUp.try(request)
  if not storage.cfg.top_up then return false end
  local ids = Deliveries.to_requester(request.station.unit)
  if not ids then return false end

  for id in pairs(ids) do
    local delivery = storage.deliveries.active[id]
    if delivery then
      local provider, available = candidate(delivery, request)
      if provider then
        local locked = provider.config.locked_slots
        local room = free_for(delivery.train, delivery.manifest, request.key, locked)
        local take = math.min(request.need, available, room)
        -- Keine Kleinstmengen: entweder lohnt es sich oder der Zug wird damit voll.
        if take > 0 and (take >= request.minimum or take == room) then
          Deliveries.book_top_up(delivery, request.key, take)
          local force = delivery.train.front_stock and delivery.train.front_stock.force
          local timeouts = { load = TeamConfig.get(force, "load_timeout"),
            unload = TeamConfig.get(force, "unload_timeout"), mode = TeamConfig.get(force, "timeout_mode") }
          if not Schedule.update_loading(delivery.train, provider.stop, delivery.manifest, timeouts) then
            -- Halt nicht mehr im Fahrplan (Interrupt, von Hand geändert): Buchung zurücknehmen.
            Deliveries.undo_top_up(delivery, request.key, take)
            return false
          end
          -- Ladefilter auf die neue Ladeliste bringen
          if provider.config.filter_load and Unlocks.loading(Unlocks.force_of(provider)) then
            Filters.clear(delivery)
            Filters.apply(delivery, locked)
            if delivery.state == "loading" then Filters.repair(delivery) end
          end
          Log.debug("Nachgeladen: Lieferung " .. delivery.id .. " + " .. take .. " " .. request.key)
          return true
        end
      end
    end
  end
  return false
end

return TopUp
