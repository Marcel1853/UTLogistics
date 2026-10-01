--- Fenster des Netz-Kombinators (ersetzt das Vanilla-Fenster des Konstant-Kombinators), im Stil
--- des Stations-Combinator-Fensters: links Status, Vorschau, Netz, Modus; rechts die Signale, die
--- er gerade ausgibt.
local Builder = require("scripts.gui.common.builder")
local Widgets = require("scripts.gui.common.widgets")
local Util = require("scripts.lib.util")
local Networks = require("scripts.stations.networks")
local Readouts = require("scripts.readout.readouts")
local Output = require("scripts.readout.output")

local Window = {}

local NAME = "utl_readout_window"
-- Bei jedem Umbau des Fensters erhöhen (offene Fenster alter Spielstände werden dann geschlossen).
local GUI_VERSION = 2
local COLUMNS = 10
local LEFT_WIDTH = 300

-- Farbe der Slots je Modus (wie im Stationsfenster: grün Angebot, rot Bedarf)
local SLOT_COLOR = { stock = "provide", storage = "cargo", demand = "request", shortage = "request", trains = "cargo" }

local function guis()
  storage.readout_guis = storage.readout_guis or {}
  return storage.readout_guis
end

function Window.is_window(element)
  return element and element.valid and element.name == NAME
end

function Window.close(player_index)
  local gui = guis()[player_index]
  guis()[player_index] = nil
  if gui and gui.frame and gui.frame.valid then gui.frame.destroy() end
end

function Window.get(player_index)
  local gui = guis()[player_index]
  if gui and gui.version == GUI_VERSION then return gui end
  return nil
end

--- Eintrag des Kombinators im offenen Fenster.
function Window.entry_of(player_index)
  local gui = Window.get(player_index)
  return gui and Readouts.get(gui.unit)
end

local function network_items(current)
  local items, selected = {}, 1
  for i, name in ipairs(Networks.known()) do
    items[i] = name
    if name == current then selected = i end
  end
  if items[selected] ~= current then
    items[#items + 1] = current
    selected = #items
  end
  return items, selected
end

local function box(parent, width)
  local frame = parent.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  if width then frame.style.width = width end
  frame.style.vertically_stretchable = true
  local flow = frame.add({ type = "flow", direction = "vertical" })
  flow.style.vertical_spacing = 6
  return flow
end

function Window.open(player, entry)
  -- Neuaufbau desselben Kombinators (Modus gewechselt …): verschobene Position behalten
  local previous = guis()[player.index]
  local keep = previous and previous.unit == entry.unit and previous.frame and previous.frame.valid
    and previous.frame.location or nil
  Window.close(player.index)
  local old = player.gui.screen[NAME]
  if old then old.destroy() end
  local cfg = entry.config

  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical" })
  if keep then frame.location = keep else frame.auto_center = true end
  Builder.titlebar(frame, { "entity-name.utl-network-combinator" }, "readout_close")
  local boxes = frame.add({ type = "flow", direction = "horizontal" })
  boxes.style.horizontal_spacing = 12

  local left = box(boxes, LEFT_WIDTH)
  local refs = {}
  refs.status = Builder.status(left)
  local preview_frame = left.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame" })
  local preview = preview_frame.add({ type = "entity-preview" })
  preview.style.minimal_height = 96
  preview.style.horizontally_stretchable = true
  preview.entity = entry.entity

  Builder.heading(left, { "utl-gui.readout-network" })
  local items, selected = network_items(cfg.network)
  left.add({
    type = "drop-down", items = items, selected_index = selected,
    tooltip = { "utl-gui.readout-network-tooltip" }, tags = { utl_readout = "network" },
  }).style.horizontally_stretchable = true
  left.add({
    type = "checkbox", state = cfg.star, caption = { "utl-gui.readout-star" },
    tooltip = { "utl-gui.readout-star-tooltip" }, tags = { utl_readout = "star" },
  })

  Builder.heading(left, { "utl-gui.readout-mode" })
  for _, mode in ipairs(Readouts.MODES) do
    left.add({
      type = "radiobutton", state = cfg.mode == mode, caption = { "utl-gui.readout-mode-" .. mode },
      tooltip = { "utl-gui.readout-mode-" .. mode .. "-tooltip" }, tags = { utl_readout = "mode", mode = mode },
    })
  end
  left.add({
    type = "checkbox", state = cfg.transit, caption = { "utl-gui.readout-transit" },
    tooltip = { "utl-gui.readout-transit-tooltip" }, enabled = cfg.mode == "stock",
    tags = { utl_readout = "transit" },
  })

  local right = box(boxes, nil)
  Builder.heading(right, { "utl-gui.readout-output" })
  refs.grid = Widgets.slot_grid(right, COLUMNS, 6)
  refs.hint = right.add({ type = "label", style = "info_label", caption = { "utl-gui.readout-hint" } })
  refs.hint.style.single_line = false
  refs.hint.style.maximal_width = COLUMNS * 40

  player.opened = frame
  guis()[player.index] = { version = GUI_VERSION, frame = frame, unit = entry.unit, refs = refs }
  Window.refresh(player.index)
end

--- Slot für ein Signal (Ware oder eigenes UTL-Signal).
local function add_slot(grid, key, amount, color)
  local kind, name = Util.split_key(key)
  if kind == "virtual" then
    grid.add({
      type = "sprite-button", style = Widgets.colors[color], sprite = "virtual-signal/" .. name,
      number = amount, tooltip = { "virtual-signal-name." .. name },
    })
  else
    Widgets.add_slot(grid, key, amount, color)
  end
end

--- Status und Signal-Vorschau auffrischen; schließt das Fenster, wenn der Kombinator weg ist.
function Window.refresh(player_index)
  local gui = guis()[player_index]
  if not gui then return end
  local entry = Readouts.get(gui.unit)
  if gui.version ~= GUI_VERSION or not (entry and entry.entity.valid and gui.frame.valid) then
    Window.close(player_index)
    return
  end
  local values = entry.last or Output.compute(entry)
  local keys = {}
  for key in pairs(values) do keys[#keys + 1] = key end
  table.sort(keys)
  local grid = gui.refs.grid
  grid.clear()
  local color = SLOT_COLOR[entry.config.mode]
  for _, key in ipairs(keys) do add_slot(grid, key, values[key], color) end
  local network = entry.config.network
  if #keys == 0 then
    Builder.set_status(gui.refs.status, "yellow", { "utl-gui.readout-status-empty", network })
  else
    Builder.set_status(gui.refs.status, "green", { "utl-gui.readout-status-ok", #keys, network })
  end
end

--- Heartbeat-Aufgabe: nur offene Fenster auffrischen.
function Window.refresh_all()
  for player_index in pairs(guis()) do
    local player = game.get_player(player_index)
    if player and player.connected then Window.refresh(player_index) end
  end
end

return Window
