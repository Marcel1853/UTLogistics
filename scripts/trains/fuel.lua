--- Treibstoffstand der Loks. Ein Zug gilt als knapp, wenn *eine* seiner Loks unter der
--- Grenze liegt (Map-Einstellung „Tanken unter (%)“). Die Tankstelle sucht service-stops.lua.
local ServiceStops = require("scripts.trains.service-stops")

local Fuel = {}

--- Füllstand einer Lok (0..1); Loks ohne Brennstoff-Inventar (elektrisch) zählen als voll.
local function fraction(locomotive)
  local inventory = locomotive.get_fuel_inventory()
  if not inventory then return 1 end
  local size = #inventory
  if size == 0 then return 1 end
  local sum = 0
  for i = 1, size do
    local stack = inventory[i]
    if stack.valid_for_read then sum = sum + stack.count / stack.prototype.stack_size end
  end
  return sum / size
end

--- Niedrigster Füllstand aller Loks des Zugs.
function Fuel.lowest(train)
  local lowest = 1
  local locomotives = train.locomotives
  for _, list in pairs({ locomotives.front_movers, locomotives.back_movers }) do
    for _, locomotive in pairs(list) do
      local value = fraction(locomotive)
      if value < lowest then lowest = value end
    end
  end
  return lowest
end

function Fuel.is_low(train)
  local threshold = storage.cfg.fuel_threshold
  return threshold > 0 and Fuel.lowest(train) < threshold / 100
end

--- Passende Tankstelle, falls der Zug knapp ist; sonst nil.
function Fuel.stop_if_low(train, network)
  if not Fuel.is_low(train) then return nil end
  return ServiceStops.find(train, network, "fuel")
end

--- Muss der Zug vor einem Auftrag tanken? Nur wenn er knapp ist UND es im Netzwerk Tankstellen
--- gibt – wer ohne UTL-Tankstellen spielt (eigene Interrupts, Hand), dessen Züge fahren normal.
function Fuel.needs_station(train, network)
  return Fuel.is_low(train) and ServiceStops.exists(network, "fuel")
end

return Fuel
