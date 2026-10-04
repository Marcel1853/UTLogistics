--- Aktiver Anbieter (wie die aktive Anbieterkiste): Der Bahnhof soll leer werden, auch ohne
--- Anforderung. Reihenfolge der Ziele:
---   1. echte Abnehmer (normale Anfragen, Rang „zuerst leeren“ – fields.lua)
---   2. Lager bis zum Höchstbestand („Auffüllen“, storage-reader.lua)
---   3. Cleanup-Stationen, die die Ware annehmen (diese Datei)
--- Die Anfragen tragen `only_active` – dann kommen nur aktive Anbieter in Frage (select.lua).
--- Gedeckelt (UPS): je Lauf höchstens ACTIVE_SCAN aktive Anbieter, reihum.
local Registry = require("scripts.stations.registry")
local Networks = require("scripts.stations.networks")
local Deliveries = require("scripts.deliveries.deliveries")
local Fields = require("scripts.stations.fields")
local Util = require("scripts.lib.util")

local ActivePush = {}

local ACTIVE_SCAN = 10
ActivePush.TIER_REQUEST, ActivePush.TIER_FILL, ActivePush.TIER_CLEANUP = 0, 1, 2

--- Nächste Cleanup-Station für `key`, die vom aktiven Anbieter aus erreichbar ist (gleiche
--- Oberfläche, gleiches Team, verbundenes Netz). Ausdrücklich eingetragene Ware zuerst.
local function cleanup_for(provider, key)
  local kind, name = Util.split_key(key)
  local p_stop = provider.stop
  local place = Networks.place(p_stop.surface_index, p_stop.force_index)
  local best, best_explicit, best_dist = nil, false, math.huge
  for unit in pairs(storage.service_stations.cleanup) do
    local station = Registry.get(unit)
    local stop = station and station.stop
    if station and station.config.mode == "cleanup" and stop and stop.valid and station.entity.valid
      and stop.surface_index == p_stop.surface_index and stop.force_index == p_stop.force_index
      and Networks.related(place, provider.config.network, station.config.network) then
      local ok, explicit = Fields.cleanup_accepts(station.config, kind, name)
      if ok then
        local dist = Util.dist2(stop.position, p_stop.position)
        if (explicit and not best_explicit) or (explicit == best_explicit and dist < best_dist) then
          best, best_explicit, best_dist = station, explicit, dist
        end
      end
    end
  end
  return best
end

--- Anfragen „ab ins Cleanup“ für die Waren aktiver Anbieter an `list` anhängen.
--- `peek` = true: Reihum-Zeiger nicht weiterschieben (Anschlussfahrt).
function ActivePush.collect(list, peek)
  local dispatch = storage.dispatch
  local active = dispatch.active
  if not active or next(active) == nil then return end
  local unit = dispatch.active_cursor
  if unit and not active[unit] then unit = nil end
  local seen = {} -- je Cleanup und Ware nur eine Anfrage
  for _ = 1, ACTIVE_SCAN do
    unit = next(active, unit)
    if not unit then break end
    local provider = Registry.get(unit)
    if not (provider and provider.stop and provider.stop.valid and Fields.is_active(provider.config)) then
      active[unit] = nil
    else
      for key, amount in pairs(provider.provide) do
        local available = amount - Deliveries.outgoing(unit, key)
        if available > 0 then
          local target = cleanup_for(provider, key)
          local id = target and (target.unit .. "|" .. key) or nil
          if target and id and not seen[id] then
            seen[id] = true
            list[#list + 1] = { station = target, key = key, need = available, minimum = 1,
              priority = target.config.request_priority, only_active = true,
              tier = ActivePush.TIER_CLEANUP, since = game.tick }
          end
        end
      end
    end
  end
  if not peek then dispatch.active_cursor = unit end
end

return ActivePush
