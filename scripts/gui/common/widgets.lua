--- Gemeinsame GUI-Bausteine: Slot-Raster mit Waren (wie LTN Manager) und Zeitangaben.
local Util = require("scripts.lib.util")
local flib_format = require("__flib__.format")

local Widgets = {}

--- Farben der Slots: Angebot, Bedarf, kommt per Zug, für Züge reserviert, Zugladung.
Widgets.colors = {
  provide = "flib_slot_button_green",
  request = "flib_slot_button_red",
  incoming = "flib_slot_button_blue",
  outgoing = "flib_slot_button_yellow",
  cargo = "flib_slot_button_default",
}

--- Name einer Ware (mit Qualität) für Tooltips.
function Widgets.ware_name(key)
  local kind, name, quality = Util.split_key(key)
  local proto = (kind == "fluid" and prototypes.fluid or prototypes.item)[name]
  local quality_part = quality ~= "normal" and { "", " (", { "quality-name." .. quality }, ")" } or ""
  return { "", proto and proto.localised_name or name, quality_part }
end

--- Rahmen mit Slot-Tabelle. `rows` = Mindesthöhe in Zeilen (leere Kästen wie bei LTN Manager).
function Widgets.slot_grid(parent, columns, rows)
  local frame = parent.add({ type = "frame", style = "slot_button_deep_frame" })
  frame.style.width = columns * 40
  frame.style.minimal_height = (rows or 1) * 40
  return frame.add({ type = "table", style = "slot_table", column_count = columns })
end

--- Ein Waren-Slot. `tooltip` = zusätzliche Zeile unter dem Namen; `tags` optional (klickbar).
function Widgets.add_slot(grid, key, count, color, tooltip, tags)
  local kind, name = Util.split_key(key)
  local sprite = kind .. "/" .. name
  if not helpers.is_valid_sprite_path(sprite) then return nil end
  local full_tooltip = tooltip and { "", Widgets.ware_name(key), "\n", tooltip } or Widgets.ware_name(key)
  return grid.add({
    type = "sprite-button",
    style = Widgets.colors[color] or color,
    sprite = sprite,
    number = count,
    tooltip = full_tooltip,
    tags = tags,
  })
end

--- Alle Waren einer Tabelle [key] = Menge als Slots.
function Widgets.add_slots(grid, map, color, tooltip_key)
  if not map then return end
  for key, count in pairs(map) do
    Widgets.add_slot(grid, key, count, color, tooltip_key and { tooltip_key, flib_format.number(count) })
  end
end

--- Dauer in Ticks als „[h:]mm:ss“.
function Widgets.duration(ticks)
  return flib_format.time(math.max(0, ticks))
end

return Widgets
