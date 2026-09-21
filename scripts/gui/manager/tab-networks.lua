--- Reiter „Netzwerke“: links alle Netze (je Oberfläche) mit Stationen, freien Zügen und
--- Lieferungen; rechts oben die Verbindungen des gewählten Netzes (Stern: Zentrum ↔ Partner) zum
--- Hinzufügen und Lösen, darunter die Stationen des Netzes und seiner verbundenen Netze.
local List = require("scripts.gui.common.list")
local Networks = require("scripts.stations.networks")
local Unlocks = require("scripts.core.unlocks")

local Tab = {}

local COLUMNS = {
  { caption = { "utl-manager.col-station" }, width = 260 },
  { caption = { "utl-manager.col-role" }, width = 220 },
  { caption = { "utl-manager.col-network" }, width = 140 },
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

  -- Verbindungsleiste: verbundene Netze als Knöpfe, dahinter Auswahl, Feld für einen neuen Namen
  local bar = right.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  bar.style.horizontally_stretchable = true
  bar.style.padding = 8
  local caption = bar.add({ type = "label", tooltip = { "utl-gui.links-tooltip" } })
  caption.style.font_color = { 0.7, 0.7, 0.7 }
  caption.style.bottom_margin = 4
  local chips = bar.add({ type = "table", column_count = 4 })
  chips.style.horizontal_spacing = 4
  chips.style.vertical_spacing = 4
  chips.style.bottom_margin = 4
  local row = bar.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  local add = row.add({ type = "drop-down", tags = { utl_mgr = "link_add" } })
  add.style.minimal_width = 200
  local field = row.add({ type = "textfield", lose_focus_on_confirm = true, clear_and_focus_on_right_click = true,
    tooltip = { "utl-gui.networks-new-tooltip" }, tags = { utl_mgr = "link_name" } })
  field.style.width = 180
  local confirm = row.add({ type = "sprite-button", style = "utl_confirm_button", sprite = "utility/check_mark",
    tooltip = { "utl-gui.networks-new-tooltip" }, tags = { utl_mgr = "link_confirm" } })

  return {
    list = list, keys = {}, rows = List.build(right, COLUMNS),
    caption = caption, chips = chips, add = add, field = field, confirm = confirm,
  }
end

--- Alle Netze je Oberfläche. Schlüssel „<oberfläche>|<name>“.
local function collect(search)
  local nets, order, surfaces = {}, {}, {}
  local function ensure(surface_index, name)
    local key = surface_index .. "|" .. name
    if nets[key] == nil then
      if search ~= "" and not string.find(string.lower(name), search, 1, true) then
        nets[key] = false
      else
        nets[key] = { key = key, surface = surface_index, name = name, stations = {}, idle = 0, deliveries = 0 }
        order[#order + 1] = key
      end
    end
    return nets[key] or nil
  end

  for _, station in pairs(storage.stations.by_unit) do
    local stop, cfg = station.stop, station.config
    if cfg and stop and stop.valid then
      surfaces[stop.surface_index] = true
      local net = ensure(stop.surface_index, cfg.network)
      if net then net.stations[#net.stations + 1] = station end
    end
  end
  -- Netze, die nur über eine Verbindung existieren (noch ohne eigene Station)
  for surface_index, links in pairs(storage.network_links or {}) do
    for center, partners in pairs(links.partners) do
      ensure(surface_index, center)
      for partner in pairs(partners) do ensure(surface_index, partner) end
    end
  end
  -- freie Züge und Lieferungen (nach Netzname; mehrere Oberflächen mit gleichem Namen teilen sich
  -- die Zahl – selten und nur eine Anzeige)
  for _, net in pairs(nets) do
    if net then
      for _ in pairs(storage.trains.idle[net.name] or {}) do net.idle = net.idle + 1 end
    end
  end
  for _, delivery in pairs(storage.deliveries.active) do
    for _, net in pairs(nets) do
      if net and net.name == delivery.network then net.deliveries = net.deliveries + 1 end
    end
  end

  table.sort(order, function(a, b)
    local na, nb = nets[a], nets[b]
    if na.name ~= nb.name then return na.name < nb.name end
    return na.surface < nb.surface
  end)
  local several = next(surfaces) ~= nil and next(surfaces, next(surfaces)) ~= nil
  return nets, order, several
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
  local label = List.cell(row, COLUMNS[3].width, { type = "label", caption = entry.network })
  if not entry.own then label.style.font_color = { 0.7, 0.7, 0.7 } end
end

--- Verbindungsleiste für das gewählte Netz auffrischen.
local function refresh_links(refs, net, force)
  refs.chips.clear()
  if not net then
    refs.caption.caption = { "utl-gui.links" }
    refs.add.items, refs.add.enabled, refs.field.enabled, refs.confirm.enabled = {}, false, false, false
    return
  end
  local limit = Unlocks.networks_limit(force)
  local star = Networks.star(net.surface, net.name)
  refs.caption.caption = star.role == "partner" and { "utl-gui.links" }
    or { "utl-gui.links-count", #star.partners, limit }
  local names = star.role == "partner" and { star.center } or star.partners
  for _, name in ipairs(names) do
    local center = star.role == "partner"
    refs.chips.add({
      type = "button",
      style = "utl_net_chip",
      caption = center and { "utl-gui.link-center-chip", name } or (name .. "  ×"),
      tooltip = { center and "utl-gui.link-leave-tooltip" or "utl-gui.networks-chip-tooltip", name },
      mouse_button_filter = { "left" },
      tags = { utl_mgr = "link_chip", network = name },
    })
  end
  local items = {}
  for _, name in ipairs(Networks.known()) do
    if name ~= net.name and Networks.can_link(net.surface, net.name, name, math.max(limit, 1)) == true then
      items[#items + 1] = name
    end
  end
  refs.add.items = items
  refs.add.selected_index = 0
  local open = star.role ~= "partner" and #star.partners < limit
  refs.add.enabled = open and #items > 0
  refs.field.enabled, refs.confirm.enabled = open, open
end

function Tab.refresh(refs, manager)
  local nets, order, several = collect(manager.search)
  local items = {}
  for i, key in ipairs(order) do
    local net = nets[key]
    local surface = game.surfaces[net.surface]
    local name = several and surface and (net.name .. " · " .. surface.name) or net.name
    items[i] = { "utl-manager.network-entry", name, #net.stations, net.idle, net.deliveries }
  end
  refs.list.items = items
  refs.keys = order
  if #order == 0 then
    manager.network = nil
  elseif not nets[manager.network or ""] then
    manager.network = order[1]
  end
  for i, key in ipairs(order) do
    if key == manager.network then refs.list.selected_index = i end
  end

  local net = manager.network and nets[manager.network] or nil
  local player = game.get_player(manager.player_index or 0)
  refresh_links(refs, net, player and player.force)

  -- Stationen des Netzes und seiner verbundenen Netze (auf derselben Oberfläche)
  local entries = {}
  if net then
    local related = {}
    for _, name in ipairs(Networks.related_list(net.surface, net.name)) do related[name] = true end
    for _, station in pairs(storage.stations.by_unit) do
      local stop = station.stop
      if stop and stop.valid and stop.surface_index == net.surface and related[station.config.network] then
        entries[#entries + 1] = { station = station, network = station.config.network,
          own = station.config.network == net.name }
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.own ~= b.own then return a.own end
    if a.network ~= b.network then return a.network < b.network end
    return a.station.unit < b.station.unit
  end)
  List.sync(refs.rows, entries, fill)
end

--- Auswahl in der linken Liste.
function Tab.select(refs, manager, index)
  manager.network = refs.keys[index]
end

--- Gewähltes Netz als { surface, name } oder nil.
function Tab.selected(manager)
  local key = manager.network
  if not key then return nil end
  local surface, name = key:match("^(%d+)|(.+)$")
  return surface and { surface = tonumber(surface), name = name } or nil
end

return Tab
