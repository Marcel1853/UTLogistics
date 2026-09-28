--- Reiter „Statistik“: links Durchsatz je Ware (letzte 10 min / letzte Stunde / je Minute), rechts
--- die Züge mit Lieferungen und Auslastung. Daten: scripts/deliveries/statistics.lua (nur beim Ende
--- einer Lieferung erfasst). Gefiltert wie die übrigen Reiter nach Oberfläche und eigenem Team.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Filter = require("scripts.gui.manager.surface-filter")
local Info = require("scripts.gui.manager.train-info")
local Networks = require("scripts.stations.networks")
local Statistics = require("scripts.deliveries.statistics")
local Deliveries = require("scripts.deliveries.deliveries")
local flib_format = require("__flib__.format")

local Tab = {}

local GOODS = {
  { caption = { "utl-manager.col-good" }, width = 170 },
  { caption = { "utl-manager.col-stat-ten" }, width = 70 },
  { caption = { "utl-manager.col-stat-hour" }, width = 70 },
  { caption = { "utl-manager.col-stat-minute" }, width = 70 },
}
local TRAINS = {
  { caption = { "utl-manager.col-train" }, width = 150 },
  { caption = { "utl-manager.col-stat-deliveries" }, width = 70 },
  { caption = { "utl-manager.col-stat-utilization" }, width = 150 },
}

function Tab.build(parent)
  local bar = parent.add({ type = "flow", direction = "horizontal" })
  bar.style.vertical_align = "center"
  local summary = bar.add({ type = "label" })
  bar.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  bar.add({
    type = "sprite-button", style = "tool_button_red", sprite = "utility/trash",
    tooltip = { "utl-manager.stat-reset" }, tags = { utl_mgr = "reset_statistics" },
  })
  local columns = parent.add({ type = "flow", direction = "horizontal" })
  columns.style.horizontal_spacing = 8
  columns.style.vertically_stretchable = true
  local left = columns.add({ type = "flow", direction = "vertical" })
  left.style.width = 430
  left.style.vertically_stretchable = true
  local right = columns.add({ type = "flow", direction = "vertical" })
  right.style.horizontally_stretchable = true
  right.style.vertically_stretchable = true
  return { summary = summary, goods = List.build(left, GOODS), trains = List.build(right, TRAINS) }
end

local function fill_good(row, item)
  local cell = List.cell(row, GOODS[1].width, { type = "flow", direction = "horizontal" })
  cell.style.vertical_align = "center"
  local grid = cell.add({ type = "table", style = "slot_table", column_count = 1 })
  Widgets.add_slot(grid, item.key, nil, "cargo")
  cell.add({ type = "label", caption = Widgets.ware_name(item.key) })
  List.cell(row, GOODS[2].width, { type = "label", caption = flib_format.number(item.ten) })
  List.cell(row, GOODS[3].width, { type = "label", caption = flib_format.number(item.hour) })
  List.cell(row, GOODS[4].width, { type = "label", caption = flib_format.number(math.floor(item.hour / 60 + 0.5)) })
end

local function fill_train(row, item)
  local train = item.train
  local name = List.cell(row, TRAINS[1].width, { type = "label",
    caption = { "", "#", tostring(train.id), "  ", Info.composition(train) } })
  name.style.font = "default-bold"
  List.cell(row, TRAINS[2].width, { type = "label", caption = tostring(item.deliveries) })
  local cell = List.cell(row, TRAINS[3].width, { type = "flow", direction = "horizontal" })
  cell.style.vertical_align = "center"
  local bar = cell.add({ type = "progressbar", value = item.utilization })
  bar.style.width = 90
  cell.add({ type = "label", caption = { "", tostring(math.floor(item.utilization * 100 + 0.5)), " %" } })
end

function Tab.refresh(refs, manager)
  local stats = Statistics.data()
  -- Waren aller passenden Orte zusammenzählen
  local goods, deliveries = {}, 0
  for place in pairs(stats.places) do
    local surface, force = Networks.split_place(place)
    if Filter.match(manager, surface, force) then
      local by_key, count = Statistics.goods(place)
      deliveries = deliveries + count
      for key, entry in pairs(by_key) do
        local sum = goods[key]
        if not sum then
          sum = { key = key, ten = 0, hour = 0 }
          goods[key] = sum
        end
        sum.ten, sum.hour = sum.ten + entry.ten, sum.hour + entry.hour
      end
    end
  end
  local search = manager.search
  local goods_list = {}
  for key, entry in pairs(goods) do
    if search == "" or string.find(key, search, 1, true) then goods_list[#goods_list + 1] = entry end
  end
  table.sort(goods_list, function(a, b)
    if a.hour ~= b.hour then return a.hour > b.hour end
    return a.key < b.key
  end)
  -- Züge: alle bekannten (schon einmal im Depot) des eigenen Teams auf der gewählten Oberfläche
  local trains = {}
  for id, home in pairs(storage.trains.home) do
    local train = home.train
    local front = train and train.valid and train.front_stock
    if front and Filter.match(manager, front.surface_index, front.force_index) then
      local delivery = Deliveries.of_train(id)
      local utilization, entry = Statistics.utilization(id, delivery and delivery.started)
      trains[#trains + 1] = { train = train, deliveries = entry and entry.deliveries or 0, utilization = utilization }
    end
  end
  table.sort(trains, function(a, b)
    if a.utilization ~= b.utilization then return a.utilization > b.utilization end
    return a.train.id < b.train.id
  end)
  refs.summary.caption = { "utl-manager.stat-summary", deliveries, Widgets.duration(game.tick - stats.since) }
  List.sync(refs.goods, goods_list, fill_good)
  List.sync(refs.trains, trains, fill_train)
end

return Tab
