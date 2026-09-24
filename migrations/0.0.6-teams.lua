-- 0.0.6: Teams getrennt. Netzverbindungen gelten jetzt je Ort (Oberfläche + Team) statt je
-- Oberfläche, freie Züge merken sich ihr Team. Bisherige Verbindungen gehörten praktisch dem
-- Standard-Team „player“ und werden dorthin übernommen.
local FORCES = 256 -- wie Networks.place in scripts/stations/networks.lua

local player_force = game.forces["player"]
local player_index = player_force and player_force.index or 1

if storage.network_links then
  local moved = {}
  for key, links in pairs(storage.network_links) do
    -- alte Schlüssel waren Oberflächen-Indizes (< FORCES)
    if key < FORCES then
      moved[key * FORCES + player_index] = links
    else
      moved[key] = links
    end
  end
  storage.network_links = moved
end

if storage.trains and storage.trains.by_id then
  for _, record in pairs(storage.trains.by_id) do
    if record.force_index == nil then
      local stop = record.stop
      local front = record.train and record.train.valid and record.train.front_stock
      record.force_index = (stop and stop.valid and stop.force_index) or (front and front.force_index) or player_index
    end
  end
end
