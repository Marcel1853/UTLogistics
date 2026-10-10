--- Heimweg durch den Weltraumaufzug (Space Exploration): Ein Zug, der nach einer Lieferung über den
--- Aufzug auf der anderen Seite steht, findet sein Depot dort nicht. Vor den nächsten festen Halt
--- seines Fahrplans (in der Regel das Depot) kommt dann der Aufzug-Halt dieser Seite – hinter
--- Tank- und Cleanup-Halte, die UTL gerade eingefügt hat (die liegen auf dieser Seite).
local Networks = require("scripts.stations.networks")
local Elevators = require("scripts.compat.se-elevators")

local OwnRecords = require("scripts.trains.own-records")

local Home = {}

--- Aufzug-Halt vor den nächsten festen Halt setzen, falls der Zug nicht auf der Seite seines
--- Heimatdepots steht. Liefert true, wenn ein Halt eingefügt wurde.
function Home.ensure(train)
  if not (storage.elevators and train.valid and not train.manual_mode) then return false end
  local front = train.front_stock
  local home = storage.trains.home[train.id]
  local depot = home and home.stop
  if not (front and depot and depot.valid) or depot.surface_index == front.surface_index then return false end
  local unit = storage.stations.by_stop[depot.unit_number]
  local station = unit and storage.stations.by_unit[unit]
  local network = station and station.config.network or "default"
  local route = Elevators.route(Networks.place_of(front), Networks.place_of(depot), network, front.position)
  if not route then return false end
  local schedule = train.get_schedule()
  if not schedule then return false end
  local count = schedule.get_record_count() or 0
  local current = math.max(schedule.current or 1, 1)
  local index = current
  while index <= count do
    local record = schedule.get_record({ schedule_index = index })
    if not (record and record.temporary) then break end
    if record.station == route.here.backer_name then return false end -- schon eingeplant
    index = index + 1
  end
  OwnRecords.add(schedule, {
    station = route.here.backer_name,
    temporary = true,
    wait_conditions = {},
    index = { schedule_index = index },
  })
  if index == current then schedule.go_to_station(index) end
  return true
end

return Home
