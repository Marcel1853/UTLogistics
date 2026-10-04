--- Versuch: Funktionieren Blaupausen-Parameter (Vanilla, Factorio 2.x) mit UTL?
--- Aufbau: UTL-Haltestelle als Abnehmer, Konstant-Kombinator mit parameter-0 = -1000 (Bedarf über
--- das Kabel) und ein UTL-Anforderungs-Slot mit parameter-1 (steht in den UTL-Tags der Blaupause).
--- Daraus wird eine Blaupause; ihr Inhalt (JSON) kommt ins Log. Spieler bekommen sie ins Inventar.
--- Danach alle 2 s: was jede UTL-Station anfordert und was im Kombinator neben ihr steht.
local W = defines.wire_connector_id

local function L(text) log("[PARAM] " .. text) end

local AREA = { { -31, -3 }, { 31, 10 } }

local function build()
  local s = game.create_surface("pt")
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces.player
  force.research_all_technologies()
  for x = -29, 29, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end
  local stop = s.create_entity({ name = "utl-train-stop", position = { 0, 3 }, direction = 4, force = force, raise_built = true })
  stop.backer_name = "Param-Test"
  local cc = s.create_entity({ name = "constant-combinator", position = { 3.5, 6.5 }, force = force })
  cc.get_or_create_control_behavior().get_section(1).set_slot(1,
    { value = { type = "item", name = "parameter-0", quality = "normal", comparator = "=" }, min = -1000 })
  cc.get_wire_connector(W.circuit_green, true).connect_to(stop.get_wire_connector(W.circuit_green, true))
  remote.call("utl", "configure_station", stop.unit_number, { mode = "station", provide = false, request = true })
  remote.call("utl", "set_request", stop.unit_number, 1, { type = "item", name = "parameter-1" }, 500)
  -- Versuch 2: Parameter in einem (versteckten) Konstant-Kombinator von UTL – findet Factorio sie dort?
  local out = s.find_entities_filtered({ name = "utl-station-output", position = stop.position, radius = 4 })[1]
  if out then
    local section = out.get_or_create_control_behavior().get_section(1) or out.get_control_behavior().add_section()
    section.set_slot(5, { value = { type = "item", name = "parameter-2", quality = "normal", comparator = "=" }, min = 700 })
    section.set_slot(6, { value = { type = "virtual", name = "utl-request-priority", quality = "normal", comparator = "=" }, min = 3 })
    local off = out.get_control_behavior().add_section()
    off.set_slot(1, { value = { type = "item", name = "parameter-3", quality = "normal", comparator = "=" }, min = 900 })
    off.active = false
    L("Ausgabe gefunden, parameter-2 eingetragen, parameter-3 im ausgeschalteten Abschnitt")
  else
    L("keine Ausgabe gefunden")
  end
  return s, force
end

--- Blaupause in einem Skript-Inventar bauen und ihr JSON loggen.
local function make_blueprint(s, force)
  local inv = game.create_inventory(1)
  inv.insert({ name = "blueprint" })
  local stack = inv[1]
  local mapping = stack.create_blueprint({ surface = s, force = force, area = AREA })
  remote.call("utl", "tag_blueprint", stack, mapping, s)
  local json = helpers.table_to_json(helpers.json_to_table(helpers.decode_string(stack.export_stack():sub(2))))
  L("Blaupause: " .. json)
  return inv
end

local function setup()
  script.on_nth_tick(1, nil)
  local s, force = build()
  storage.inv = make_blueprint(s, force)
  storage.surface = s.index
  for _, player in pairs(game.players) do
    player.teleport({ 0, 14 }, s)
    player.get_main_inventory().insert(storage.inv[1])
    player.cheat_mode = true
  end
  L("aufgebaut")
end

--- Stand aller UTL-Stationen ins Log (nur wenn er sich ändert).
local function report()
  if not storage.inv then return end
  local lines = {}
  for _, st in pairs(remote.call("utl", "get_stations", {})) do
    local info = remote.call("utl", "get_station", st.unit)
    if info then
      local slots = {}
      for i, r in pairs(info.config.requests or {}) do
        slots[#slots + 1] = i .. "=" .. tostring(r.signal and r.signal.name) .. ":" .. tostring(r.count)
      end
      local need = {}
      for key, n in pairs(info.request or {}) do need[#need + 1] = key .. "=" .. n end
      table.sort(need)
      lines[#lines + 1] = ("%s #%d mode=%s slots[%s] bedarf[%s]"):format(info.stop_name or "?", info.unit,
        tostring(info.config.mode), table.concat(slots, ","), table.concat(need, ","))
    end
  end
  local s = game.get_surface(storage.surface)
  for _, cc in pairs(s and s.find_entities_filtered({ name = "constant-combinator" }) or {}) do
    local slot = cc.get_control_behavior().get_section(1).get_slot(1)
    lines[#lines + 1] = ("kombinator %.1f,%.1f: %s = %s"):format(cc.position.x, cc.position.y,
      tostring(slot.value and slot.value.name), tostring(slot.min))
  end
  table.sort(lines)
  local text = table.concat(lines, " | ")
  if text ~= storage.last then
    storage.last = text
    L("stand: " .. text)
  end
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_nth_tick(120, report)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.inv then
    player.teleport({ 0, 14 }, game.get_surface(storage.surface))
    player.get_main_inventory().insert(storage.inv[1])
    player.cheat_mode = true
  end
end)
