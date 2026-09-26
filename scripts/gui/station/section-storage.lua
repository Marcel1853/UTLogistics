--- Abschnitt „Lager“ (nur im Modus Lager): je Ware Mindest- und Höchstbestand, darunter das Häkchen
--- „Restladung annehmen“. Unter Mindest fordert das Lager an (bis Höchst), über Mindest bietet es an.
local Fields = require("scripts.stations.fields")
local Roles = require("scripts.stations.roles")

local Section = {}

local function number_field(parent, value, action, slot, tooltip)
  local field = parent.add({
    type = "textfield", text = value and tostring(value) or "", numeric = true, allow_decimal = false,
    lose_focus_on_confirm = true, clear_and_focus_on_right_click = true, tooltip = tooltip,
    tags = { utl_action = action, slot = slot },
  })
  field.style.width = 80
  return field
end

function Section.build(parent, station)
  local cfg = station.config
  if cfg.mode ~= "storage" then return nil end
  local st = cfg.storage
  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.section-storage" },
    tooltip = { "utl-gui.section-storage-tooltip" } })
  local frame = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  frame.style.padding = 6
  -- Abstand nur an einem Flow erlaubt, nicht am Frame
  local inner = frame.add({ type = "flow", direction = "vertical" })
  inner.style.vertical_spacing = 4

  local grid = inner.add({ type = "table", column_count = 3 })
  grid.style.horizontal_spacing = 8
  grid.style.vertical_spacing = 2
  grid.style.vertical_align = "center"
  grid.add({ type = "label", caption = { "utl-gui.storage-good" } })
  grid.add({ type = "label", caption = { "utl-gui.storage-min" }, tooltip = { "utl-gui.storage-min-tooltip" } })
  grid.add({ type = "label", caption = { "utl-gui.storage-max" }, tooltip = { "utl-gui.storage-max-tooltip" } })
  for slot = 1, Fields.storage_slots do
    local limit = st.limits[slot] or {}
    grid.add({
      type = "choose-elem-button", style = "slot_button", elem_type = "signal", signal = limit.signal,
      elem_filters = { { filter = "type", type = "item" }, { filter = "type", type = "fluid" } },
      tooltip = { "utl-gui.storage-good-tooltip" }, tags = { utl_action = "storage_signal", slot = slot },
    })
    number_field(grid, limit.min, "storage_min", slot, { "utl-gui.storage-min-tooltip" })
    number_field(grid, limit.max, "storage_max", slot, { "utl-gui.storage-max-tooltip" })
  end
  inner.add({
    type = "checkbox", caption = { "utl-gui.storage-leftover" }, state = st.accept_leftover == true,
    tooltip = { "utl-gui.storage-leftover-tooltip" }, tags = { utl_action = "storage_leftover" },
  })
  return true
end

--- Ware eines Slots gewählt oder geleert (nil).
function Section.set_signal(cfg, slot, signal)
  local limits = cfg.storage.limits
  if signal and (signal.type == "item" or signal.type == "fluid") then
    local limit = limits[slot] or { min = 0, max = 0 }
    limit.signal = signal
    limits[slot] = limit
  else
    limits[slot] = nil
  end
end

--- Mindest oder Höchst eines Slots (Text aus dem Feld). Liefert true bei gültiger Zahl.
function Section.set_number(cfg, action, slot, text)
  local value = tonumber(text)
  if not value then return false end
  local limit = cfg.storage.limits[slot]
  if not limit then return false end
  value = math.max(0, math.floor(value))
  if action == "storage_min" then limit.min = value else limit.max = value end
  return true
end

function Section.set_leftover(cfg, state)
  cfg.storage.accept_leftover = state
  Roles.derive(cfg)
end

return Section
