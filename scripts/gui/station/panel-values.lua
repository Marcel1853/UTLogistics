--- Rechter Kasten (wie LTN Combinator): Abschnitte „Allgemein“, „Anbieter“, „Abnehmer“,
--- „Depot“. Jede Zeile: Reset-Knopf | Symbol | Beschriftung | … | Zahlenfeld.
local Fields = require("scripts.stations.fields")
local Util = require("scripts.lib.util")

local Values = {}

local function add_row(grid, cfg, field)
  local value = cfg[field.key]
  local is_default = value == Fields.default(field)
  local tooltip = { "utl-gui.value-" .. field.key .. "-tooltip" }

  grid.add({
    type = "sprite-button",
    style = "utl_reset_button",
    sprite = "utility/reset",
    tooltip = { "utl-gui.reset-tooltip" },
    enabled = not is_default,
    mouse_button_filter = { "left" },
    tags = { utl_action = "reset", key = field.key },
  })
  grid.add({ type = "sprite", style = "utl_entry_sprite", sprite = "virtual-signal/" .. field.signal, tooltip = tooltip })
  grid.add({ type = "label", style = "utl_entry_label", caption = { "utl-gui.value-" .. field.key }, tooltip = tooltip })
  grid.add({
    type = "textfield",
    style = "utl_entry_text",
    text = tostring(value),
    -- nicht numeric: Rechenausdrücke wie „4000*2“ erlaubt (Util.parse_number)
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    tooltip = tooltip,
    tags = { utl_action = "value", key = field.key },
  })
end

function Values.build(parent, station)
  local cfg = station.config
  for _, group in ipairs(Fields.groups) do
    if group.visible(cfg) then
      local flow = parent.add({ type = "flow", direction = "vertical" })
      flow.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.section-" .. group.name } })
      local frame = flow.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
      frame.style.padding = 6
      local grid = frame.add({ type = "table", column_count = 4 })
      grid.style.cell_padding = 2
      grid.style.column_alignments[1] = "center"
      for _, field in ipairs(group.fields) do add_row(grid, cfg, field) end
    end
  end
end

--- Neuen Wert übernehmen. Liefert true bei Änderung.
function Values.apply(cfg, key, text)
  local field = Fields.by_key[key]
  local value = field and Util.parse_number(text)
  if not value then return false end
  cfg[key] = Fields.clamp(field, value)
  return true
end

function Values.reset(cfg, key)
  local field = Fields.by_key[key]
  if not field then return false end
  cfg[key] = Fields.default(field)
  return true
end

return Values
