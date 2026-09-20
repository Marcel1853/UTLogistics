--- Reiter „Stationen“ (wie LTN Manager): Name + Rolle | Angebot/Bedarf | Unterwegs | Züge.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Networks = require("scripts.stations.networks")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-station" }, width = 220 },
  { caption = { "utl-manager.col-goods" }, width = 200 },
  { caption = { "utl-manager.col-transit" }, width = 200 },
  { caption = { "utl-manager.col-trains" }, width = 60 },
}

local ROLE_ORDER = { "provider", "requester", "depot", "fuel", "cleanup" }

local function role_caption(station)
  local cfg = station.config
  local caption = { "" }
  for _, role in ipairs(ROLE_ORDER) do
    if cfg.roles[role] then
      if #caption > 1 then caption[#caption + 1] = " + " end
      caption[#caption + 1] = { "utl-gui.role-" .. role }
    end
  end
  if #caption == 1 then caption[2] = { "utl-manager.role-none" } end
  local extra = Networks.extra_text(cfg)
  if cfg.network ~= "default" or extra ~= "" then
    caption = { "", caption, "  [", cfg.network, extra ~= "" and (" " .. extra) or "", "]" }
  end
  return caption
end

function Tab.build(parent)
  return { rows = List.build(parent, COLUMNS) }
end

local function fill(row, station)
  local stop = station.stop
  local name_flow = List.cell(row, COLUMNS[1].width, { type = "flow", direction = "vertical" })
  name_flow.style.vertical_spacing = 0
  if stop and stop.valid then
    List.station_label(name_flow, COLUMNS[1].width, stop.backer_name, stop)
  else
    -- Combinator ohne verbundene Haltestelle: deutlich zeigen, was fehlt
    local e = station.entity
    local missing = List.cell(name_flow, COLUMNS[1].width, { type = "label", style = "clickable_label",
      caption = { "utl-manager.no-stop" }, tooltip = { "utl-gui.status-no-stop" },
      tags = e.valid and { utl_mgr = "goto", surface = e.surface_index, x = e.position.x, y = e.position.y } or nil })
    missing.style.font_color = { 1, 0.4, 0.3 }
  end
  local role = name_flow.add({ type = "label", caption = role_caption(station) })
  role.style.font_color = { 0.7, 0.7, 0.7 }

  local goods = Widgets.slot_grid(row, 5)
  Widgets.add_slots(goods, station.provide, "provide", "utl-gui.goods-provide")
  Widgets.add_slots(goods, station.request, "request", "utl-gui.goods-request")

  local deliveries = storage.deliveries
  local transit = Widgets.slot_grid(row, 5)
  Widgets.add_slots(transit, deliveries.incoming[station.unit], "incoming", "utl-gui.transit-incoming")
  Widgets.add_slots(transit, deliveries.outgoing[station.unit], "outgoing", "utl-gui.transit-outgoing")

  List.cell(row, COLUMNS[4].width, { type = "label", caption = tostring(deliveries.trains_at[station.unit] or 0) })
end

function Tab.refresh(refs, manager)
  local search = manager.search
  local items, names = {}, {}
  for _, station in pairs(storage.stations.by_unit) do
    local stop = station.stop
    local name = stop and stop.valid and stop.backer_name or ""
    if search == "" or string.find(string.lower(name), search, 1, true) then
      items[#items + 1] = station
      names[station] = name
    end
  end
  table.sort(items, function(a, b)
    if names[a] ~= names[b] then return names[a] < names[b] end
    return a.unit < b.unit
  end)
  List.sync(refs.rows, items, fill)
end

return Tab
