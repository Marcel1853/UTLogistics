--- Reservierungen der Lieferungen: beim Anbieter bis zur Abfahrt reserviert (outgoing), beim
--- Abnehmer bis zum Entladen unterwegs (incoming), dazu Züge je Station (trains_at).
---
--- Zweiter Anbieter (Kartenwert „utl-multi-pickup“): `delivery.second = { unit, manifest, name,
--- released }` ist der zweite Ladehalt. `delivery.manifest` bleibt die Gesamtmenge; beim ersten
--- Anbieter ist nur sein Anteil reserviert (Gesamtmenge minus Anteil des zweiten).
local Output = require("scripts.stations.output")

local Reservations = {}

function Reservations.add(map, unit, key, amount)
  Output.mark(unit) -- Auftrags-Ausgabe dieser Station neu schreiben
  local by_key = map[unit]
  if not by_key then
    by_key = {}
    map[unit] = by_key
  end
  local value = (by_key[key] or 0) + amount
  if value <= 0 then
    by_key[key] = nil
    if next(by_key) == nil then map[unit] = nil end
  else
    by_key[key] = value
  end
end
local add = Reservations.add

function Reservations.count_train(unit, delta)
  local trains_at = storage.deliveries.trains_at
  local value = (trains_at[unit] or 0) + delta
  trains_at[unit] = value > 0 and value or nil
end
local count_train = Reservations.count_train

--- Reservierte Menge beim Anbieter.
function Reservations.outgoing(unit, key)
  local by_key = storage.deliveries.outgoing[unit]
  return by_key and by_key[key] or 0
end

--- Menge, die zum Abnehmer unterwegs ist.
function Reservations.incoming(unit, key)
  local by_key = storage.deliveries.incoming[unit]
  return by_key and by_key[key] or 0
end

--- Züge, die gerade zu dieser Station unterwegs sind oder dort stehen.
function Reservations.trains_at(unit)
  return storage.deliveries.trains_at[unit] or 0
end

--- Anteil des ersten Anbieters: Gesamtmenge minus Anteil des zweiten.
function Reservations.first_share(delivery)
  local second = delivery.second
  if not second then return delivery.manifest end
  local share = {}
  for key, amount in pairs(delivery.manifest) do
    local rest = amount - (second.manifest[key] or 0)
    if rest > 0 then share[key] = rest end
  end
  return share
end

--- Station, bei der gerade geladen wird bzw. die der Zug als Nächstes zum Laden anfährt.
function Reservations.pickup_unit(delivery)
  if delivery.leg == 2 and delivery.second then return delivery.second.unit end
  return delivery.provider
end

--- Neue Lieferung buchen.
function Reservations.book(delivery)
  local deliveries = storage.deliveries
  for key, amount in pairs(Reservations.first_share(delivery)) do add(deliveries.outgoing, delivery.provider, key, amount) end
  for key, amount in pairs(delivery.manifest) do add(deliveries.incoming, delivery.requester, key, amount) end
  count_train(delivery.provider, 1)
  count_train(delivery.requester, 1)
  local second = delivery.second
  if second then
    for key, amount in pairs(second.manifest) do add(deliveries.outgoing, second.unit, key, amount) end
    count_train(second.unit, 1)
  end
end

--- Reservierung beim (ersten) Anbieter freigeben (einmalig).
function Reservations.release_provider(delivery)
  if delivery.provider_released then return end
  for key, amount in pairs(Reservations.first_share(delivery)) do
    add(storage.deliveries.outgoing, delivery.provider, key, -amount)
  end
  delivery.provider_released = true
  count_train(delivery.provider, -1)
end

--- Reservierung beim zweiten Anbieter freigeben (einmalig).
function Reservations.release_second(delivery)
  local second = delivery.second
  if not second or second.released then return end
  second.released = true
  for key, amount in pairs(second.manifest) do add(storage.deliveries.outgoing, second.unit, key, -amount) end
  count_train(second.unit, -1)
end

--- „Unterwegs“ beim Abnehmer freigeben.
function Reservations.release_requester(delivery)
  for key, amount in pairs(delivery.manifest) do add(storage.deliveries.incoming, delivery.requester, key, -amount) end
  count_train(delivery.requester, -1)
end

return Reservations
