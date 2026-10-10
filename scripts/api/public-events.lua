--- Ereignisse für andere Mods (IDs über remote.call("utl", "get_event_ids")):
---   on_delivery_created        – Lieferung angelegt, Zug losgeschickt
---   on_delivery_state_changed  – neuer Zustand (loading, to_requester, unloading, to_provider beim
---                                zweiten Anbieter)
---   on_delivery_completed      – beim Abnehmer entladen und abgefahren
---   on_delivery_canceled       – abgebrochen (Feld `reason`)
---   on_train_arrived           – Zug wartet an einer UTL-Station (train, station, stop, mode, roles,
---                                delivery_id, held_by)
---   on_train_departed          – Zug verlässt eine UTL-Station (dieselben Felder)
---   on_train_idle              – Zug steht frei im Depot (train, station, stop, network)
---   on_train_rebuilt           – Zug mit UTL-Daten umgebaut (train, old_train_ids, canceled, changing)
---   on_job_finished            – Auftrag eines Add-ons fertig oder abgebrochen (job_id, mod, train,
---                                train_id, canceled, reason)
---   on_station_created/_changed – Station gebaut bzw. Einstellungen geändert (station, kind, stop,
---                                stop_name, network, mode, roles, addon_role)
---   on_station_removed         – Station abgerissen (station, kind)
---   on_alert                   – UTL-Warnung (group, icon, entity, message, key, force, surface)
---   on_request_unserved        – Abnehmer wartet länger als eingestellt ohne Zug (station, key, network,
---                                since, reason, provider) – höchstens einmal je Minute und Anfrage
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
  -- seit der API-Beta (Schnittstelle für Add-ons, api/remote-addons.lua); neue IDs immer hinten anhängen
  on_train_arrived = script.generate_event_name(),
  on_train_departed = script.generate_event_name(),
  on_train_idle = script.generate_event_name(),
  on_train_rebuilt = script.generate_event_name(),
  on_job_finished = script.generate_event_name(),
  on_station_created = script.generate_event_name(),
  on_station_removed = script.generate_event_name(),
  on_station_changed = script.generate_event_name(),
  on_alert = script.generate_event_name(),
  on_request_unserved = script.generate_event_name(),
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
    extra_stops = delivery.extra_stops, -- von Add-ons eingefügte Halte (Anzahl)
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

--- Öffentliche Sicht auf eine Station (Stations-Ereignisse).
function PublicEvents.station_info(station)
  local cfg = station.config
  local stop = station.stop
  return {
    station = station.unit,
    kind = station.kind,
    stop = stop and stop.valid and stop or nil,
    stop_name = stop and stop.valid and stop.backer_name or nil,
    network = cfg.network,
    mode = cfg.mode,
    roles = util.table.deepcopy(cfg.roles),
    addon_role = cfg.addon_role,
  }
end

--- Ereignis `name` mit fertigen Daten auslösen (Zug-Ereignisse; nur Kopien bzw. LuaObjekte).
function PublicEvents.raise_data(name, data)
  script.raise_event(PublicEvents.ids[name], data)
end

return PublicEvents
