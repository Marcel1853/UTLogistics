--- Reiter „Netzwerke“: links alle Netzwerke der Karte mit freien Zügen und laufenden Lieferungen,
--- rechts die Stationen des gewählten Netzes – und ob sie darin ihr Heimatnetz haben oder nur als
--- Zusatznetz mitarbeiten.
local List = require("scripts.gui.common.list")
local Networks = require("scripts.stations.networks")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-station" }, width = 260 },
  { caption = { "utl-manager.col-role" }, width = 220 },
  { caption = { "utl-manager.col-membership" }, width = 140 },
}

local ROLE_ORDER = { "provider", "requester", "depot", "fuel", "cleanup" }

local function role_caption(cfg)
  local caption = { "" }
  for _, role in ipairs(ROLE_ORDER) do
    if cfg.roles[role] then
      if #caption > 1 then caption[#caption + 1] = " + " end
      caption[#caption + 1] = { "utl-gui.role-" .. role }
    end
  end
  if #caption == 1 then caption[2] = { "utl-manager.role-none" } end
  return caption
end

function Tab.build(parent)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.horizontal_spacing = 8
  flow.style.vertically_stretchable = true
  local left = flow.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  left.style.width = 230
  left.style.vertically_stretchable = true
  local list = left.add({ type = "list-box", tags = { utl_mgr = "network_list" } })
  list.style.horizontally_stretchable = true
  list.style.vertically_stretchable = true
  local right = flow.add({ type = "flow", direction = "vertical" })
  right.style.horizontally_stretchable = true
  right.style.vertically_stretchable = true
  return { list = list, rows = List.build(right, COLUMNS), names = {} }
end

--- Alle Netze mit ihren Stationen; `home` sagt, ob es das Heimatnetz der Station ist.
local function collect(search)
  local nets, order = {}, {}
  local function ensure(name)
    if nets[name] == nil then
      if search ~= "" and not string.find(string.lower(name), search, 1, true) then
        nets[name] = false
      else
        nets[name] = { name = name, entries = {}, idle = 0, deliveries = 0 }
        order[#order + 1] = name
      end
    end
    return nets[name] or nil
  end

  for _, station in pairs(storage.stations.by_unit) do
    local cfg = station.config
    if cfg then
      for i, name in ipairs(Networks.list(cfg)) do
        local net = ensure(name)
        if net then net.entries[#net.entries + 1] = { station = station, home = i == 1 } end
      end
    end
  end
  for name, pool in pairs(storage.trains.idle or {}) do
    local net = ensure(name)
    if net then
      for _ in pairs(pool) do net.idle = net.idle + 1 end
    end
  end
  for _, delivery in pairs(storage.deliveries.active) do
    local net = delivery.network and ensure(delivery.network)
    if net then net.deliveries = net.deliveries + 1 end
  end

  table.sort(order)
  return nets, order
end

local function fill(row, entry)
  local station = entry.station
  local stop = station.stop
  if stop and stop.valid then
    List.station_label(row, COLUMNS[1].width, stop.backer_name, stop)
  else
    List.cell(row, COLUMNS[1].width, { type = "label", caption = { "utl-manager.no-stop" } })
  end
  List.cell(row, COLUMNS[2].width, { type = "label", caption = role_caption(station.config) })
  local kind = List.cell(row, COLUMNS[3].width, { type = "label",
    caption = { entry.home and "utl-manager.network-home" or "utl-manager.network-extra" } })
  if not entry.home then kind.style.font_color = { 0.7, 0.7, 0.7 } end
end

function Tab.refresh(refs, manager)
  local nets, order = collect(manager.search)
  local items = {}
  for i, name in ipairs(order) do
    local net = nets[name]
    items[i] = { "utl-manager.network-entry", name, #net.entries, net.idle, net.deliveries }
  end
  refs.list.items = items
  refs.names = order
  if #order == 0 then
    manager.network = nil
  elseif not nets[manager.network or ""] then
    manager.network = order[1]
  end
  for i, name in ipairs(order) do
    if name == manager.network then refs.list.selected_index = i end
  end

  local entries = manager.network and nets[manager.network].entries or {}
  table.sort(entries, function(a, b)
    if a.home ~= b.home then return a.home end
    return a.station.unit < b.station.unit
  end)
  List.sync(refs.rows, entries, fill)
end

--- Auswahl in der linken Liste.
function Tab.select(refs, manager, index)
  manager.network = refs.names[index]
end

return Tab
