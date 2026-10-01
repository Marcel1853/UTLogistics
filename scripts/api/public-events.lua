--- Ereignisse für andere Mods (IDs über remote.call("utl", "get_event_ids")):
---   on_delivery_created        – Lieferung angelegt, Zug losgeschickt
---   on_delivery_state_changed  – neuer Zustand (loading, to_requester, unloading, to_provider beim
---                                zweiten Anbieter)
---   on_delivery_completed      – beim Abnehmer entladen und abgefahren
---   on_delivery_canceled       – abgebrochen (Feld `reason`)
--- Daten: siehe `Events.info` (keine Tabellen aus storage, nur Kopien). Ausgelöst wird immer erst
--- am Ende der eigenen Verarbeitung, damit ein Empfänger UTL nicht mitten im Ablauf stört.
local util = require("util")

local PublicEvents = {}

-- IDs im Hauptteil erzeugen: dort ist die Reihenfolge bei jedem Laden gleich (auch in on_load)
PublicEvents.ids = {
  on_delivery_created = script.generate_event_name(),
  on_delivery_state_changed = script.generate_event_name(),
  on_delivery_completed = script.generate_event_name(),
  on_delivery_canceled = script.generate_event_name(),
}

--- Öffentliche Sicht auf eine Lieferung (auch für get_deliveries/get_delivery).
function PublicEvents.info(delivery)
  local train = delivery.train
  return {
    id = delivery.id,
    delivery_id = delivery.id,
    train_id = delivery.train_id,
    train = train and train.valid and train or nil,
    provider = delivery.provider,
    requester = delivery.requester,
    second = delivery.second and delivery.second.unit or nil, -- zweiter Anbieter (utl-multi-pickup)
    leg = delivery.leg,
    from = delivery.from,
    to = delivery.to,
    network = delivery.network,
    manifest = util.table.deepcopy(delivery.manifest),
    state = delivery.state,
    started = delivery.started,
    chained = delivery.chained,
  }
end

--- Ereignis `name` für `delivery` auslösen; `extra` (optional) wird in die Daten übernommen.
function PublicEvents.raise(name, delivery, extra)
  local data = PublicEvents.info(delivery)
  if extra then
    for key, value in pairs(extra) do data[key] = value end
  end
  script.raise_event(PublicEvents.ids[name], data)
end

return PublicEvents
