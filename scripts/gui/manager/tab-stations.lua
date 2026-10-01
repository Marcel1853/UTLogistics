--- Reiter „Stationen“ (wie LTN Manager): Name + Rolle | Angebot/Bedarf | Unterwegs | Züge.
local List = require("scripts.gui.common.list")
local Widgets = require("scripts.gui.common.widgets")
local Networks = require("scripts.stations.networks")
local Filter = require("scripts.gui.manager.surface-filter")

local Tab = {}

--- Summe der Mengen einer Warenliste (zum Sortieren).
local function total(...)
  local sum = 0
  for i = 1, select("#", ...) do
    for _, amount in pairs(select(i, ...) or {}) do sum = sum + amount end
  end
  return sum
end

local COLUMNS = {
  { caption = { "utl-manager.col-station" }, width = 220, sort = function(station)
    local stop = station.stop
    return stop and stop.valid and string.lower(stop.backer_name) or ""
  end },
  { caption = { "utl-manager.col-goods" }, width = 200, desc_first = true,
    sort = function(station) return total(station.provide, station.request) end },
  { caption = { "utl-manager.col-transit" }, width = 200, desc_first = true, sort = function(station)
    local deliveries = storage.deliveries
    return total(deliveries.incoming[station.unit], deliveries.outgoing[station.unit])
  end },
  { caption = { "utl-manager.col-trains" }, width = 60, desc_first = true,
    sort = function(station) return storage.deliveries.trains_at[station.unit] or 0 end },
}

local ROLE_ORDER = { "storage", "provider", "requester", "depot", "fuel", "cleanup" }

-- Manager des laufenden Auffrischens (fill bekommt nur Zeile und Station)
local current = nil


local function role_caption(station)
  local cfg = station.config
  local caption = { "" }
  for _, role in ipairs(ROLE_ORDER) do
    -- ein Lager hat intern auch Anbieter/Abnehmer/Cleanup – angezeigt wird nur „Lager“
    if cfg.roles[role] and not (cfg.roles.storage and role ~= "storage") then
      if #caption > 1 then caption[#caption + 1] = " + " end
      caption[#caption + 1] = { "utl-gui.role-" .. role }
    end
  end
  if #caption == 1 then caption[2] = { "utl-manager.role-none" } end
  local stop = station.stop
  local links = stop and stop.valid and Networks.link_text(Networks.place_of(stop), cfg.network) or ""
  if cfg.network ~= "default" or links ~= "" then
    caption = { "", caption, "  [", cfg.network, links ~= "" and (" " .. links) or "", "]" }
  end
  if current and current.several then caption = { "", caption, "  · ", Filter.label((Filter.place_of(station))) } end
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
  current = manager
  for _, station in pairs(storage.stations.by_unit) do
    local stop = station.stop
    local name = stop and stop.valid and stop.backer_name or ""
    if Filter.station(manager, station)
      and (search == "" or string.find(string.lower(name), search, 1, true)) then
      items[#items + 1] = station
      names[station] = name
    end
  end
  table.sort(items, function(a, b)
    if names[a] ~= names[b] then return names[a] < names[b] end
    return a.unit < b.unit
  end)
  local deliveries = storage.deliveries
  List.sync(refs.rows, items, fill, COLUMNS, function(station)
    -- Angebot/Bedarf über `version` (steigt nur bei Änderung), dazu Name, Netz, Rollen, Transit
    local stop = station.stop
    local cfg = station.config
    return table.concat({ station.unit, station.version or 0, stop and stop.valid and stop.backer_name or "",
      cfg.network, stop and stop.valid and Networks.link_text(Networks.place_of(stop), cfg.network) or "",
      List.map_sig(cfg.roles), List.map_sig(deliveries.incoming[station.unit]),
      List.map_sig(deliveries.outgoing[station.unit]), deliveries.trains_at[station.unit] or 0,
      tostring(manager.several) }, "|")
  end)
  current = nil
end

return Tab
