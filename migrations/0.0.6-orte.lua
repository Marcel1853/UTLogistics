-- 0.0.6: Der „Ort“ (Oberfläche + Team) bekommt mehr Luft – Force-Indizes wachsen mit jeder
-- erzeugten Force weiter, die erste Fassung mit Faktor 256 wäre irgendwann übergelaufen.
-- Außerdem sind die Pools der freien Züge jetzt nach Ort **und** Netz geschlüsselt, damit
-- fremde Planeten und Teams das Such-Budget des Dispatchers nicht auffressen.
local OLD = 256
local NEW = 1048576

local player_force = game.forces["player"]
local player_index = player_force and player_force.index or 1

-- Netzverbindungen umschlüsseln: alte Fassungen waren entweder der reine Oberflächen-Index
-- (vor 0.0.6) oder Oberfläche * 256 + Team (frühe 0.0.6-Entwicklung).
if storage.network_links then
  local moved = {}
  for key, links in pairs(storage.network_links) do
    local surface, force
    if key < 1024 then
      surface, force = key, player_index
    elseif key < NEW then
      surface, force = math.floor(key / OLD), key % OLD
    else
      surface, force = math.floor(key / NEW), key % NEW
    end
    moved[surface * NEW + force] = links
  end
  storage.network_links = moved
end

-- Pools der freien Züge neu aufbauen; die Einträge in by_id wissen, wo der Zug steht.
if storage.trains and storage.trains.by_id then
  local idle = {}
  for id, record in pairs(storage.trains.by_id) do
    local stop = record.stop
    local surface = record.surface_index or (stop and stop.valid and stop.surface_index)
    local force = record.force_index or (stop and stop.valid and stop.force_index) or player_index
    if surface then
      record.surface_index, record.force_index = surface, force
      record.place = surface * NEW + force
      for _, name in ipairs(record.networks or { record.network }) do
        local key = record.place .. "|" .. name
        idle[key] = idle[key] or {}
        idle[key][id] = true
      end
    end
  end
  storage.trains.idle = idle
end

-- Sammelwarnungen „kein freier Zug“ hatten den Netznamen als Schlüssel, jetzt Ort + Netz.
if storage.dispatch then storage.dispatch.starving = {} end
