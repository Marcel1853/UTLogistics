local P = require("__UTLogistics__/prototypes/tips/scenes/common")

-- Netzwerk-Szene: Rundkurs aus Marcels Blaupause (Gleise, Signale, sechs Bahnhöfe auf
-- Ausbuchtungen, zwei davon normale Haltestelle + UTL-Combinator, Kabel schon gesetzt).
-- Diese Szene stellt die Stationen ein, baut Kisten und Greifarme und setzt die Züge.
-- Zwei Netzwerke auf denselben Gleisen: „Erze“ und „Platten“.
local RING_BP = "0eNrtnd1u27oSRt/FlwdJQXJIkcxznLuiCJxEbYzt2Dn+6d5FkXc/km25STxyZhnYd7kqLMdL7GjImZE+DX9P7ubb9nk1W2wmN78ns/vlYj25+fp7sp79WEzn/bHF9Kmd3ExW09l88nI1mS0e2n8mN/7l29WkXWxmm1m7/8Xuw6/bxfbprl11f3A1/PJ+u/rZPlz3gOvp5GryvFx3v1ouenhHuvYlXU1+TW6a2OEfZqv2fv9teLk6oYYjdb3pgD8eNzvuOWp+UTjCR1fejq4o1MhHV7XRJczJXuM0nCMaJ3NO0jiFc9SrVzlHtbN3GFRUQ3vPQaqlPXfwopraCweptvbcqYtubO7VVTc2d+uqG5v7ddWNzR276sbmnl1VYwfu2d6p1g7+ApJq7hAuIKn2DnIBSTV4iBeQdItz9/Zet3hzAUm3eL6ApFu8XEDSLV4vIKkWlwt8PKgWF56s+BA+zlbkAo8P6pUUuWCEzccZi/zx/x3wkPZpVPlySFmaL8kATm/B94/T2cKCz9GEb/C4vbeR84UD766ciV/UK3mns3fkVA2uVjG2y/U+zmgdxvbz/sPhRs+54g3jDXZurnvrvrtoXh2vYK6eusaIQf3i/naETgMnDpb3//WogRv70pPzPgEM6n8dRKMBpAajWDhIvxiVg/SCzWGQntsmz0FqwEiBg1RjJ+Eg1dgpcpBu7IRBI7ltai4g6ebOF5B0exc83bwrhgUiVRbYcvoyVKqWuNY4a0Q+gr0zpRLNnzmx3cyve/N2494sn3X4sHBcdVdiuv9u0v3lZvpj3f9Vh+j/eVo+7C/W/k860mr5c9Yf26y27dVk1f5v2643w8dFu/l7ufqr+8VD+326nW+6XzzNFre7wdzO28WPzePkpjPB0/SfMwfXu4+HU91uHlft+nE5f9gvIMPhbkz3f73+8tV3z6vZctUZZ3dwvrz/q324Xc+Xmz34MOj34OGwBh6+ewN+aJ+X7w4d/q434cufXz1Nn/cH7uftdLHtP0ym8/ntbNM+rQfb9Qe+z7ezh+ORw9f9D4cvfr/02OW83V2kw3939e5q/DmwG+Hk5vt0vu4+fd+28+OH41B2n19e1BtjAUyyuE8TxJAmNIK5XrIhCDcRTl5/mGPpJOnVB57Ms3cgd9nDe7Q6crLGetXUKjZj7ImlVS5Zfp063EbDVow1DTeDxKOpZutmj7G24YKspMn24QrG2oYLUpYm2YcLUvUBmz72sdxg7EkFoA43YyvYrFvYmtZEtvLkal3TGmGrZSGzTsx+UTzGmgxdyKyzL8EF1MQDthpiXYmYe3JvQL9sCdvBZl8Q4pJ9ES4ZY23DBeVzsi/CpWKsabjV2UNnX9D1tyi9wc2qx1wfqsHNKphuyR41qmCszb7mW8BpWICbYFomK7wHfOT7kC0LfCXzzr4M14yx7x1Oxf6ZdudL2AOzM8J7G3fFzXKx6aqk27v2cfqzK8/6H+3LzZ723FeDR+HG5tdzf7Kfs9VmuzP48J/a/cX1fycvb2tkbcwVm+JkjkT1wbvjYIszewdiaLLHOu8C5lqcwjvBXKOFIwfbLJze3I45OND1/fLpbraYbjqf1M7ghmdSpyuH7tXT1Wzz+NRuZve33dcPO9zu3sC67T/3B7tT97KlDr18bleDH/9n59eft3s+b/e88lkQKWIFq0LGXNuqUDDXuCpUDjatCkRKFe1JpSfKqgPXZGEitDpwbRYmwquYiYXBgh4TsHDCXJuFG8w1WjhzsM3CZNYJsHDFXJOFicgrkuyMaL4iyc6IBCyC7IwIwiLIzog8LJLsjKjFIsnOiHhMQKQjUjIBkY4Iy4REOqIzExLpiOxMQKQTj7kmCxMRmpBIJ8LBNguDWScg0knCXJuFG8w1WjhzsM3CZNaBSCcVc00Wjg5zbRaOnoNNFo5k1oFIFwVzbRaOmGu0cOJgm4XBrAsg0hGZWgCRjqjWAol0RMUWSKQjqrYAIh0RuQUQ6YjmLZBIRzRwgUS6ZL73HhJ7+OmJSi6AIEo0cwEEUaKgCySIpsLBtosHNB0hArBdSheEPTHxDZl6IPA3AXNNXtEI5tq8ookcbLt4CXhF0EfcqGAy8UBGQZRUAWQUTcFc46WrHGy6dNmx55XBHdfkE92IqCfwFzw6Ce7wdvTJBP98cPL54ORffnBCBHseJNlEsedBkk0Ue54k2USz56tdXOdzw0dsW83gi2w+MxGcz2CB96A8yBVzTb7xSrV3XoAxQMW03v6L8gtPFIGeVDQFvCc3gN9r7NQspQgfscmdC1TA+wamxiVdegJjRVbAi3S+MUvLfaETPTEZly/lwhN4caa8iEgHPahVq8Nc00pSPebapmUl0zIB6asn6kFPquAagVdHYGM6HY+lsJy4tTptiHrQg1KYyAc9KIVrwVyj04FXxwew6c3hQFR+HhTZgaj8vL0WDo7MP29+MyMQlZ+319iBiPw8qLGDSxxsu3INnNZDjZ1OoviIz2WwHjkg6w5ElOUqcDow/wau5RoSSZaz11iBSLIcqLEC0WQ5UAqFV5osk9O5wkqh4OOlJ6gnJ/DqCdKFJzBmv8GD5LSfCOY3V4OH6anLLD0NRLbl7HVo8GReZvv7TYHotpy9wA2BvCjv8vhbBp8vzn/eENRvCAai4HPgjkQgEj4HbhyEQNdmWNeHQNfmNJ7SOPUEoFJx9vI4hAwWuGRvlhSIqM8lsMBVzLU5H9H0OVAdByLqc/YiMxBRn7MXmYFo+pwQC0cOtlkYPG91wf56aCCqPgdqTCLqc6AWJJo+R2pBIupzpBaM4M1e5+xdWMIrVd95AUWtMNcEsr4KSkCg6qugUgOivkoKNaDpq6ROi9aujpUWaEDUV0GJADR9FSTyQNFXSY4FBH2VpFhA0FdBfgL0fBVkEUDNV0kSARrcVZJDACVfBSkEEPJVkEEAHV8lCQSQ8VWSPyQw10CUbxzFmqwL9HuVxHig36skxAP9XgHxEqj3CoiXTaJYo3UbzLVZ1z7XCohqQLlXQFQDur1CohrogVZIVANN0AqIakBSVUBUA4qqQqIaUFQVEtUymGsgqgE5VQFRDfRAKySqAQ1VIVENaKgKiGqg8VkBUQ3InAqJaqDxWSFRDYicMohqJVKszbqJYo3WbTDXZl37XMsgqoG2ZxlENaBdyiSqAe1SJlENaJcyiGqg6VkGUQ3IljKJajVirs26YK6BqAa0ShlENSBVyiSqAalSJlENtCMDrYQFyJSyPaqJA49jB+6p5PjzWezns1j9WayAnnQZpE0C1GqktbY49iS2gTfnxVmbmB/JRnWMgP5hoMu2gPZhpMu2OHsT86aABa1SrOnNRgFCNdAUXIBOjTQFFyBTA03BBTQOI122BfQNA72qxdtfiGrELFoU31Cs6b0UAU3DSGtt8cW65gQmKxHQNQw07RYgPiM9sCV4trg79gRPgPAI9NiWYG9insB+YRIi5do09QI6h5Gm4AJERqApuIC+YaQpuACJEeixLUBhRHpsi9ilDgnsNyNg58pE9psRIDACrbUF6ItI22cx72OZAlx34EaWiS7zYhdeJ/t+MyKZYo2GLvaidmgg695v8vVZ1X5WtaNVrbB96mJ5s5ucusettZ9OHF49yKevZahg++objztjfryVKxCZxXP7ZAqQlcVz+2QKEJLFc/tkClCOxXP7ZAro/hbP7ZMpQBkWz+2TKUALFs/tkylA/RXP7ZMpQO4Vz+6TKUDgFc/ukykpcJJu7yR08p3sk6lvXG3P3KN9cy5JiWKzYR9lSQ3FnmwnrFshY66l3Ykk+/bX8bhnlAqqFJQt2yhL4yh3ZKN7aTwmnbzLrw8xsAjpXu/crgLFGiDd613aVVS8bGy7dho6MdHB7XdiV1n2ZHtoYh11kD1qDKARJyl4RMXkIxUPUJ9nQF11AGU9hgA51QDSQwgQUA0g3RuAZErO7ekuQCM1gEaMnSiojBi7waARY2NHH8lFgdJpAI0YG3v2SC5asGeP5KIFe/ZILlqwZ4/kogV79kguWrBnj+SiBXv2WC5aGk4aMXfmpBF7F04aMXjlJN3iFbu397rFq+ck3eI1cJJu8SqcpFu8Rk4asTj38TBicZyn+BB0EvfxMHLtCh9Tc5KqfLua/N0dWE9uvn7tiOGqf582frv62jdHjVd9k77w7dv+PlR3prv5tn1ezRb9Tb2f7Wq9w6Qm1BRDrI100aD7f/8fOzDdkg=="

local NETWORKS_PRE = "AREA = { { -140, -100 }, { 140, 100 } }\nLINES = {}\nRING_BP = \"" .. RING_BP .. "\"\n"


local NETWORKS = [[
-- Blaupause setzen: surface.create_entities_from_blueprint_string gibt es nur in Simulationen,
-- deshalb über einen Blaupausen-Gegenstand bauen und die Geister sofort beleben (klappt überall,
-- also auch im Headless-Test).
local inv = game.create_inventory(1)
inv[1].set_stack({ name = "blueprint" })
inv[1].import_stack(RING_BP)
local ghosts = inv[1].build_blueprint({ surface = s, force = force, position = { 0, 0 },
  skip_fog_of_war = true, raise_built = true })
for _, ghost in pairs(ghosts or {}) do
  if ghost.valid then ghost.revive({ raise_revive = true }) end
end
inv.destroy()

-- Bahnhöfe der Blaupause einsammeln und nach Fahrtrichtung einordnen
-- (oben Osten = Anbieter, unten Westen = Abnehmer, links Norden und rechts Süden = Depots)
local found = { [4] = {}, [12] = {}, [0] = {}, [8] = {} }
for _, st in pairs(s.find_entities_filtered({ type = "train-stop" })) do
  table.insert(found[st.direction], st)
end
table.sort(found[4], function(x, y) return x.position.x < y.position.x end)
table.sort(found[12], function(x, y) return x.position.x < y.position.x end)

-- Combinator einer normalen Haltestelle (Kabel steckt schon in der Blaupause)
local function station_unit(stop)
  if stop.name ~= "train-stop" then return stop.unit_number end
  local c = s.find_entities_filtered({ name = "utl-station-combinator", position = stop.position, radius = 5 })[1]
  return c and c.unit_number
end
local function station_target(stop)
  if stop.name ~= "train-stop" then return stop.get_wire_connector(W.circuit_green, true) end
  local c = s.find_entities_filtered({ name = "utl-station-combinator", position = stop.position, radius = 5 })[1]
  return c and c.get_wire_connector(W.combinator_input_green, true)
end

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

-- Kamera: ganzer Rundkurs, dann die Ausbuchtungen mit geöffnetem Stationsfenster
local minx, maxx, miny, maxy
for _, rail in pairs(s.find_entities_filtered({ type = { "straight-rail", "curved-rail-a", "curved-rail-b" } })) do
  local q = rail.position
  minx = math.min(minx or q.x, q.x); maxx = math.max(maxx or q.x, q.x)
  miny = math.min(miny or q.y, q.y); maxy = math.max(maxy or q.y, q.y)
end
local cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
local function view(x, y, zoom)
  return function()
    if not game.simulation then return end
    game.simulation.camera_position = { x, y }
    game.simulation.camera_zoom = zoom
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

return P.scene({ pre = NETWORKS_PRE, NETWORKS })
