local P = require("__UTLogistics__/prototypes/tips/scenes/common")

-- Netzwerk-Szene auf dem Rundkurs (ring-layout.lua).
-- Diese Szene stellt die Stationen ein, baut Kisten und Greifarme und setzt die Züge.
-- Zwei Netzwerke auf denselben Gleisen: „Erze“ und „Platten“.
local Layout = require("__UTLogistics__/prototypes/tips/scenes/ring-layout")

local NETWORKS = [[
local function setup(stop, name, network, mode)
  stop.backer_name = (stop.name == "train-stop" and "[item=utl-station-combinator] " or "") .. name
  local unit = station_unit(stop)
  remote.call("utl", "configure_station", unit, mode)
  remote.call("utl", "configure_station", unit, { network = network })
  return unit
end

-- Netz „Erze“ bekommt die Combinator-Bauart, „Platten“ die UTL-Haltestellen
local nets = {}
for _, st in pairs(found[4]) do
  nets[st.name == "train-stop" and "Erze" or "Platten"] = { provider = st }
end
for _, st in pairs(found[12]) do
  nets[st.name == "train-stop" and "Erze" or "Platten"].requester = st
end
nets.Erze.depot, nets.Platten.depot = found[0][1], found[8][1]
nets.Erze.item, nets.Platten.item = "iron-ore", "copper-plate"

for name, net in pairs(nets) do
  setup(net.depot, "Depot " .. name, name, { mode = "depot" })
  local p_unit = setup(net.provider, "Anbieter " .. name, name,
    { mode = "station", provide = true, request = false, provide_threshold = 100 })
  local r_unit = setup(net.requester, "Abnehmer " .. name, name,
    { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", r_unit, 1, { type = "item", name = net.item }, 200)
  if name == "Erze" then ERZ_STOP = p_unit end

  -- Anbieter: Fahrtrichtung Osten → Gleis 2 Felder über der Haltestelle, Kisten darunter
  local pl = net.provider.position.y - 2
  equip({ net.provider.position.x - 10 }, pl + 1.5, true, net.item, station_target(net.provider), false, pl)
  -- Abnehmer: Fahrtrichtung Westen → Gleis 2 Felder unter der Haltestelle, Kisten darüber.
  -- Stahlkiste mit langsamem Abfluss, damit der Bedarf nach und nach entsteht und der Zug
  -- zwischendurch sichtbar ins Depot zurückfährt.
  local rl = net.requester.position.y + 2
  local rx = net.requester.position.x + 10
  equip({ rx }, rl - 1.5, false, nil, station_target(net.requester), true, rl)
  s.create_entity({ name = "inserter", position = { rx, rl - 3.5 }, direction = 8, force = force })
  local void = s.create_entity({ name = "infinity-chest", position = { rx, rl - 4.5 }, force = force })
  void.remove_unfiltered_items = true

  -- Zug (Lok + Wagen) im Depot: links fährt er nach Norden, rechts nach Süden
  local north = net.depot.direction == 0
  local rail_x = net.depot.position.x + (north and -2 or 2)
  local head_y = net.depot.position.y + (north and 3 or -3)
  local loco = s.create_entity({ name = "locomotive", position = { rail_x, head_y },
    direction = north and 0 or 8, force = force })
  s.create_entity({ name = "cargo-wagon", position = { rail_x, head_y + (north and 7 or -7) },
    direction = north and 0 or 8, force = force })
  loco.insert({ name = "coal", count = 150 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = "Depot " .. name, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
end

-- Schild neben jedem Depot: welches Netz, und dass die Netze nichts voneinander wissen
for name, net in pairs(nets) do
  local p = net.depot.position
  local icon = { type = "virtual", name = "utl-network" }
  for d = 3, 9 do
    if sign(p.x + d, p.y, "ring-network", icon, name) or sign(p.x - d, p.y, "ring-network", icon, name) then break end
  end
end

local overview = view(cx, cy, 0.17)
overview()
local perz = nets.Erze.provider.position
show({
  { 1, overview },
  { 8, view(perz.x - 6, perz.y + 4, 0.55) },
  { 2, function() remote.call("utl", "open_station", player.index, ERZ_STOP, nil, true) end },
  { 8, function() remote.call("utl", "close_windows", player.index) end },
  { 8, view(nets.Erze.depot.position.x + 6, nets.Erze.depot.position.y, 0.5) },
  { 8, overview },
})
]]

return P.scene({ pre = Layout.PRE, Layout.BUILD, NETWORKS })
