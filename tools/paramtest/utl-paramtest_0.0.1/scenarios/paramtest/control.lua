--- Versuch: Blaupausen-Parameter mit UTL (Einstellungs-Kombinator, scripts/stations/settings-combinator.lua).
--- Aufbau: UTL-Haltestelle als Abnehmer mit Anforderungs-Slot parameter-1 = 500. Daraus wird eine
--- Blaupause; ihr Inhalt (Parameter-Liste) kommt ins Log, Spieler bekommen sie ins Inventar.
--- Ohne Spieler (headless) wird das Platzieren nachgespielt: in der Blaupause parameter-1 → Eisen,
--- Menge → 4000, Rolle → 5 (Depot), dann bauen und die Geister beleben.
--- Danach alle 2 s: Rolle und Anforderungen jeder UTL-Station.
local L = function(text) log("[PARAM] " .. text) end

local AREA = { { -31, -3 }, { 31, 10 } }

local function build()
  local s = game.create_surface("pt")
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies()
  for x = -29, 29, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end
  local stop = s.create_entity({ name = "utl-train-stop", position = { 0, 3 }, direction = 4, force = force, raise_built = true })
  if not stop then return s, force end
  stop.backer_name = "Param-Test"
  remote.call("utl", "configure_station", stop.unit_number, { mode = "station", provide = false, request = true })
  remote.call("utl", "set_request", stop.unit_number, 1, { type = "item", name = "parameter-1" }, 500)
  return s, force
end

local function make_blueprint(s, force)
  local inv = game.create_inventory(1)
  inv.insert({ name = "blueprint" })
  local stack = inv[1]
  local mapping = stack.create_blueprint({ surface = s, force = force, area = AREA })
  remote.call("utl", "tag_blueprint", stack, mapping, s)
  local bp = helpers.json_to_table(helpers.decode_string(stack.export_stack():sub(2))).blueprint
  local names = {}
  for _, e in ipairs(bp.entities) do if e.name ~= "straight-rail" then names[#names + 1] = e.name end end
  L("Blaupause: Bauteile " .. table.concat(names, ",") .. " – Parameter " .. helpers.table_to_json(bp.parameters or {}))
  return inv
end

local function is_settings(e) return (e.ghost_name or e.name) == "utl-station-settings" and 1 or 0 end

--- Platzieren mit gewählten Parametern nachspielen (so wie Factorio es nach dem Dialog tut).
local function simulate(s, force, stack, y, settings_first)
  local entities = stack.get_blueprint_entities()
  for _, e in ipairs(entities) do
    if e.name == "utl-station-settings" then
      for _, section in ipairs(e.control_behavior.sections.sections) do
        for _, f in ipairs(section.filters or {}) do
          if f.name == "parameter-1" then f.name, f.count = "iron-plate", 4000 end
          if f.name == "utl-role" then f.count = 5 end
        end
      end
    end
  end
  stack.set_blueprint_entities(entities)
  local ghosts = stack.build_blueprint({ surface = s, force = force, position = { 0, y }, build_mode = defines.build_mode.forced })
  -- Haltestelle zuerst beleben, den Einstellungs-Kombinator danach (wie beim Bau durch Roboter)
  table.sort(ghosts, function(a, b)
    if settings_first then return is_settings(a) > is_settings(b) end
    return is_settings(a) < is_settings(b)
  end)
  for _, ghost in ipairs(ghosts) do
    if ghost.valid then ghost.revive({ raise_revive = true }) end
  end
  L("nachgespielt (" .. (settings_first and "Kombinator zuerst" or "Haltestelle zuerst") .. "): " .. #ghosts .. " Geister gebaut")
end

local function setup()
  script.on_nth_tick(1, nil)
  local s, force = build()
  storage.inv = make_blueprint(s, force)
  storage.surface = s.index
  if #game.players == 0 then
    local copy = game.create_inventory(1)
    copy.insert(storage.inv[1])
    simulate(s, force, storage.inv[1], 30, false)
    simulate(s, force, copy[1], 60, true)
  end
  for _, player in pairs(game.players) do
    player.teleport({ 0, 14 }, s)
    player.get_main_inventory().insert(storage.inv[1])
    player.cheat_mode = true
  end
  L("aufgebaut")
end

local function report()
  if not storage.inv then return end
  local lines = {}
  for _, st in pairs(remote.call("utl", "get_stations", {}) --[[@as table[] ]]) do
    local info = remote.call("utl", "get_station", st.unit) --[[@as table?]]
    if info then
      local slots = {}
      for i, r in pairs(info.config.requests or {}) do
        slots[#slots + 1] = i .. "=" .. tostring(r.signal and r.signal.name) .. ":" .. tostring(r.count)
      end
      local need = {}
      for key, n in pairs(info.request or {}) do need[#need + 1] = key .. "=" .. n end
      table.sort(need)
      lines[#lines + 1] = ("%s #%d mode=%s provide=%s request=%s slots[%s] bedarf[%s]"):format(info.stop_name or "?",
        info.unit, tostring(info.config.mode), tostring(info.config.provide), tostring(info.config.request),
        table.concat(slots, ","), table.concat(need, ","))
    end
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
