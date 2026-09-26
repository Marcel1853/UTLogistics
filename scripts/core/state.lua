--- Layout von `storage`. Alles hier ist idempotent und darf beliebig oft laufen.
--- Es ergänzt nur fehlende Tabellen; Umbauten bestehender Daten gehören in migrations/.
local Config = require("scripts.core.config")

local State = {}

function State.init()
  -- Heartbeat-Zähler (für Aufgaben mit eigenem Takt).
  storage.heartbeat = storage.heartbeat or { count = 0 }

  -- Stationen, Schlüssel = unit_number des Combinators.
  local stations = storage.stations or {}
  stations.by_unit = stations.by_unit or {}
  stations.by_stop = stations.by_stop or {} -- [unit_number Zughalt] = unit_number Combinator
  stations.count = stations.count or 0
  stations.dirty = stations.dirty or {}     -- [unit] = true, wenn sich Angebot/Bedarf geändert hat
  -- stations.cursor: Round-Robin-Position des Lesers (darf nil sein)
  storage.stations = stations

  -- Züge: nur die, die gerade frei im Depot stehen (by_id), nach Netzwerk sortiert (idle).
  local trains = storage.trains or {}
  trains.by_id = trains.by_id or {} -- [train_id] = Zug-Eintrag (siehe trains/depot.lua)
  trains.count = trains.count or 0
  trains.idle = trains.idle or {}   -- ["<ort>|<netzwerk>"] = { [train_id] = true } (Ort = Oberfläche + Team)
  -- [train_id] = "fuel" | "cleanup" | "both" | "relocate" | "relocate-serviced": auf
  -- Dienstfahrt bzw. zu einem passenden Depot geschickt (verhindert Pendeln)
  trains.service = trains.service or trains.refueling or {}
  trains.refueling = nil
  trains.pending = trains.pending or {} -- [train_id] = { [Haltestelle] = true }: per Wegpunkt unterwegs dorthin
  trains.visiting = trains.visiting or {} -- [train_id] = Tank-/Cleanup-Haltestelle, an der er steht
  trains.cargo_waiting = trains.cargo_waiting or {} -- [train_id] = { train, stop, network }: Restladung, kein Cleanup frei
  trains.home = trains.home or {} -- [train_id] = { train, depot = Name, stop = Haltestelle } (für den Manager)
  trains.filtered = trains.filtered or {} -- [train_id] = von UTL gesetzte Ladefilter (wagon-filters.lua)
  storage.trains = trains

  -- Dienst-Stationen: [rolle][station] = true (fuel, cleanup)
  local services = storage.service_stations or {}
  services.fuel = services.fuel or storage.fuel_stations or {}
  services.cleanup = services.cleanup or {}
  storage.service_stations = services
  storage.fuel_stations = nil

  -- Lieferungen und Reservierungen.
  local deliveries = storage.deliveries or {}
  deliveries.active = deliveries.active or {}     -- [id] = Lieferung
  deliveries.count = deliveries.count or 0
  deliveries.next_id = deliveries.next_id or 1
  deliveries.by_train = deliveries.by_train or {} -- [train_id] = id
  deliveries.by_requester = deliveries.by_requester or {} -- [station] = { [id] = true } (Nachladen)
  deliveries.outgoing = deliveries.outgoing or {} -- [station] = { [key] = reservierte Menge }
  deliveries.incoming = deliveries.incoming or {} -- [station] = { [key] = Menge unterwegs }
  deliveries.trains_at = deliveries.trains_at or {} -- [station] = Züge auf dem Weg dorthin
  deliveries.output_dirty = deliveries.output_dirty or {} -- [station] = Auftrags-Ausgabe neu schreiben
  -- [station] = { id, length, wagons }: Zug, der gerade an dieser Station steht (für die Ausgabe)
  deliveries.at_station = deliveries.at_station or {}
  storage.deliveries = deliveries

  -- Verbundene Netze (Stern je Oberfläche), siehe scripts/stations/networks.lua
  storage.network_links = storage.network_links or {}

  -- Dispatcher: Anbieter-Index pro Ware und Menge der Abnehmer.
  local dispatch = storage.dispatch or {}
  dispatch.providers = dispatch.providers or {}         -- [key] = { [station] = true }
  dispatch.provider_keys = dispatch.provider_keys or {} -- [station] = { [key] = true }
  dispatch.requesters = dispatch.requesters or {}       -- [station] = true
  dispatch.starving = dispatch.starving or {}           -- [netzwerk][station|key] = Anfrage ohne freien Zug
  dispatch.waiting = dispatch.waiting or {}             -- [station][key] = { since, seen }: unbedient seit
  -- dispatch.cursor: Round-Robin-Position über die Abnehmer (darf nil sein)
  storage.dispatch = dispatch

  -- Wiederholsperre der Warnungen: [schlüssel] = tick der letzten Warnung
  storage.alerts = storage.alerts or {}
  -- Letzte Warnungen für den Manager-Reiter „Alarme“ (neueste zuerst)
  storage.alert_log = storage.alert_log or {}

  -- Verlauf abgeschlossener/abgebrochener Lieferungen, neueste zuerst (begrenzt).
  storage.history = storage.history or {}

  -- Offene Fenster pro Spieler: Stationsfenster (guis) und Manager (managers).
  storage.guis = storage.guis or {}
  storage.managers = storage.managers or {}
  storage.manager_prefs = storage.manager_prefs or {}
  storage.admin_windows = storage.admin_windows or {} -- offene Admin-Fenster (scripts/gui/admin)
  storage.map_config = storage.map_config or {} -- [Einstellung] = Wert, im UTL-Manager geändert (config.lua)
  storage.team_config = storage.team_config or {} -- [force_index] = { load_timeout = …, … }, siehe team-config.lua
end

--- Für Aufrufe, die *vor* UTLs on_init kommen können: Factorio startet das Script eines
--- Szenarios vor den Mods. Baut es dabei Haltestellen oder ruft die Remote-Schnittstelle auf,
--- legt UTL seinen Speicher eben hier an (on_init macht danach nichts mehr kaputt).
function State.ensure()
  if storage.stations then return end
  State.init()
  Config.refresh()
end

return State
