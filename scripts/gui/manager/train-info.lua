--- Anzeige-Helfer für Züge: Zusammensetzung „<L CC L>“, Zustand, Ladung.
local Deliveries = require("scripts.deliveries.deliveries")
local Util = require("scripts.lib.util")

local Info = {}

local S = defines.train_state
local LETTERS = { ["cargo-wagon"] = "C", ["fluid-wagon"] = "F", ["artillery-wagon"] = "A" }

--- „<L“ = Lok in Fahrtrichtung, „L>“ = Lok rückwärts, C/F/A = Güter-/Flüssigkeits-/Artilleriewagen.
function Info.composition(train)
  local front = {}
  for _, loco in pairs(train.locomotives.front_movers) do front[loco.unit_number] = true end
  local parts = {}
  for _, carriage in ipairs(train.carriages) do
    if carriage.type == "locomotive" then
      parts[#parts + 1] = front[carriage.unit_number] and "<L" or "L>"
    else
      parts[#parts + 1] = LETTERS[carriage.type] or "?"
    end
  end
  return table.concat(parts)
end

--- Zustand als { Überschrift, Stationsname oder nil }.
function Info.status(train)
  local id = train.id
  local delivery = Deliveries.of_train(id)
  if delivery then
    local state = delivery.state
    if state == "to_provider" then return { "utl-manager.status-to-provider" }, delivery.from end
    if state == "loading" then return { "utl-manager.status-loading" }, delivery.from end
    if state == "to_requester" then return { "utl-manager.status-to-requester" }, delivery.to end
    return { "utl-manager.status-unloading" }, delivery.to
  end
  local state = train.state
  if state == S.manual_control or state == S.manual_control_stop then
    return { "utl-manager.status-manual" }, nil
  end
  if state == S.no_path then return { "utl-manager.status-no-path" }, nil end
  if storage.trains.by_id[id] then
    local station = train.station
    return { "utl-manager.status-idle" }, station and station.backer_name
  end
  local service = storage.trains.service[id]
  if service == "cleanup" then return { "utl-manager.status-cleanup" }, nil end
  if service == "relocate" or service == "relocate-serviced" then return { "utl-manager.status-relocate" }, nil end
  if service then return { "utl-manager.status-refuel" }, nil end
  if state == S.wait_station and train.station then
    return { "utl-manager.status-at-station" }, train.station.backer_name
  end
  return { "utl-manager.status-returning" }, nil
end

--- Ladung als [key] = Menge; ist der Zug noch leer, die geplante Liefermenge (zweiter Wert true).
function Info.cargo(train)
  local cargo = {}
  local any = false
  for _, stack in pairs(train.get_contents()) do
    local key = Util.signal_key({ type = "item", name = stack.name, quality = stack.quality })
    if key then
      cargo[key] = (cargo[key] or 0) + stack.count
      any = true
    end
  end
  for name, amount in pairs(train.get_fluid_contents()) do
    local key = Util.signal_key({ type = "fluid", name = name })
    if key then
      cargo[key] = math.floor(amount)
      any = true
    end
  end
  if not any then
    local delivery = Deliveries.of_train(train.id)
    if delivery then return delivery.manifest, true end
  end
  return cargo, false
end

return Info
