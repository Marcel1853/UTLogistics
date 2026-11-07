--- Reiter „Inventar“ (wie LTN Manager): links alle angebotenen, angeforderten und unterwegs
--- befindlichen Waren im Netz; Klick auf eine Ware zeigt rechts, wo sie liegt und wohin sie fährt.
local Widgets = require("scripts.gui.common.widgets")
local List = require("scripts.gui.common.list")
local Section = require("scripts.gui.common.section")
local flib_format = require("__flib__.format")
local Filter = require("scripts.gui.manager.surface-filter")

local Tab = {}

local ROWS = { provide = 4, request = 3, incoming = 3 }

function Tab.build(parent)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontal_spacing = 8
  flow.style.vertically_stretchable = true

  -- links je ein Kasten für Angeboten, Angefordert und Unterwegs; Spaltenzahl wächst mit dem Fenster
  local columns = math.max(8, math.floor(List.w(440) / 40))
  local left = flow.add({ type = "flow", direction = "vertical" })
  left.style.vertical_spacing = 8
  -- feste Breite (Raster + Innenabstand + Rahmen): sonst verschiebt ein langer Stationsname rechts
  -- je nach gewählter Ware die Trennlinie zwischen links und rechts
  left.style.width = columns * 40 + 24
  left.style.vertically_stretchable = true
  local refs = {}
  for _, part in ipairs({ "provide", "request", "incoming" }) do
    local frame, _, body = Section.add(left, { "utl-manager.inventory-" .. part })
    body.style.padding = 8
    refs[part] = Widgets.slot_grid(body, columns, ROWS[part])
    if part == "incoming" then frame.style.vertically_stretchable = true end
  end

  -- rechts ein Kasten mit der gewählten Ware in der Kopfleiste
  local right = flow.add({ type = "frame", style = "inside_shallow_frame", direction = "vertical" })
  right.style.horizontally_stretchable = true
  right.style.horizontally_squashable = true
  right.style.vertically_stretchable = true
  local head = right.add({ type = "frame", style = "subheader_frame" })
  head.style.horizontally_stretchable = true
  refs.title = head.add({ type = "flow", direction = "horizontal" })
  refs.title.style.vertical_align = "center"
  refs.title.style.horizontal_spacing = 6
  local scroll = right.add({ type = "scroll-pane", style = "flib_naked_scroll_pane_no_padding",
    horizontal_scroll_policy = "never" })
  scroll.style.vertically_stretchable = true
  scroll.style.horizontally_stretchable = true
  refs.detail = scroll.add({ type = "flow", direction = "vertical" })
  -- rechts mehr Abstand, damit die Zahlen nicht am Scrollbalken kleben
  refs.detail.style.padding = { 8, 16, 12, 12 }
  refs.detail.style.vertical_spacing = 6
  refs.detail.style.horizontally_stretchable = true
  return refs
end

local function add(map, key, amount)
  map[key] = (map[key] or 0) + amount
end

--- Liste in einem dunklen Rahmen, jede Zeile als helle Box (wie die Tabellen der anderen Reiter).
local function box_list(parent, caption)
  parent.add({ type = "label", style = "utl_header_label", caption = caption })
  local frame = parent.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  frame.style.horizontally_stretchable = true
  frame.style.padding = 4
  return frame
end

local function box_row(list)
  local box = list.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame" })
  box.style.horizontally_stretchable = true
  box.style.padding = 4
  local row = box.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.style.horizontal_spacing = 8
  return row
end

local function pusher(row)
  row.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
end

--- Rechte Seite: Summen, Stationen mit dieser Ware und Züge unterwegs.
local function detail(refs, key, totals, manager)
  local parent, title = refs.detail, refs.title
  parent.clear()
  title.clear()
  if not key then
    title.add({ type = "label", style = "subheader_caption_label", caption = { "utl-manager.select-ware" } })
    return
  end
  local kind, name = key:match("^([^|]+)|(.+)|")
  local icon = title.add({ type = "sprite", sprite = kind .. "/" .. name })
  icon.style.size = 24
  icon.style.stretch_image_to_widget_size = true
  title.add({ type = "label", style = "subheader_caption_label", caption = Widgets.ware_name(key) })

  -- Summen: Name links, Zahl rechtsbündig, feine Linien dazwischen
  local sums = parent.add({ type = "table", column_count = 2 })
  sums.draw_horizontal_lines = true
  sums.style.horizontally_stretchable = true
  sums.style.vertical_spacing = 6
  sums.style.column_alignments[2] = "right"
  for _, part in ipairs({ "provide", "request", "incoming" }) do
    local label = sums.add({ type = "label", style = "bold_label", caption = { "utl-manager.inventory-" .. part } })
    label.style.horizontally_stretchable = true
    sums.add({ type = "label", caption = flib_format.number(totals[part][key] or 0) })
  end

  local stations
  for _, station in pairs(storage.stations.by_unit) do
    local provide, request = station.provide[key], station.request[key]
    if (provide or request) and station.stop and station.stop.valid
      and Filter.station(manager, station) then
      stations = stations or box_list(parent, { "utl-manager.col-station" })
      local row = box_row(stations)
      -- zu lange Namen werden gekürzt statt die rechte Seite zu verbreitern
      List.station_label(row, nil, station.stop.backer_name, station.stop).style.horizontally_squashable = true
      pusher(row)
      local grid = Widgets.slot_grid(row, 1)
      if provide then Widgets.add_slot(grid, key, provide, "provide") end
      if request then Widgets.add_slot(grid, key, request, "request") end
    end
  end

  local trains
  for _, delivery in pairs(storage.deliveries.active) do
    local amount = delivery.manifest[key]
    local front = delivery.train and delivery.train.valid and delivery.train.front_stock
    if amount and front and Filter.match(manager, front.surface_index, front.force_index) then
      trains = trains or box_list(parent, { "utl-manager.col-trains" })
      local row = box_row(trains)
      row.add({ type = "label", caption = { "utl-manager.route", delivery.from or "?", delivery.to or "?" } })
        .style.horizontally_squashable = true
      pusher(row)
      Widgets.add_slot(Widgets.slot_grid(row, 1), key, amount, "incoming")
    end
  end
end

function Tab.refresh(refs, manager)
  local totals = { provide = {}, request = {}, incoming = {} }
  local stations = storage.stations.by_unit
  for _, station in pairs(stations) do
    if Filter.station(manager, station) then
      for key, amount in pairs(station.provide) do add(totals.provide, key, amount) end
      for key, amount in pairs(station.request) do add(totals.request, key, amount) end
    end
  end
  for unit, by_key in pairs(storage.deliveries.incoming) do
    local station = stations[unit]
    if station and Filter.station(manager, station) then
      for key, amount in pairs(by_key) do add(totals.incoming, key, amount) end
    end
  end
  -- Waren-Filter: nur diese Ware zeigen und ihr Detail gleich öffnen (erste passende Qualität)
  if manager.ware_filter and not (manager.ware and Filter.ware_key(manager, manager.ware)) then
    manager.ware = nil
    for _, part in ipairs({ "provide", "request", "incoming" }) do
      for key in pairs(totals[part]) do
        if not manager.ware and Filter.ware_key(manager, key) then manager.ware = key end
      end
    end
  end
  for part, map in pairs(totals) do
    local grid = refs[part]
    grid.clear()
    for key, amount in pairs(map) do
      if Filter.ware_key(manager, key) then
        local button = Widgets.add_slot(grid, key, amount, part, nil, { utl_mgr = "ware", key = key })
        if button and key == manager.ware then button.toggled = true end
      end
    end
  end
  detail(refs, manager.ware, totals, manager)
end

return Tab
