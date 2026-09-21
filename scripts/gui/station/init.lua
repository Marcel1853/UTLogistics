--- Verdrahtet das Stationsfenster mit den GUI-Events.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Registry = require("scripts.stations.registry")
local Reader = require("scripts.stations.reader")
local Window = require("scripts.gui.station.window")
local Main = require("scripts.gui.station.panel-main")
local Values = require("scripts.gui.station.panel-values")
local RequestsSection = require("scripts.gui.station.section-requests")
local CleanupSection = require("scripts.gui.station.section-cleanup")
local Networks = require("scripts.stations.networks")
local Nets = require("scripts.gui.station.section-networks")

local function tags_of(element)
  if not (element and element.valid) then return nil end
  local tags = element.tags
  return tags and tags.utl_action and tags or nil
end

--- Station neu lesen und Fenster auffrischen; `rebuild` baut es komplett neu auf.
local function changed(event, station, rebuild)
  Reader.read(station)
  Registry.config_changed(station)
  if rebuild then
    local player = game.get_player(event.player_index)
    local gui = Window.get(event.player_index)
    if player then Window.open(player, station, gui and gui.standalone) end
  else
    Window.refresh(event.player_index)
  end
end

--- Kontext für ein Event aus unserem Fenster: tags, gui, station (alle drei oder keiner).
local function context(event)
  local tags = tags_of(event.element)
  if not tags then return nil end
  local gui = Window.get(event.player_index)
  local station = gui and Registry.get(gui.unit)
  if not station then return nil end
  return tags, gui, station
end

local function is_station_entity(entity)
  if not (entity and entity.valid) then return false end
  local name = entity.name
  return name == C.station_combinator or name == C.train_stop
end

Events.on(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not is_station_entity(entity) then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local station = Registry.get_or_add(entity)
  if station then Window.open(player, station) end
end)

Events.on(defines.events.on_gui_closed, function(event)
  -- Eigenes Fenster (Combinator) oder Vanilla-Haltestellenfenster mit unserem Panel.
  -- Nicht beim Combinator-Entity: das Vanilla-Fenster schließt, weil wir es ersetzen.
  local entity = event.entity
  local utl_stop_closed = entity and entity.valid and entity.name == C.train_stop
  if Window.is_window(event.element) or utl_stop_closed then
    Window.close(event.player_index)
  end
end)

--- Eingegebenen Netznamen übernehmen: entweder als Heimatnetz oder als neues Zusatznetz.
local function apply_network_name(event, gui, station)
  local refs = gui.main.net
  local field = refs.field
  local target = field.tags.target
  local name = field.text
  Nets.stop_edit(refs)
  if target == "home" then
    Nets.apply_home(station.config, name)
  elseif not Networks.toggle(station.config, name ~= "" and name or nil) then
    return
  end
  Networks.invalidate()
  changed(event, station, true)
end

Events.on(defines.events.on_gui_click, function(event)
  local tags, gui, station = context(event)
  if not (tags and gui and station) then return end
  local action, cfg = tags.utl_action, station.config
  if action == "close" then
    Window.close(event.player_index)
  elseif action == "reset" then
    if Values.reset(cfg, tags.key) then changed(event, station, true) end
  elseif action == "req_slot" then
    if event.button == defines.mouse_button_type.right then
      RequestsSection.clear(gui.requests, cfg, tags.slot)
      changed(event, station, false)
    elseif cfg.requests[tags.slot] then
      RequestsSection.select(gui.requests, cfg, tags.slot)
    end
  elseif action == "req_confirm" then
    if RequestsSection.confirm(gui.requests, cfg) then changed(event, station, false) end
  elseif action == "req_cancel" then
    RequestsSection.select(gui.requests, cfg, nil)
  elseif action == "cleanup_all" then
    if CleanupSection.toggle(cfg, tags.key) then changed(event, station, true) end
  elseif action == "network_chip" then
    if Networks.toggle(cfg, tags.network) then
      Networks.invalidate()
      changed(event, station, true)
    end
  elseif action == "network_rename" then
    Nets.start_edit(gui.main.net, "home", cfg.network)
  elseif action == "network_confirm" then
    apply_network_name(event, gui, station)
  elseif action == "network_cancel" then
    Nets.stop_edit(gui.main.net)
  end
end)

Events.on(defines.events.on_gui_elem_changed, function(event)
  local tags, gui, station = context(event)
  if not (tags and gui and station) then return end
  local action = tags.utl_action
  if action == "req_slot" then
    RequestsSection.on_elem_changed(gui.requests, station.config, tags.slot, event.element.elem_value)
    changed(event, station, false)
  elseif action == "cleanup_item" or action == "cleanup_fluid" then
    local value = event.element.elem_value
    CleanupSection.set(station.config, action, tags.slot, type(value) == "string" and value or nil)
    changed(event, station, false)
  end
end)

Events.on(defines.events.on_gui_checked_state_changed, function(event)
  local tags, _, station = context(event)
  if not (tags and station) then return end
  if tags.utl_action == "role" then
    Main.apply_role(station.config, tags.role, event.element.state)
    changed(event, station, true)
  elseif tags.utl_action == "toggle" then
    if Values.toggle(station.config, tags.key, event.element.state) then changed(event, station, false) end
  end
end)

-- Auswahllisten des Netzwerk-Abschnitts: Heimatnetz und „Netz hinzufügen“.
Events.on(defines.events.on_gui_selection_state_changed, function(event)
  local tags, gui, station = context(event)
  if not (tags and gui and station) then return end
  local action, element = tags.utl_action, event.element
  if action == "network_pick" then
    local name = element.get_item(element.selected_index)
    if type(name) == "string" then
      Nets.apply_home(station.config, name)
      Networks.invalidate()
      changed(event, station, true)
    end
  elseif action == "network_add_pick" then
    local index = element.selected_index
    if index == #element.items then -- letzter Eintrag: „Neu …“
      element.selected_index = 1
      Nets.start_edit(gui.main.net, "extra", "")
    elseif index > 1 then
      local name = element.get_item(index)
      if type(name) == "string" and Networks.toggle(station.config, name) then
        Networks.invalidate()
        changed(event, station, true)
      end
    end
  end
end)

Events.on(defines.events.on_gui_text_changed, function(event)
  local tags, gui, station = context(event)
  if not (tags and gui and station) then return end
  local action, cfg = tags.utl_action, station.config
  if action == "value" then
    if Values.apply(cfg, tags.key, event.element.text) then changed(event, station, false) end
  elseif action == "req_stacks" or action == "req_items" then
    RequestsSection.sync(gui.requests, cfg, action)
  end
end)

Events.on(defines.events.on_gui_confirmed, function(event)
  local tags, gui, station = context(event)
  if not (tags and gui and station) then return end
  local action = tags.utl_action
  if action == "req_stacks" or action == "req_items" then
    if RequestsSection.confirm(gui.requests, station.config) then changed(event, station, false) end
  elseif action == "value" then
    changed(event, station, true) -- Reset-Knöpfe an/aus neu setzen
  elseif action == "network_name" then
    apply_network_name(event, gui, station)
  end
end)

-- Einstellungen per Shift-Klick eingefügt: offene Fenster dieser Station neu aufbauen.
Events.on(defines.events.on_entity_settings_pasted, function(event)
  local entity = event.destination
  if not (entity and entity.valid and entity.unit_number) then return end
  local station = Registry.get(entity.unit_number)
  if not station then return end
  for player_index, gui in pairs(storage.guis) do
    local player = game.get_player(player_index)
    if player and gui.unit == station.unit then Window.open(player, station) end
  end
end)

-- Nach einem Mod-Update alle Fenster schließen; sie werden beim nächsten Klick neu gebaut.
Events.on_configuration_changed(Window.close_all)

Heartbeat.add_task("station-gui-refresh", C.gui_refresh_every, Window.refresh_all)
