--- Parameter-Planer (Test, Wunsch Marcel 04.10.2026): eigene Blaupause mit Abfrage beim Platzieren.
---   1. Werkzeug „utl-param-planner“ (Shortcut-Leiste) über die Station(en) ziehen.
---   2. Fenster: was soll beim Platzieren abgefragt werden? → Blaupause landet im Cursor. Jede
---      UTL-Station darin trägt zusätzlich den Tag `utl_ask` = Liste der Punkte.
---   3. Beim Platzieren entstehen Geister mit diesem Tag → Abfrage-Fenster. Die Antworten kommen in
---      die Tags der Geister (gebaut wird dann wie gewohnt) bzw. in schon gebaute Stationen.
--- Der Einstellungs-Kombinator bleibt in der Blaupause, aber leer – sonst überschriebe er die
--- Antworten beim Bau mit den alten Werten.
local C = require("scripts.core.constants")
local Events = require("scripts.core.events")
local Heartbeat = require("scripts.core.heartbeat")
local Registry = require("scripts.stations.registry")
local Blueprint = require("scripts.stations.blueprint")
local Paste = require("scripts.stations.settings-paste")
local Ask = require("scripts.parameter.fields")
local Windows = require("scripts.parameter.windows")
local util = require("util")

local TOOL = "utl-param-planner"
local ASK_TAG = "utl_ask"

local function station_of(entity)
  if not (entity and entity.valid and entity.unit_number) then return nil end
  local station = Registry.get(entity.unit_number)
  if station then return station end
  local unit = entity.type == "train-stop" and storage.stations.by_stop[entity.unit_number]
  return unit and Registry.get(unit) or nil
end

local function pending()
  storage.param_planner = storage.param_planner or { select = {}, ask = {} }
  return storage.param_planner
end

-- 1. Bereich gezogen
local function on_selected(event)
  if event.item ~= TOOL then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local count = 0
  for _, entity in pairs(event.entities) do
    if station_of(entity) then count = count + 1 end
  end
  if count == 0 then
    player.create_local_flying_text({ text = { "utl-param.no-station" }, create_at_cursor = true })
    return
  end
  pending().select[player.index] = { surface = event.surface.index, area = event.area }
  player.clear_cursor() -- Planer nach dem Ziehen aus der Hand (Wunsch Marcel)
  Windows.choose(player, count)
end
Events.on(defines.events.on_player_selected_area, on_selected)
Events.on(defines.events.on_player_alt_selected_area, on_selected)

-- 2. Blaupause erstellen
local function make(player)
  local sel = pending().select[player.index]
  local keys = Windows.chosen(player)
  Windows.close(player, Windows.CHOOSE)
  pending().select[player.index] = nil
  local surface = sel and game.get_surface(sel.surface)
  if not surface then return end
  player.clear_cursor()
  local stack = player.cursor_stack
  if not (stack and stack.set_stack({ name = "blueprint" })) then return end
  local mapping = stack.create_blueprint({ surface = surface, force = player.force, area = sel.area })
  Blueprint.tag(stack, mapping, surface)
  local entities = stack.get_blueprint_entities() or {}
  for index, entry in ipairs(entities) do
    if entry.name == C.station_settings then
      entry.control_behavior = nil -- leer: würde sonst die Antworten mit alten Werten überschreiben
    elseif station_of(mapping[index]) then
      entry.tags = entry.tags or {}
      entry.tags[ASK_TAG] = keys
    end
  end
  stack.set_blueprint_entities(entities)
  -- Vanilla-Parameter-Liste entfernen (sie stammt aus dem geleerten Kombinator) – sonst öffnet
  -- Factorio beim Platzieren zusätzlich sein leeres „Parametrisches Bauen“-Fenster.
  local json = helpers.decode_string(stack.export_stack():sub(2))
  local data = json and helpers.json_to_table(json) --[[@as table?]]
  if data and data.blueprint and data.blueprint.parameters then
    data.blueprint.parameters = nil
    stack.import_stack("0" .. helpers.encode_string(helpers.table_to_json(data)))
  end
  stack.label = "UTL-Parameter"
  player.add_to_clipboard(stack) -- wie Kopieren: später mit Strg + V wieder einfügen
  if not (player.cursor_stack and player.cursor_stack.valid_for_read) then player.activate_paste() end
  player.create_local_flying_text({ text = { "utl-param.made", #keys }, create_at_cursor = true })
end

-- Nach dem Platzieren die Blaupause aus der Hand nehmen (Wunsch Marcel: beim Ausfüllen nicht aus
-- Versehen noch einmal platzieren; Strg + V holt sie zurück). Erst im nächsten Herzschlag, damit
-- alle Geister der Blaupause stehen; ohne Auftrag kostet die Aufgabe nur ein next().
local function clear_hands()
  local list = storage.param_planner and storage.param_planner.clear
  if not (list and next(list)) then return end
  for index in pairs(list) do
    local player = game.get_player(index)
    local stack = player and player.cursor_stack
    if player and ((stack and stack.valid_for_read and stack.is_blueprint) or player.cursor_record) then
      player.clear_cursor()
    end
  end
  storage.param_planner.clear = {}
end
Heartbeat.add_task("param-clear-hands", 1, clear_hands)

local function clear_later(player)
  local p = pending()
  p.clear = p.clear or {}
  p.clear[player.index] = true
end

-- 3. Geister mit Abfrage-Tag platziert
local ghost_filter = {
  { filter = "ghost_type", type = "train-stop" },
  { filter = "ghost_name", name = C.station_combinator },
}
local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.type == "entity-ghost") then return end
  local tags = entity.tags
  local keys = tags and tags[ASK_TAG]
  if not keys then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local list = pending().ask[player.index]
  if not list or list.tick ~= game.tick then
    list = { tick = game.tick, keys = keys, entries = {}, cfg = util.table.deepcopy(tags.utl or {}) }
    pending().ask[player.index] = list
  end
  list.entries[#list.entries + 1] = { ghost = entity, surface = entity.surface.index, position = entity.position,
    name = entity.ghost_name }
  Windows.ask(player, keys, tags.utl or {}, #list.entries)
  clear_later(player)
end
Events.on(defines.events.on_built_entity, on_built, ghost_filter)

-- 4. Antworten übernehmen
local function apply(player)
  local list = pending().ask[player.index]
  local answers = Windows.answers(player)
  Windows.close(player, Windows.ASK)
  pending().ask[player.index] = nil
  if not list then return end
  for _, e in ipairs(list.entries) do
    local ghost = e.ghost
    if ghost and ghost.valid then
      local tags = ghost.tags or {}
      local cfg = util.table.deepcopy(tags.utl or {})
      Ask.apply(cfg, answers)
      tags.utl = cfg
      tags[ASK_TAG] = nil
      ghost.tags = tags
    else
      -- schon gebaut (z. B. Creative Mod): die Station direkt ändern
      local surface = game.get_surface(e.surface)
      local built = surface and surface.find_entities_filtered({ position = e.position, radius = 0.5, name = e.name })[1]
      local station = station_of(built)
      if station then
        local cfg = util.table.deepcopy(station.config)
        Ask.apply(cfg, answers)
        Paste.apply(station, cfg)
      end
    end
  end
  player.create_local_flying_text({ text = { "utl-param.applied", #list.entries }, create_at_cursor = true })
end

-- Rolle im Abfrage-Fenster gewechselt: nur die dazu passenden Felder zeigen, Eingaben behalten
Events.on(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.utl_param == "role") then return end
  local player = game.get_player(event.player_index)
  local list = player and pending().ask[player.index]
  if not (player and list) then return end
  local cfg = util.table.deepcopy(list.cfg)
  Ask.apply(cfg, Windows.answers(player))
  Windows.ask(player, list.keys, cfg, #list.entries)
end)

Events.on(defines.events.on_gui_click, function(event)
  local element = event.element
  local action = element and element.valid and element.tags and element.tags.utl_param
  if not action then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  if action == "make" then
    make(player)
  elseif action == "apply" then
    apply(player)
  elseif action == "close" then
    Windows.close(player, element.tags.window --[[@as string]])
  end
end)
