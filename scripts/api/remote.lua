--- Remote-Schnittstelle „utl“ für andere Mods, Tests und die Konsole.
--- Beispiel: /c game.print(serpent.line(remote.call("utl", "get_station", 123)))
local Registry = require("scripts.stations.registry")
local Networks = require("scripts.stations.networks")
local Unlocks = require("scripts.core.unlocks")
local TeamConfig = require("scripts.core.team-config")
local Config = require("scripts.core.config")
local Pending = require("scripts.trains.pending")
local Reader = require("scripts.stations.reader")
local Roles = require("scripts.stations.roles")
local Requests = require("scripts.stations.requests")
local Paste = require("scripts.stations.settings-paste")
local Blueprint = require("scripts.stations.blueprint")
local Perf = require("scripts.core.perf")
local Window = require("scripts.gui.station.window")
local Manager = require("scripts.gui.manager.window")
local util = require("util")

local function copy(t)
  return util.table.deepcopy(t)
end

local interface = {
  station_count = function()
    return storage.stations.count
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
    Perf.start(heartbeats or 60)
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
    for id, d in pairs(storage.deliveries.active) do
      list[#list + 1] = {
        id = id, train_id = d.train_id, provider = d.provider, requester = d.requester,
        from = d.from, to = d.to, network = d.network, -- Namen der Haltestellen und das Netzwerk
        manifest = util.table.deepcopy(d.manifest), state = d.state, started = d.started, chained = d.chained,
      }
    end
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
      version = station.version,
    }
  end,

  --- Einstellungen übernehmen, z. B. { mode = "station", provide = true, request = false, priority = 5 }.
  configure_station = function(unit, changes)
    local station = Registry.get(unit)
    if not station then return false end
    local cfg = station.config
    for key, value in pairs(changes) do
      if key ~= "roles" and cfg[key] ~= nil and type(cfg[key]) == type(value) then
        cfg[key] = value
      end
    end
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
    return Networks.star(Networks.place(surface_index, f and f.index or 1), name)
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
    if not station or slot < 1 or slot > Requests.slot_count then return false end
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
  end,
}

-- Jede Funktion kann vor UTLs on_init aufgerufen werden (Szenario-Script startet zuerst).
local State = require("scripts.core.state")
for name, fn in pairs(interface) do
  interface[name] = function(...)
    State.ensure()
    return fn(...)
  end
end

remote.add_interface("utl", interface)
