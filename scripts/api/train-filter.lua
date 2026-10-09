--- Zugwahl mit Add-ons (register_train_filter): Ist an einer Fahrt eine Station mit Add-on-Rolle
--- beteiligt, darf jedes angemeldete Add-on die Kandidaten einmal je Vermittlung sehen und eine
--- Liste erlaubter Zug-IDs in Wunschreihenfolge zurückgeben. Ohne Add-on-Rolle oder ohne Filter
--- kostet das nichts (kein remote.call).
local Addons = require("scripts.api.addons")

local TrainFilter = {}

--- `best` = Liste { record, amount, distance } (beste zuerst). Liefert die gefilterte Liste.
function TrainFilter.apply(best, provider, requester, key)
  if not (provider.config.addon_role or requester.config.addon_role) then return best end
  local filters = Addons.list("filters")
  if not filters[1] or not best[1] then return best end
  for _, entry in ipairs(filters) do
    local ids, by_id = {}, {}
    for i, candidate in ipairs(best) do
      ids[i] = candidate.record.id
      by_id[candidate.record.id] = candidate
    end
    local ok, allowed = Addons.call(entry.mod, entry.interface, entry.build, ids, {
      provider = provider.unit, requester = requester.unit, key = key,
      provider_role = provider.config.addon_role, requester_role = requester.config.addon_role,
    })
    if ok and type(allowed) == "table" then
      local kept = {}
      for _, id in ipairs(allowed) do
        local candidate = by_id[id]
        if candidate then
          kept[#kept + 1] = candidate
          by_id[id] = nil -- jede ID nur einmal
        end
      end
      best = kept
    end
  end
  return best
end

return TrainFilter
