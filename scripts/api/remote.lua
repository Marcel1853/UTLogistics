--- Remote-Schnittstelle „utl“ für andere Mods, Tests und die Konsole.
--- Beispiel: /c game.print(serpent.line(remote.call("utl", "get_station", 123)))
local Registry = require("scripts.stations.registry")
local C = require("scripts.core.constants")
local Networks = require("scripts.stations.networks")
local Unlocks = require("scripts.core.unlocks")
local TeamConfig = require("scripts.core.team-config")
local Config = require("scripts.core.config")
local Pending = require("scripts.trains.pending")
local Reader = require("scripts.stations.reader")
local Roles = require("scripts.stations.roles")
local Fields = require("scripts.stations.fields")
local Requests = require("scripts.stations.requests")
local Paste = require("scripts.stations.settings-paste")
local Blueprint = require("scripts.stations.blueprint")
local Perf = require("scripts.core.perf")
local Window = require("scripts.gui.station.window")
local Manager = require("scripts.gui.manager.window")
local Readouts = require("scripts.readout.readouts")
local ReadoutOutput = require("scripts.readout.output")
local ReadoutWindow = require("scripts.gui.readout.window")
local Statistics = require("scripts.deliveries.statistics")
local Water = require("scripts.compat.cargo-ships")
local RecipeNotice = require("scripts.gui.notice.recipe-notice")
local Rekey = require("scripts.trains.rekey")
local Elevators = require("scripts.compat.se-elevators")
local PublicEvents = require("scripts.api.public-events")
local util = require("util")

local function copy(t)
  return util.table.deepcopy(t)
end

local interface = {
  station_count = function()
    return storage.stations.count
  end,

  --- Netz-Kombinator: Einstellungen und zuletzt ausgegebene Signale, nil wenn unbekannt.
  --- mode: "stock", "storage", "demand", "shortage", "trains".
  --- { config = { network, mode, star, transit }, values = { [key] = Menge } }
  get_readout = function(unit)
    local entry = Readouts.get(unit)
    if not entry then return nil end
    return { config = copy(entry.config), values = copy(ReadoutOutput.compute(entry)) }
  end,

  --- Statistik (Manager-Reiter „Statistik“): { since, deliveries, goods = { [key] = { ten, hour } },
  --- trains = { [zug] = { deliveries, utilization } }, stations = { [station] = { sent_ten, sent_hour,
  --- received_ten, received_hour } } } über alle Oberflächen und Teams.
  get_statistics = function()
    local stats = Statistics.data()
    local goods, deliveries = {}, 0
    for place in pairs(stats.places) do
      local by_key, count = Statistics.goods(place)
      deliveries = deliveries + count
      for key, entry in pairs(by_key) do
        local sum = goods[key] or { ten = 0, hour = 0 }
        sum.ten, sum.hour = sum.ten + entry.ten, sum.hour + entry.hour
        goods[key] = sum
      end
    end
    local trains = {}
    for id, entry in pairs(stats.trains) do
      trains[id] = { deliveries = entry.deliveries, utilization = (Statistics.utilization(id)) }
    end
    local stations = {}
    for unit in pairs(stats.stations) do stations[unit] = Statistics.station(unit) end
    return { since = stats.since, deliveries = deliveries, goods = goods, trains = trains, stations = stations }
  end,

  --- Fenster eines Netz-Kombinators öffnen (ohne Reichweite, z. B. für Tipps-Szenen).
  open_readout = function(player_index, unit)
    local player = game.get_player(player_index)
    local entry = Readouts.get(unit)
    if not (player and entry and entry.entity.valid) then return false end
    ReadoutWindow.open(player, entry)
    return true
  end,

  --- Netz-Kombinator einstellen, z. B. { network = "Eisen", mode = "shortage", star = true }.
  --- Liefert false, wenn es den Kombinator nicht gibt.
  configure_readout = function(unit, changes)
    local entry = Readouts.get(unit)
    if not entry then return false end
    Readouts.configure(entry, changes)
    ReadoutOutput.write(entry)
    return true
  end,

  --- Cargo Ships: in einer Blaupause (LuaItemStack/LuaRecord) Gleise ↔ Wasserwege, Signale ↔ Bojen,
  --- Haltestellen ↔ Häfen tauschen (wie der Knopf). Liefert die Zahl getauschter Bauteile oder nil.
  convert_blueprint_water = function(blueprint)
    return Water.convert(blueprint)
  end,

  --- Hinweis-Fenster „Rezepte geändert“ (erscheint sonst nur einmal nach dem Update auf 0.0.9) zeigen.
  --- Konsole: /c remote.call("utl", "show_recipe_notice", game.player.index)
  show_recipe_notice = function(player_index)
    RecipeNotice.show(game.get_player(player_index))
  end,

  --- Für Mods, die Züge versetzen und dabei neu bauen (wie der SE-Weltraumaufzug, den UTL selbst
  --- erkennt): vorher `train_transfer_started(alte_id)`, danach `train_transfer_finished(alte_id, zug)`.
  --- Dazwischen bricht UTL die Lieferung nicht als „Zug umgebaut“ ab; am Ende ziehen alle Einträge
  --- auf die neue ID um.
  train_transfer_started = function(old_id)
    Rekey.start(old_id)
  end,
  train_transfer_finished = function(old_id, train)
    Rekey.move(old_id, train)
  end,

  --- Schalter „über den Weltraumaufzug liefern“ für ein Netz eines Teams (nur mit SE wirksam).
  set_elevator_network = function(force_name, network, on)
    local force = game.forces[force_name or "player"]
    if not (force and network) then return false end
    Elevators.set_enabled(force.index, network, on ~= false)
    return true
  end,
  --- Bekannte Aufzug-Seiten: Liste { unit, stop, opposite, surface, ok }.
  get_elevators = function()
    local list = {}
    for unit, entry in pairs(storage.elevators and storage.elevators.by_unit or {}) do
      if entry.main.valid then
        list[#list + 1] = { unit = unit, stop = entry.stop, opposite = entry.opposite,
          surface = entry.main.surface_index, ok = entry.ok }
      end
    end
    return list
  end,

  --- Anzahl freier Züge im Depot und laufender Lieferungen.
  idle_train_count = function()
    return storage.trains.count
  end,
  delivery_count = function()
    return storage.deliveries.count
  end,
  --- Wie viele Lieferungen direkt im Anschluss (ohne Depot) vergeben wurden.
  chained_count = function()
    return storage.deliveries.chained or 0
  end,

  --- Zeitmessung für die nächsten `heartbeats` Heartbeats (Ergebnis in factorio-current.log).
  perf = function(heartbeats)
    Perf.start(tonumber(heartbeats) or 60)
  end,

  --- Letzte Warnungen (neueste zuerst): { key, group, icon, count, tick }.
  get_alerts = function()
    local list = {}
    for i, entry in ipairs(storage.alert_log) do
      list[i] = { key = entry.key, group = entry.group, icon = entry.icon, count = entry.count, tick = entry.tick }
    end
    return list
  end,

  --- Laufende Lieferungen als Liste (ohne Entity-Referenzen).
  get_deliveries = function()
    local list = {}
    for _, d in pairs(storage.deliveries.active) do
      local info = PublicEvents.info(d) -- gleiche Sicht wie die Ereignisse, ohne Entity-Referenz
      info.train = nil
      list[#list + 1] = info
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
  end,

  --- Kopie der Stationsdaten (ohne Entity-Referenzen), nil wenn unbekannt.
  get_station = function(unit)
    local station = Registry.get(unit)
    if not station then return nil end
    local stop = station.stop
    return {
      unit = station.unit,
      kind = station.kind,
      stop_name = stop and stop.valid and stop.backer_name or nil,
      config = copy(station.config),
      provide = copy(station.provide),
      request = copy(station.request),
      provide_rank = copy(station.provide_rank or {}), -- Lager: [key] = 0 Reserve / 1 normal
      version = station.version,
    }
  end,

  --- Einstellungen übernehmen, z. B. { mode = "station", provide = true, request = false, priority = 5 }.
  configure_station = function(unit, changes)
    local station = Registry.get(unit)
    if not station or type(changes) ~= "table" then return false end
    -- unbekannter Modus nähme der Station still alle Rollen
    local mode = changes.mode
    if mode ~= nil and mode ~= "storage" then
      local ok = false
      for _, known in ipairs(C.modes) do ok = ok or known == mode end
      if not ok then return false end
    end
    local cfg = station.config
    for key, value in pairs(changes) do
      if key ~= "roles" and cfg[key] ~= nil and type(cfg[key]) == type(value) then
        if type(value) == "table" and key ~= "requests" and key ~= "request_map" then
          -- verschachtelte Einstellungen (cleanup, storage) zusammenführen statt ersetzen –
          -- sonst verlöre { cleanup = { offer = … } } die Warenliste
          for sub, v in pairs(value) do cfg[key][sub] = v end
        else
          cfg[key] = value
        end
      end
    end
    Fields.fill(cfg)
    Roles.derive(cfg)
    Reader.read(station)
    Registry.config_changed(station)
    return true
  end,

  --- Netze zu einem Stern verbinden: `partner` hilft `center` und umgekehrt (je Oberfläche und
  --- Team; `force` = Name, Standard „player“). Grenze wie im Spiel aus der Forschung der Force.
  --- Liefert true oder den Grund als Text.
  link_networks = function(surface_index, center, partner, force)
    local f = game.forces[force or "player"]
    if not f then return "link-limit" end
    return Networks.link(Networks.place(surface_index, f.index), center, partner, Unlocks.networks_limit(f))
  end,

  --- Team-Wert setzen (z. B. "load_timeout", "unload_timeout" in Sekunden); nil = Kartenwert.
  set_team_config = function(force_name, key, value)
    local force = game.forces[force_name]
    if not force then return false end
    -- nur bekannte Team-Werte, Typ wie der zugehörige Kartenwert (sonst stürzte später der
    -- Zeitlimit-Code über einen Text statt einer Zahl); nil = wieder der Kartenwert
    local setting = nil
    for _, entry in ipairs(TeamConfig.KEYS) do
      if entry.key == key then setting = entry.setting end
    end
    local proto = setting and prototypes.mod_setting[setting]
    if not proto then return false end
    if value ~= nil then
      if proto.allowed_values then
        local ok = false
        for _, allowed in ipairs(proto.allowed_values) do ok = ok or allowed == value end
        if not ok then return false end
      elseif type(value) ~= "number" then
        return false
      end
    end
    TeamConfig.set(force, key, value)
    return true
  end,

  --- Wie viele Züge sind per Wegpunkt zu dieser Haltestelle unterwegs (Depot, Tanken, Cleanup)?
  --- Zusammen mit `stop.trains_count` ergibt das die Belegung gegen das Zuglimit.
  pending_trains = function(stop_unit)
    return Pending.counts()[stop_unit] or 0
  end,

  --- Kartenwert setzen wie im UTL-Manager (Einstellungsname, z. B. "utl-load-timeout";
  --- nil = wieder der Wert aus den Mod-Einstellungen). Prüft Typ und Grenzen.
  set_map_config = function(name, value)
    local proto = prototypes.mod_setting[name]
    if not (proto and settings.global[name] and string.sub(name, 1, 4) == "utl-") then return false end
    if value ~= nil then
      if proto.type == "bool-setting" then
        if type(value) ~= "boolean" then return false end
      elseif proto.allowed_values then
        local ok = false
        for _, allowed in ipairs(proto.allowed_values) do ok = ok or allowed == value end
        if not ok then return false end
      else
        if type(value) ~= "number" then return false end
        if proto.type == "int-setting" then value = math.floor(value + 0.5) end
        if proto.minimum_value and value < proto.minimum_value then return false end
        if proto.maximum_value and value > proto.maximum_value then return false end
      end
    end
    Config.set(name, value)
    return true
  end,

  --- Gültiger Team-Wert (eigener Wert oder Kartenwert).
  get_team_config = function(force_name, key)
    return TeamConfig.get(game.forces[force_name], key)
  end,

  --- Verbindung zweier Netze lösen (`force` wie bei link_networks).
  unlink_networks = function(surface_index, a, b, force)
    local f = game.forces[force or "player"]
    return f ~= nil and Networks.unlink(Networks.place(surface_index, f.index), a, b)
  end,

  --- Stern eines Netzes: { role, center, partners } (`force` wie bei link_networks).
  get_network_star = function(surface_index, name, force)
    local f = game.forces[force or "player"]
    if not f then return nil end
    return Networks.star(Networks.place(surface_index, f.index), name)
  end,

  --- Alle Einstellungen einer Station auf eine andere kopieren (wie Shift-Klick).
  copy_settings = function(from_unit, to_unit)
    local source, destination = Registry.get(from_unit), Registry.get(to_unit)
    if not (source and destination) then return false end
    return Paste.copy(source, destination)
  end,

  --- UTL-Einstellungen in eine per Script erstellte Blaupause schreiben.
  --- Beispiel: local map = stack.create_blueprint{...}; remote.call("utl", "tag_blueprint", stack, map)
  tag_blueprint = function(blueprint, mapping, surface)
    return Blueprint.tag(blueprint, mapping, surface)
  end,

  --- Anforderungs-Slot setzen, z. B. set_request(unit, 1, { type = "item", name = "iron-plate" }, 400).
  --- signal = nil leert den Slot.
  set_request = function(unit, slot, signal, count)
    local station = Registry.get(unit)
    if not station or type(slot) ~= "number" or slot < 1 or slot > Requests.slot_count then return false end
    Requests.set(station.config, slot, signal, count or 0)
    Reader.read(station)
    return true
  end,

  --- Stationsfenster für einen Spieler öffnen (Tipps-Szenen, Tests). `tab` 2 = Reiter „Werte“
  --- (nur UTL-Haltestelle). Bei der Haltestelle öffnet sich das Vanilla-Fenster mit UTL-Panel,
  --- mit `standalone` nur das UTL-Panel als eigenes Fenster.
  open_station = function(player_index, unit, tab, standalone)
    local player = game.get_player(player_index)
    local station = Registry.get(unit)
    if not (player and station and station.entity.valid) then return false end
    if standalone then
      Window.open(player, station, true)
    else
      -- dieselbe Haltestelle nicht erneut öffnen (schlösse das Fenster), nur den Reiter wechseln
      if station.kind == "stop" and player.opened ~= station.entity then player.opened = station.entity end
      if not Window.get(player_index) then Window.open(player, station) end
    end
    if tab then Window.select_tab(player_index, tab) end
    return true
  end,

  --- UTL-Manager öffnen, optional mit Reiter: depots, stations, networks, inventory, history,
  --- alerts. `select` wählt wie ein Klick etwas aus (Tipps-Szenen): { network = "<oberfläche>|<name>" }
  --- im Reiter „Netzwerke“, { ware = "item|iron-plate|normal" } im Reiter „Inventar“.
  open_manager = function(player_index, tab, select)
    local player = game.get_player(player_index)
    if not player then return false end
    if not Manager.get(player_index) then Manager.open(player) end
    local manager = Manager.get(player_index)
    if manager and select then
      if select.network then manager.network = select.network end
      if select.ware then manager.ware = select.ware end
    end
    if tab then Manager.select(player_index, tab) else Manager.refresh(player_index) end
    return true
  end,

  --- UTL-Fenster eines Spielers schließen.
  close_windows = function(player_index)
    local player = game.get_player(player_index)
    if player then player.opened = nil end
    Window.close(player_index)
    Manager.close(player_index)
    ReadoutWindow.close(player_index)
  end,
}

-- Weitere Funktionen (0.0.10): Ereignisse, einzelne Lieferung/Zug, Listen, Abbrechen
for name, fn in pairs(require("scripts.api.remote-more")) do interface[name] = fn end

-- Jede Funktion kann vor UTLs on_init aufgerufen werden (Szenario-Script startet zuerst).
local State = require("scripts.core.state")
for name, fn in pairs(interface) do
  interface[name] = function(...)
    State.ensure()
    return fn(...)
  end
end

remote.add_interface("utl", interface)
