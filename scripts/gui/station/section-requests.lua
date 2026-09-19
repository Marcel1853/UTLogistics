--- Anforderungs-Slots mit Mengen-Editor (wie „Output signals“ bei LTN Combinator):
--- Slot anklicken → Ware wählen → Menge in Stacks oder Stück eingeben → ✓.
--- Rechtsklick auf einen Slot leert ihn.
local Requests = require("scripts.stations.requests")
local Util = require("scripts.lib.util")
local flib_format = require("__flib__.format")

local Section = {}

local COLUMNS = 10
local FLUID_DEFAULT = 1000

local function count_caption(count)
  return count and flib_format.number(count, true) or ""
end

function Section.build(parent, station)
  local cfg = station.config
  local refs = { slots = {} }

  -- Mengen-Editor: Stacks | Stück | ✓ | ✗ (aktiv, sobald ein Slot gewählt ist)
  local editor = parent.add({ type = "flow", style = "flib_indicator_flow" })
  editor.style.top_margin = 4
  editor.visible = false
  refs.editor = editor
  editor.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  editor.add({ type = "label", caption = { "utl-gui.label-stacks" } })
  refs.stacks = editor.add({
    type = "textfield", style = "utl_entry_text", -- nicht numeric: Rechnen wie „2*4“ erlaubt
    lose_focus_on_confirm = true, clear_and_focus_on_right_click = true,
    tags = { utl_action = "req_stacks" },
  })
  editor.add({ type = "label", caption = { "utl-gui.label-items" } })
  refs.items = editor.add({
    type = "textfield", style = "utl_entry_text",
    lose_focus_on_confirm = true, clear_and_focus_on_right_click = true,
    tags = { utl_action = "req_items" },
  })
  refs.confirm = editor.add({
    type = "sprite-button", style = "utl_confirm_button", sprite = "utility/check_mark",
    tooltip = { "utl-gui.confirm-tooltip" }, mouse_button_filter = { "left" },
    tags = { utl_action = "req_confirm" },
  })
  refs.cancel = editor.add({
    type = "sprite-button", style = "utl_cancel_button", sprite = "utility/reset",
    tooltip = { "utl-gui.cancel-tooltip" }, mouse_button_filter = { "left" },
    tags = { utl_action = "req_cancel" },
  })

  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.requests" },
    tooltip = { "utl-gui.requests-tooltip" } })
  local frame = parent.add({ type = "frame", style = "slot_button_deep_frame", direction = "vertical" })
  local grid = frame.add({ type = "table", style = "slot_table", column_count = COLUMNS })
  for slot = 1, Requests.slot_count do
    local request = cfg.requests[slot]
    local button = grid.add({
      type = "choose-elem-button",
      style = "flib_slot_button_default",
      elem_type = "signal",
      signal = request and request.signal or nil,
      tooltip = { "utl-gui.request-slot-tooltip" },
      tags = { utl_action = "req_slot", slot = slot },
    })
    button.locked = request ~= nil -- gefüllte Slots: Klick wählt zum Bearbeiten statt Auswahlfenster
    button.add({ type = "label", style = "utl_slot_count", ignored_by_interaction = true,
      caption = count_caption(request and request.count) })
    refs.slots[slot] = button
  end
  return refs
end

--- Editor für einen Slot öffnen (oder mit nil schließen).
function Section.select(refs, cfg, slot)
  refs.edit_slot = slot
  local request = slot and cfg.requests[slot]
  refs.editor.visible = request ~= nil
  if not request then
    refs.stacks.text, refs.items.text = "", ""
    return
  end
  local key = Util.signal_key(request.signal)
  local size = key and Util.stack_size(key)
  refs.items.text = tostring(request.count)
  refs.stacks.text = size and tostring(math.floor(request.count / size * 10 + 0.5) / 10) or ""
  refs.stacks.enabled = size ~= nil
  refs.items.focus()
  refs.items.select_all()
end

--- Stacks ↔ Stück beim Tippen gegenseitig umrechnen (auch Rechenausdrücke).
function Section.sync(refs, cfg, from)
  local request = refs.edit_slot and cfg.requests[refs.edit_slot]
  local key = request and Util.signal_key(request.signal)
  local size = key and Util.stack_size(key)
  if not size then return end
  if from == "req_stacks" then
    local stacks = Util.parse_number(refs.stacks.text)
    if stacks then refs.items.text = tostring(math.floor(stacks * size + 0.5)) end
  else
    local items = Util.parse_number(refs.items.text)
    if items then refs.stacks.text = tostring(math.floor(items / size * 10 + 0.5) / 10) end
  end
end

--- Neue Ware in einem Slot gewählt oder geleert.
function Section.on_elem_changed(refs, cfg, slot, signal)
  if not signal or signal.type == "virtual" then
    Requests.set(cfg, slot, nil)
    Section.refresh_slot(refs, cfg, slot)
    Section.select(refs, cfg, nil)
    return
  end
  local key = Util.signal_key(signal)
  local count = key and (Util.stack_size(key) or FLUID_DEFAULT) or FLUID_DEFAULT
  Requests.set(cfg, slot, signal, count)
  Section.refresh_slot(refs, cfg, slot)
  Section.select(refs, cfg, slot)
end

--- Menge aus dem Editor übernehmen. 0 oder leer = Slot leeren.
function Section.confirm(refs, cfg)
  local slot = refs.edit_slot
  local request = slot and cfg.requests[slot]
  if not request then return false end
  local count = math.floor(Util.parse_number(refs.items.text) or 0)
  if count > 0 then
    Requests.set(cfg, slot, request.signal, count)
  else
    Requests.set(cfg, slot, nil)
  end
  Section.refresh_slot(refs, cfg, slot)
  Section.select(refs, cfg, nil)
  return true
end

function Section.clear(refs, cfg, slot)
  Requests.set(cfg, slot, nil)
  Section.refresh_slot(refs, cfg, slot)
  if refs.edit_slot == slot then Section.select(refs, cfg, nil) end
end

function Section.refresh_slot(refs, cfg, slot)
  local button = refs.slots[slot]
  local request = cfg.requests[slot]
  button.locked = false
  button.elem_value = request and request.signal or nil
  button.locked = request ~= nil
  button.children[1].caption = count_caption(request and request.count)
end

return Section
