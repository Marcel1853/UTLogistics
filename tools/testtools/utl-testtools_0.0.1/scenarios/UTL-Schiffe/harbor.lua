--- Häfen des Szenarios „UTL-Schiffe“: Rollen und Ausrüstung am Ufer. Gemessen (Cargo Ships
--- 2.1.8): Ein haltendes Frachtschiff steht mit dem Rumpf 7 Felder hinter dem Hafen (Rumpf
--- 15 lang, 3 breit), der Motor 17 Felder dahinter – beides auf der Linie des Wasserwegs.
--- Greifarme stehen 1,5 Felder neben der Linie am Ufer, die Kisten dahinter.
local Harbor = {}

local W = defines.wire_connector_id

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor (rechts liegt der Hafen)
local DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } },
  [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } },
  [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

--- Rollen der zehn Häfen, nach ihrer Lage im Rundkurs (Schlüssel wie in UTL-Beispiele).
Harbor.ROLES = {
  ["11/41"] = { name = "Hafen-Depot", kind = "depot", ship = true },
  ["137/61"] = { name = "Hafen-Depot", kind = "depot", ship = true },
  ["65/3"] = { name = "Mischlager", kind = "provider", items = { "iron-plate", "copper-plate", "iron-gear-wheel" } },
  ["79/83"] = { name = "Erz-Hafen", kind = "provider", items = { "iron-ore" } },
  ["115/3"] = { name = "Werkstatt", kind = "requester", items = { "iron-plate", "copper-plate" } },
  ["115/19"] = { name = "Kupfer-Lager", kind = "requester", items = { "copper-plate" } },
  ["33/83"] = { name = "Hütte", kind = "requester", items = { "iron-ore" } },
  ["33/99"] = { name = "Baustelle", kind = "requester", items = { "iron-gear-wheel" } },
  ["69/19"] = { name = "Tankstelle", kind = "fuel" },
  ["83/99"] = { name = "Cleanup", kind = "cleanup" },
}

local surface, force

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end

local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

--- Punkt auf der Linie des Wasserwegs, `back` Felder hinter dem Hafen.
local function line_at(port, back)
  local d = DIRS[port.direction] or DIRS[0]
  local rail = port.connected_rail
  local base = rail and { rail.position.x, rail.position.y } or add({ port.position.x, port.position.y }, d.r, -2)
  return add(base, d.f, -back), d
end

local function power(at, d)
  local pole = surface.create_entity({ name = "medium-electric-pole", position = add(at, d.r, 1), force = force })
  -- 2×2 groß: Mitte auf ganzen Feldern (die Kiste steht auf einer Feldmitte)
  local eei = surface.create_entity({ name = "electric-energy-interface", position = add(at, d.r, 3.5), force = force })
  if eei then
    eei.power_production = 200000
    eei.electric_buffer_size = 2000000
  end
  return pole
end

--- Greifarm + Kiste am Ufer, `back` Felder hinter dem Hafen. `item` = Ware einer Unendlich-Kiste
--- (Anbieter, Kohle), sonst eine Kiste, die alles vernichtet (Abnehmer, Cleanup).
local function dock(port, back, item, count)
  local at, d = line_at(port, back)
  local ins_pos, chest_pos = add(at, d.r, 1.5), add(at, d.r, 2.5)
  -- laden: Greifarm greift aus der Kiste (rechts) und legt ins Schiff; entladen umgekehrt
  local grab = item and d.r or { -d.r[1], -d.r[2] }
  surface.create_entity({ name = "bulk-inserter", position = ins_pos, direction = direction_of(grab), force = force })
  local chest = surface.create_entity({ name = "infinity-chest", position = chest_pos, force = force })
  if chest then
    if item then
      chest.infinity_container_filters = { { index = 1, name = item, count = count or 4000, mode = "at-least" } }
    else
      chest.remove_unfiltered_items = true
    end
  end
  return chest, power(chest_pos, d)
end

--- Kisten verketten (grün) und an den Hafen hängen – so sieht UTL das Angebot.
local function wire(port, chests)
  local previous = port
  for _, chest in ipairs(chests) do
    if chest and previous then
      chest.get_wire_connector(W.circuit_green, true).connect_to(previous.get_wire_connector(W.circuit_green, true))
      previous = chest
    end
  end
end

--- Rollen setzen und ausrüsten. Liefert die Depot-Häfen (für die Schiffe).
function Harbor.setup(ports, s, f)
  surface, force = s, f
  local depots = {}
  for key, role in pairs(Harbor.ROLES) do
    local port = ports[key]
    if port then
      port.backer_name = role.name
      local unit = port.unit_number
      if role.kind == "depot" then
        remote.call("utl", "configure_station", unit, { mode = "depot" })
        depots[#depots + 1] = port
      elseif role.kind == "fuel" then
        dock(port, 17.5, "coal", 200) -- am Motor; Schiffe verbrauchen viel
        remote.call("utl", "configure_station", unit, { mode = "fuel" })
      elseif role.kind == "cleanup" then
        dock(port, 3.5, nil)
        dock(port, 9.5, nil)
        remote.call("utl", "configure_station", unit, { mode = "cleanup" })
      elseif role.kind == "provider" then
        local chests = {}
        for i, item in ipairs(role.items) do chests[#chests + 1] = (dock(port, 1.5 + 4 * i, item)) end
        wire(port, chests)
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = true, request = false, provide_threshold = 100 })
      elseif role.kind == "requester" then
        dock(port, 3.5, nil)
        dock(port, 9.5, nil)
        remote.call("utl", "configure_station", unit,
          { mode = "station", provide = false, request = true, request_threshold = 100 })
        -- Die Kisten vernichten alles: Der Bedarf bleibt, die Schiffe fahren ohne Pause
        for slot, item in ipairs(role.items) do
          remote.call("utl", "set_request", unit, slot, { type = "item", name = item }, 400)
        end
      end
    end
  end
  return depots
end

--- Frachtschiff hinter einem Depot-Hafen: Rumpf und Motor setzt das Szenario selbst, OHNE
--- Bau-Ereignis (raise_built). Mods, die gebaute Zugteile entfernen (z. B. Train Construction Site,
--- solange manuelles Platzieren aus ist), ließen sonst nur den unsichtbaren Motor übrig.
--- Der Motor steht 9,9 Felder hinter der Rumpfmitte (gemessen, Cargo Ships 2.1.8) und koppelt
--- von selbst an.
local ENGINE_BACK = 9.9
function Harbor.ship(port)
  -- etwas hinter dem Haltepunkt: das Schiff fährt ein paar Felder ins Depot (steht es schon
  -- darüber hinaus, müsste es erst eine ganze Runde drehen – Schiffe fahren nur etwa 5 Felder/s)
  local at, d = line_at(port, 11)
  local body = surface.create_entity({ name = "cargo_ship", position = at, direction = port.direction, force = force })
  if not body then return nil end
  local engine = surface.create_entity({ name = "cargo_ship_engine", position = add(at, d.f, -ENGINE_BACK),
    direction = port.direction, force = force })
  if not (engine and body.train and #body.train.carriages == 2) then
    if engine then engine.destroy() end
    body.destroy()
    return nil
  end
  return body
end

--- Im nächsten Takt (Motor ist dann angekoppelt): Kohle rein, Fahrplan nur das Depot.
function Harbor.start(body)
  local train = body and body.valid and body.train
  if not train then return false end
  for _, list in pairs({ train.locomotives.front_movers, train.locomotives.back_movers }) do
    for _, loco in pairs(list) do loco.insert({ name = "coal", count = 250 }) end -- 5 Plätze voll
  end
  local schedule = train.get_schedule()
  schedule.add_record({ station = "Hafen-Depot", wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  train.manual_mode = false
  return true
end

return Harbor
