--- Reiter „Inventar“ (wie LTN Manager): links alle angebotenen, angeforderten und unterwegs
--- befindlichen Waren im Netz; Klick auf eine Ware zeigt rechts, wo sie liegt und wohin sie fährt.
local Widgets = require("scripts.gui.common.widgets")
local List = require("scripts.gui.common.list")
local flib_format = require("__flib__.format")
local Filter = require("scripts.gui.manager.surface-filter")

local Tab = {}

local COLUMNS = 10

function Tab.build(parent)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontal_spacing = 8
  flow.style.vertically_stretchable = true

  local left = flow.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  left.style.vertically_stretchable = true
  local refs = {}
  for _, part in ipairs({ "provide", "request", "incoming" }) do
    left.add({ type = "label", style = "utl_header_label", caption = { "utl-manager.inventory-" .. part } })
    refs[part] = Widgets.slot_grid(left, COLUMNS, part == "provide" and 4 or 3)
  end

  local right = flow.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  right.style.horizontally_stretchable = true
  right.style.vertically_stretchable = true
  local scroll = right.add({ type = "scroll-pane", style = "flib_naked_scroll_pane_no_padding",
    horizontal_scroll_policy = "never" })
  scroll.style.vertically_stretchable = true
  refs.detail = scroll.add({ type = "flow", direction = "vertical" })
  refs.detail.style.vertical_spacing = 4
  return refs
end

--- Oberfläche einer Station (Haltestelle, sonst Combinator).
local function surface_of(station)
  local stop, entity = station.stop, station.entity
  if stop and stop.valid then return stop.surface_index end
  return entity and entity.valid and entity.surface_index or nil
end

local function add(map, key, amount)
  map[key] = (map[key] or 0) + amount
end

local function line(parent, caption, value)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.add({ type = "label", style = "bold_label", caption = caption })
  flow.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  flow.add({ type = "label", caption = flib_format.number(value) })
end

--- Rechte Seite: Summen, Stationen mit dieser Ware und Züge unterwegs.
local function detail(parent, key, totals, manager)
  parent.clear()
  if not key then
    parent.add({ type = "label", caption = { "utl-manager.select-ware" } })
    return
  end
  local kind, name = key:match("^([^|]+)|(.+)|")
  local head = parent.add({ type = "flow", direction = "horizontal" })
  head.style.vertical_align = "center"
  head.add({ type = "sprite", sprite = kind .. "/" .. name })
  head.add({ type = "label", style = "caption_label", caption = Widgets.ware_name(key) })
  line(parent, { "utl-manager.inventory-provide" }, totals.provide[key] or 0)
  line(parent, { "utl-manager.inventory-request" }, totals.request[key] or 0)
  line(parent, { "utl-manager.inventory-incoming" }, totals.incoming[key] or 0)

  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-manager.col-station" } })
  for _, station in pairs(storage.stations.by_unit) do
    local provide, request = station.provide[key], station.request[key]
    if (provide or request) and station.stop and station.stop.valid
      and Filter.match(manager, station.stop.surface_index) then
      local row = parent.add({ type = "flow", direction = "horizontal" })
      row.style.vertical_align = "center"
      List.station_label(row, 200, station.stop.backer_name, station.stop)
      local grid = Widgets.slot_grid(row, 1)
      if provide then Widgets.add_slot(grid, key, provide, "provide") end
      if request then Widgets.add_slot(grid, key, request, "request") end
    end
  end

  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-manager.col-trains" } })
  for _, delivery in pairs(storage.deliveries.active) do
    local amount = delivery.manifest[key]
    local front = delivery.train and delivery.train.valid and delivery.train.front_stock
    if amount and front and Filter.match(manager, front.surface_index) then
      local row = parent.add({ type = "flow", direction = "horizontal" })
      row.style.vertical_align = "center"
      local route = row.add({ type = "label", caption = { "utl-manager.route", delivery.from or "?", delivery.to or "?" } })
      route.style.width = 200
      Widgets.add_slot(Widgets.slot_grid(row, 1), key, amount, "incoming")
    end
  end
end

function Tab.refresh(refs, manager)
  local totals = { provide = {}, request = {}, incoming = {} }
  local stations = storage.stations.by_unit
  for _, station in pairs(stations) do
    if Filter.match(manager, surface_of(station)) then
      for key, amount in pairs(station.provide) do add(totals.provide, key, amount) end
      for key, amount in pairs(station.request) do add(totals.request, key, amount) end
    end
  end
  for unit, by_key in pairs(storage.deliveries.incoming) do
    local station = stations[unit]
    if station and Filter.match(manager, surface_of(station)) then
      for key, amount in pairs(by_key) do add(totals.incoming, key, amount) end
    end
  end
  for part, map in pairs(totals) do
    local grid = refs[part]
    grid.clear()
    for key, amount in pairs(map) do
      local button = Widgets.add_slot(grid, key, amount, part, nil, { utl_mgr = "ware", key = key })
      if button and key == manager.ware then button.toggled = true end
    end
  end
  detail(refs.detail, manager.ware, totals, manager)
end

return Tab
