--- Testkarte für den Add-on-Test: zwei gerade Strecken.
---   oben (y = 1):  Rangierdepot (Add-on-Rolle, eigene Züge) – die Rangierlok holt einen Wagen vom
---                  Abstellgleis, bringt ihn zum Ladegleis und stellt ihn wieder ab (shunting.lua)
---   unten (y = 21): normales UTL-Depot mit Zug, Ladebucht (Add-on-Rolle wie Anbieter) → Abnehmer
--- Gebaut wird nach 1 s (dann hat sich das Add-on bei UTL angemeldet; Szenarien starten vor Mods).
local MOD = "utl-addontest"
local W = defines.wire_connector_id

local function stop(s, force, name, x, y, west)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, y + (west and -2 or 2) },
    direction = west and 12 or 4, force = force, raise_built = true })
  e.backer_name = name
  return e
end

local function rails(s, force, y)
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, y }, direction = 4, force = force }) end
end

local function loco_pair(s, force, x, y, depot)
  local l1 = s.create_entity({ name = "locomotive", position = { x, y }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { x - 7, y }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 50 })
  l2.insert({ name = "coal", count = 50 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = depot, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
end

local function cargo_train(s, force, x, y, depot)
  local l1 = s.create_entity({ name = "locomotive", position = { x, y }, direction = 4, force = force })
  s.create_entity({ name = "cargo-wagon", position = { x - 7, y }, direction = 4, force = force })
  local l2 = s.create_entity({ name = "locomotive", position = { x - 14, y }, direction = 12, force = force })
  l1.insert({ name = "coal", count = 50 })
  l2.insert({ name = "coal", count = 50 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = depot, wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
end

local function build()
  local s = game.create_surface("addontest")
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies()
  local set = function(e, changes) remote.call("utl", "configure_station", e.unit_number, changes) end

  -- oben: Rangieren (shunting.lua im Test-Add-on). Von West nach Ost:
  --   Wagen (-66) · Abstellgleis (-58, Richtung West) · Zufahrt (-40, Richtung West) ·
  --   Ladegleis (-15, Richtung Ost) · Rangierdepot (20, Richtung Ost)
  rails(s, force, 1)
  local shunt_depot = stop(s, force, "Rangierdepot", 20, 1)
  local siding = stop(s, force, "Abstellgleis", -58, 1, true)
  local access = stop(s, force, "Zufahrt Abstellgleis", -40, 1, true)
  local load = stop(s, force, "Ladegleis", -15, 1)
  for _, e in ipairs({ shunt_depot, siding, access, load }) do set(e, { network = "Rangieren" }) end
  remote.call("utl", "set_station_role", shunt_depot.unit_number, MOD .. "/depot")
  for _, e in ipairs({ siding, access, load }) do remote.call("utl", "set_station_role", e.unit_number, MOD .. "/siding") end
  remote.call("utl", "set_station_data", siding.unit_number, MOD, "tracks", 3)
  local wagon = s.create_entity({ name = "cargo-wagon", position = { -66, 1 }, direction = 4, force = force })
  remote.call(MOD, "setup", { wagon = wagon, access = access.unit_number, load = load.unit_number, siding = siding.unit_number })
  loco_pair(s, force, 14, 1, "Rangierdepot")

  -- unten: Lieferung aus der Ladebucht
  rails(s, force, 21)
  local depot = stop(s, force, "Depot", 10, 21)
  local bay = stop(s, force, "Ladebucht", 60, 21)
  local req = stop(s, force, "Abnehmer", -60, 21, true)
  set(depot, { network = "Test", mode = "depot" })
  set(bay, { network = "Test" })
  remote.call("utl", "set_station_role", bay.unit_number, MOD .. "/bay")
  set(req, { network = "Test", mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 1000)
  local c = s.create_entity({ name = "constant-combinator", position = { 63.5, 26.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1,
    { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 5000 })
  c.get_wire_connector(W.circuit_green, true).connect_to(bay.get_wire_connector(W.circuit_green, true))
  cargo_train(s, force, 4, 21, "Depot")
  return s
end

local function welcome(player)
  player.print("[font=default-bold]UTL Add-on-Test[/font]: oben holt eine Rangierlok einen Wagen vom Abstellgleis, "
    .. "kuppelt an, bringt ihn zum Ladegleis und stellt ihn wieder ab; "
    .. "unten liefert ein UTL-Zug aus der Ladebucht. Zum Ansehen: Stationsfenster (Rollen-Häkchen, Abschnitt "
    .. "„Add-on-Test“ mit Gleise +/−) und UTL-Manager (Reiter „Add-on-Test“).")
end

script.on_nth_tick(60, function(event)
  if storage.built then return end
  storage.built = true
  local s = build()
  for _, player in pairs(game.players) do
    player.teleport({ 0, 12 }, s)
    welcome(player)
  end
  script.on_nth_tick(60, nil)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.built then
    player.teleport({ 0, 12 }, "addontest")
    welcome(player)
  end
end)
