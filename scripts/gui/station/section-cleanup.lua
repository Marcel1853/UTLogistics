--- Abschnitt „Cleanup“ im rechten Kasten (nur mit Rolle Cleanup): was hier geleert werden darf.
--- Zwei Schalter „Alle Items“/„Alle Flüssigkeiten“ und Slots für einzelne Items und Flüssigkeiten.
--- Ausdrücklich eingetragene Waren haben Vorrang vor den Schaltern (siehe cleanup-route.lua).
local Fields = require("scripts.stations.fields")

local Cleanup = {}

local function toggle(parent, cleanup, key, signal)
  local on = cleanup[key] == true
  parent.add({
    type = "sprite-button",
    style = "slot_button",
    sprite = "virtual-signal/" .. signal,
    toggled = on,
    tooltip = { "utl-gui.cleanup-" .. key .. "-tooltip", { on and "utl-gui.on" or "utl-gui.off" } },
    mouse_button_filter = { "left" },
    tags = { utl_action = "cleanup_all", key = key },
  })
end

local function slots(parent, list, count, elem_type, action)
  local grid = parent.add({ type = "table", column_count = 10 })
  grid.style.horizontal_spacing = 0
  grid.style.vertical_spacing = 0
  for slot = 1, count do
    grid.add({
      type = "choose-elem-button",
      style = "slot_button",
      elem_type = elem_type,
      [elem_type] = list[slot],
      tooltip = { "utl-gui.cleanup-slot-tooltip" },
      tags = { utl_action = action, slot = slot },
    })
  end
end

function Cleanup.build(parent, station)
  local cfg = station.config
  if not cfg.roles.cleanup then return end
  local cleanup = cfg.cleanup
  local flow = parent.add({ type = "flow", direction = "vertical" })
  flow.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.section-cleanup" },
    tooltip = { "utl-gui.section-cleanup-tooltip" } })
  local frame = flow.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  frame.style.padding = 6
  -- Abstand nur an einem Flow erlaubt, nicht am Frame
  local inner = frame.add({ type = "flow", direction = "vertical" })
  inner.style.vertical_spacing = 4
  local row = inner.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  toggle(row, cleanup, "all_items", "utl-cleanup-all-items")
  toggle(row, cleanup, "all_fluids", "utl-cleanup-all-fluids")
  row.add({ type = "label", caption = { "utl-gui.cleanup-or-single" } })
  slots(inner, cleanup.items, Fields.cleanup_item_slots, "item", "cleanup_item")
  slots(inner, cleanup.fluids, Fields.cleanup_fluid_slots, "fluid", "cleanup_fluid")
end

--- Schalter umlegen.
function Cleanup.toggle(cfg, key)
  if key ~= "all_items" and key ~= "all_fluids" then return false end
  cfg.cleanup[key] = not cfg.cleanup[key]
  return true
end

--- Slot geändert (nil = geleert).
function Cleanup.set(cfg, action, slot, value)
  local list = action == "cleanup_item" and cfg.cleanup.items or cfg.cleanup.fluids
  list[slot] = value
end

return Cleanup
