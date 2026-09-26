--- Abschnitt „Cleanup“ im rechten Kasten (nur mit Rolle Cleanup): was hier geleert werden darf.
--- Zwei Schalter „Alle Items“/„Alle Flüssigkeiten“ und Slots für einzelne Items und Flüssigkeiten.
--- Ausdrücklich eingetragene Waren haben Vorrang vor den Schaltern (siehe cleanup-route.lua).
--- Darunter: „Inhalt wieder anbieten“ mit Rang (Reserve / normal / zuerst leeren).
local Fields = require("scripts.stations.fields")
local Roles = require("scripts.stations.roles")

local Cleanup = {}

Cleanup.TIERS = { "reserve", "normal", "first" }

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

  -- Inhalt wieder anbieten (Kartenschalter kann es für alle abschalten)
  local allowed = storage.cfg.cleanup_offer
  local offer = inner.add({ type = "flow", direction = "horizontal" })
  offer.style.vertical_align = "center"
  offer.style.top_margin = 4
  offer.add({
    type = "checkbox",
    caption = { "utl-gui.cleanup-offer" },
    state = cleanup.offer ~= false,
    enabled = allowed,
    tooltip = { allowed and "utl-gui.cleanup-offer-tooltip" or "utl-gui.cleanup-offer-disabled" },
    tags = { utl_action = "cleanup_offer" },
  })
  local items, selected = {}, 1
  for i, tier in ipairs(Cleanup.TIERS) do
    items[i] = { "utl-gui.cleanup-offer-" .. tier }
    if tier == (cleanup.offer or cleanup.offer_tier) then selected = i end
  end
  offer.add({
    type = "drop-down",
    items = items,
    selected_index = selected,
    enabled = allowed and cleanup.offer ~= false,
    tooltip = { "utl-gui.cleanup-offer-tier-tooltip" },
    tags = { utl_action = "cleanup_offer_tier" },
  })
end

--- „Inhalt wieder anbieten“ an/aus. Der gewählte Rang bleibt beim Ausschalten gemerkt.
function Cleanup.set_offer(cfg, on)
  local cleanup = cfg.cleanup
  if cleanup.offer then cleanup.offer_tier = cleanup.offer end
  cleanup.offer = on and (cleanup.offer_tier or "reserve") or false
  Roles.derive(cfg)
end

--- Rang gewählt (Index in Cleanup.TIERS).
function Cleanup.set_tier(cfg, index)
  local tier = Cleanup.TIERS[index]
  if not tier then return false end
  cfg.cleanup.offer_tier = tier
  if cfg.cleanup.offer then cfg.cleanup.offer = tier end
  return true
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
