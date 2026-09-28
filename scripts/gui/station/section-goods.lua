--- Live-Anzeige (wie „Provided / requested“ bei LTN Manager): was die Station gerade
--- anbietet (grün) und braucht (rot) – nach Schwellen und Anforderungen – und was gerade
--- unterwegs ist: kommt per Zug (blau) bzw. ist für einen Zug reserviert (gelb).
local Widgets = require("scripts.gui.common.widgets")

local Goods = {}

local COLUMNS = 10

--- Nur für Stationen, die anbieten oder anfordern können (Station, Cleanup mit „Inhalt wieder
--- anbieten“), sonst nil.
function Goods.build(parent, station)
  local roles = station.config.roles
  if station.config.mode ~= "station" and not roles.provider then return nil end
  local refs = {}
  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.goods" } })
  refs.grid = Widgets.slot_grid(parent, COLUMNS)
  refs.transit_label = parent.add({ type = "label", style = "utl_header_label" })
  refs.transit = Widgets.slot_grid(parent, COLUMNS)
  return refs
end

function Goods.refresh(refs, station)
  if not refs then return end
  refs.grid.clear()
  Widgets.add_slots(refs.grid, station.provide, "provide", "utl-gui.goods-provide")
  Widgets.add_slots(refs.grid, station.request, "request", "utl-gui.goods-request")

  local deliveries = storage.deliveries
  local unit = station.unit
  refs.transit.clear()
  Widgets.add_slots(refs.transit, deliveries.incoming[unit], "incoming", "utl-gui.transit-incoming")
  Widgets.add_slots(refs.transit, deliveries.outgoing[unit], "outgoing", "utl-gui.transit-outgoing")
  refs.transit_label.caption = { "utl-gui.transit", deliveries.trains_at[unit] or 0 }
end

return Goods
