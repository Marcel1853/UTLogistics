-- Szenen zum Netzverbund: ein Depot im Netz „Eisen“, Anbieter und Abnehmer im Netz „Kupfer“.
-- Anfangs fährt nichts – „Kupfer“ hat keinen Zug. Erst die Verbindung Eisen ↔ Kupfer schickt den
-- Eisen-Zug los. Gezeigt wird das einmal im Stationsfenster und einmal im Manager.
local P = require("__UTLogistics__/prototypes/tips/scenes/common")

local SETUP = [[
DEPOT_NAME = "Depot Eisen"
local depot = stop("Depot Eisen", -3, true, false)
local provider = stop("Anbieter Kupfer", 29, true, false)
local requester = stop("Abnehmer Kupfer", -29, false, false)
d_unit, p_unit, r_unit = depot.unit_number, provider.unit_number, requester.unit_number
equip({ 18.5, 20.5 }, 2.5, true, "copper-plate", provider.get_wire_connector(W.circuit_green, true))
equip({ -18.5, -20.5 }, -0.5, false, nil, requester.get_wire_connector(W.circuit_green, true))
remote.call("utl", "configure_station", d_unit, { mode = "depot", network = "Eisen" })
remote.call("utl", "configure_station", p_unit, { mode = "station", provide = true, request = false,
  provide_threshold = 100, network = "Kupfer" })
remote.call("utl", "configure_station", r_unit, { mode = "station", provide = false, request = true,
  request_threshold = 100, network = "Kupfer" })
remote.call("utl", "set_request", r_unit, 1, { type = "item", name = "copper-plate" }, 200)
-- „Netzverbund II“: zwei Partner erlaubt, danach zeigt das Fenster die Grenze
force.technologies["utl-networks-1"].researched = true
force.technologies["utl-networks-2"].researched = true
sign(-3, 6, "links-iron", { type = "virtual", name = "utl-network" })
sign(22, 8, "links-copper", { type = "item", name = "copper-plate" })
sign(-16.5, -4.5, "links-copper-wait", { type = "item", name = "copper-plate" })
train(-8, 150)
-- Ohne Simulation (tools/tipstest) gleich verbinden, damit der Test eine Lieferung sieht
if not game.simulation then remote.call("utl", "link_networks", s.index, "Eisen", "Kupfer") end

-- Element in UTLs Fenstern über seine tags finden (die Szene kann nicht wirklich klicken)
local function find(root, key, value, target)
  if not (root and root.valid) then return nil end
  local tags = root.tags
  if tags and tags[key] == value and (target == nil or tags.target == target) then return root end
  for _, child in pairs(root.children) do
    local hit = find(child, key, value, target)
    if hit then return hit end
  end
  return nil
end
function gui(key, value, target)
  return find(player.gui.screen, key, value, target) or find(player.gui.relative, key, value, target)
end
-- Jede Runde von vorn: Verbindungen lösen (die Szene läuft in Schleife)
function reset_links()
  remote.call("utl", "unlink_networks", s.index, "Eisen", "Kupfer")
  remote.call("utl", "unlink_networks", s.index, "Eisen", "Kohle")
end
-- Eintrag einer Auswahlliste sichtbar wählen
function pick(element, name)
  if not element then return end
  for i, item in ipairs(element.items) do
    if item == name then element.selected_index = i end
  end
end
]]

-- Stationsfenster des Depots: „Kupfer“ aus der Liste wählen, dann mit „Neu“ das Netz „Kohle“
-- anlegen (Name wird getippt). Danach ist die Grenze erreicht, und der Zug fährt nach Kupfer.
-- Läuft in Schleife; jede Runde beginnt ohne Verbindungen.
local WINDOW = [[
local function open() remote.call("utl", "open_station", player.index, d_unit, nil, true) end
local function link(name)
  return function()
    remote.call("utl", "link_networks", s.index, "Eisen", name)
    open()
  end
end
local function typing(text)
  return function()
    local field = gui("utl_action", "network_name", "extra")
    if field then field.text = text end
  end
end
show({
  { 1, function() reset_links(); open() end },
  { 2, function() pick(gui("utl_action", "network_add_pick"), "Kupfer") end },
  { 1.5, link("Kupfer") },
  { 2.5, function()
    local field = gui("utl_action", "network_name", "extra")
    if field then
      field.parent.visible = true
      field.text = ""
      field.focus()
    end
  end },
  { 0.4, typing("K") }, { 0.25, typing("Ko") }, { 0.25, typing("Koh") }, { 0.25, typing("Kohl") },
  { 0.25, typing("Kohle") },
  { 1.2, link("Kohle") },
  { 8, close },
  { 3, nil },
})
]]

-- Manager, Reiter „Netzwerke“: Netz „Eisen“ wählen, „Kupfer“ verbinden, dann die Sicht des
-- Partners und die Anzeige im Reiter „Stationen“.
local MANAGER = [[
local function manager(tab, select)
  return function() remote.call("utl", "open_manager", player.index, tab, select) end
end
show({
  { 1, function()
    reset_links()
    remote.call("utl", "open_manager", player.index, "networks", { network = s.index .. "|Eisen" })
  end },
  { 2.5, function() pick(gui("utl_mgr", "link_add"), "Kupfer") end },
  { 1, function()
    remote.call("utl", "link_networks", s.index, "Eisen", "Kupfer")
    remote.call("utl", "open_manager", player.index, "networks")
  end },
  { 6, manager("networks", { network = s.index .. "|Kupfer" }) },
  { 5, manager("stations") },
  { 6, close },
  { 3, nil },
})
]]

return {
  links = P.scene({ SETUP, WINDOW }),
  manager_networks = P.scene({ SETUP, MANAGER }),
}
