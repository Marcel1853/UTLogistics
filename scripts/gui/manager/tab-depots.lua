--- Reiter „Depots“ (wie LTN Manager): links die Depots (gleichnamige Haltestellen zusammengefasst)
--- mit freien/gesamten Zügen, rechts die Züge des gewählten Depots.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Info = require("scripts.gui.manager.train-info")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-composition" }, width = 110 },
  { caption = { "utl-manager.col-status" }, width = 220 },
  { caption = { "utl-manager.col-cargo" }, width = 160 },
}

function Tab.build(parent)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontal_spacing = 8
  flow.style.vertically_stretchable = true
  local left = flow.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  left.style.width = 230
  left.style.vertically_stretchable = true
  local list = left.add({ type = "list-box", tags = { utl_mgr = "depot_list" } })
  list.style.horizontally_stretchable = true
  list.style.vertically_stretchable = true
  local right = flow.add({ type = "flow", direction = "vertical" })
  right.style.horizontally_stretchable = true
  right.style.vertically_stretchable = true
  return { list = list, rows = List.build(right, COLUMNS), names = {} }
end

--- Depots nach Namen gruppiert, mit ihren Zügen (Heimat-Depot = zuletzt geparkt).
local function collect(search)
  local groups, order = {}, {}
  for _, station in pairs(storage.stations.by_unit) do
    local stop = station.stop
    if station.config.roles.depot and stop and stop.valid then
      local name = stop.backer_name
      if not groups[name] and (search == "" or string.find(string.lower(name), search, 1, true)) then
        groups[name] = { name = name, trains = {}, idle = 0 }
        order[#order + 1] = name
      end
    end
  end
  local home = storage.trains.home
  for id, entry in pairs(home) do
    if not entry.train.valid then
      home[id] = nil
    else
      local group = groups[entry.depot]
      if group then
        group.trains[#group.trains + 1] = entry.train
        if storage.trains.by_id[id] then group.idle = group.idle + 1 end
      end
    end
  end
  table.sort(order)
  return groups, order
end

local function fill(row, train)
  local composition = List.cell(row, COLUMNS[1].width, {
    type = "label",
    style = "clickable_label",
    caption = Info.composition(train),
    tooltip = { "utl-manager.goto-train", train.id },
    tags = { utl_mgr = "follow", train_id = train.id },
  })
  composition.style.font = "default-bold"

  local heading, place = Info.status(train)
  local status = List.cell(row, COLUMNS[2].width, { type = "flow", direction = "vertical" })
  status.style.vertical_spacing = 0
  status.add({ type = "label", caption = heading })
  if place then List.station_label(status, COLUMNS[2].width, place, nil) end

  local cargo, planned = Info.cargo(train)
  local grid = Widgets.slot_grid(row, 4)
  Widgets.add_slots(grid, cargo, planned and "outgoing" or "cargo", planned and "utl-manager.cargo-planned" or nil)
end

function Tab.refresh(refs, manager)
  local groups, order = collect(manager.search)
  local list = refs.list
  local items = {}
  for i, name in ipairs(order) do
    local group = groups[name]
    items[i] = { "utl-manager.depot-entry", name, group.idle, #group.trains }
  end
  list.items = items
  refs.names = order
  if #order == 0 then
    manager.depot = nil
  elseif not groups[manager.depot or ""] then
    manager.depot = order[1]
  end
  for i, name in ipairs(order) do
    if name == manager.depot then list.selected_index = i end
  end

  local trains = manager.depot and groups[manager.depot].trains or {}
  table.sort(trains, function(a, b) return a.id < b.id end)
  List.sync(refs.rows, trains, fill)
end

--- Auswahl in der linken Liste.
function Tab.select(refs, manager, index)
  manager.depot = refs.names[index]
end

return Tab
