--- Nachladen (0.0.7): Index „Lieferungen je Abnehmer“ nachtragen. Läuft einmal je Spielstand,
--- vor on_configuration_changed – deshalb prüfen, ob es die Tabellen schon gibt.
local deliveries = storage.deliveries
if not deliveries then return end

local by_requester = deliveries.by_requester or {}
for id, delivery in pairs(deliveries.active or {}) do
  local unit = delivery.requester
  if unit then
    local set = by_requester[unit]
    if not set then
      set = {}
      by_requester[unit] = set
    end
    set[id] = true
  end
end
deliveries.by_requester = by_requester
