--- Fenster am Wende-Greifarm: hängt rechts am Vanilla-Greifarmfenster (relatives GUI), damit die
--- normale Schaltungs-Einstellung sichtbar bleibt. Einstellbar: Signal, Vergleich, Zahl, welche
--- Kabel gelesen werden. Darunter steht, wie er gerade arbeitet.
local C = require("scripts.core.constants")
local Reversible = require("scripts.inserters.reversible")

local Window = {}

local NAME = "utl_rev_panel"
local TAG = "utl_rev"

local function frame_of(player)
  local frame = player.gui.relative[NAME]
  return frame and frame.valid and frame or nil
end

function Window.close(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

--- Statuszeile: wie gebaut / umgedreht, dazu der gelesene Wert.
local function status_caption(entry)
  return { entry.flipped and "utl-rev.status-flipped" or "utl-rev.status-normal", Reversible.value(entry) }
end

function Window.open(player, entity)
  Window.close(player)
  local entry = Reversible.get(entity.unit_number) or Reversible.add(entity)
  if not entry then return end
  local cfg, unit = entry.cfg, entity.unit_number
  local frame = player.gui.relative.add({
    type = "frame", name = NAME, direction = "vertical", caption = { "utl-rev.title" },
    anchor = { gui = defines.relative_gui_type.inserter_gui, position = defines.relative_gui_position.right,
      name = C.reversible_inserter },
  })
  local inner = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  -- Zeilenabstand gibt es nur bei Flows, nicht bei Frames
  local box = inner.add({ type = "flow", direction = "vertical" })
  box.style.vertical_spacing = 6
  local explain = box.add({ type = "label", caption = { "utl-rev.explain" } })
  explain.style.single_line = false
  explain.style.maximal_width = 260

  local row = box.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.add({ type = "choose-elem-button", elem_type = "signal", signal = cfg.signal, style = "slot_button",
    tooltip = { "utl-rev.signal-tooltip" }, tags = { [TAG] = "signal", unit = unit } })
  local items, selected = {}, 1
  for i, comparator in ipairs(Reversible.COMPARATORS) do
    items[i] = comparator
    if comparator == cfg.comparator then selected = i end
  end
  row.add({ type = "drop-down", items = items, selected_index = selected, tags = { [TAG] = "comparator", unit = unit } })
  local number = row.add({ type = "textfield", text = tostring(cfg.constant or 0), numeric = true,
    allow_negative = true, lose_focus_on_confirm = true, tags = { [TAG] = "constant", unit = unit } })
  number.style.width = 80

  local wires = box.add({ type = "flow", direction = "horizontal" })
  wires.add({ type = "checkbox", caption = { "utl-rev.red" }, state = cfg.red ~= false, tags = { [TAG] = "red", unit = unit } })
  wires.add({ type = "checkbox", caption = { "utl-rev.green" }, state = cfg.green ~= false, tags = { [TAG] = "green", unit = unit } })

  local status = box.add({ type = "label", name = "status", caption = status_caption(entry) })
  status.style.font = "default-bold"
  storage.rev_open = storage.rev_open or {}
  storage.rev_open[player.index] = { unit = unit, status = status }
end

--- Offene Fenster: Statuszeile auffrischen (Heartbeat, selten).
function Window.refresh_open()
  for index, open in pairs(storage.rev_open or {}) do
    local entry = Reversible.get(open.unit)
    if entry and open.status.valid then
      open.status.caption = status_caption(entry)
    else
      storage.rev_open[index] = nil
    end
  end
end

--- Eine Einstellung aus dem Fenster übernehmen. Liefert true bei Änderung.
function Window.apply(element)
  local tags = element.tags
  local action = tags and tags[TAG]
  if not action then return false end
  local entry = Reversible.get(tags.unit)
  if not entry then return false end
  local cfg = entry.cfg
  if action == "signal" then
    cfg.signal = element.elem_value
  elseif action == "comparator" then
    cfg.comparator = Reversible.COMPARATORS[element.selected_index] or ">"
  elseif action == "constant" then
    local value = tonumber(element.text)
    if not value then return false end
    cfg.constant = math.floor(value)
  elseif action == "red" or action == "green" then
    cfg[action] = element.state
  else
    return false
  end
  Reversible.update(entry, game.tick)
  return true
end

return Window
