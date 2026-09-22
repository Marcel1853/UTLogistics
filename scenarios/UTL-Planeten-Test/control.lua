--- Szenario „UTL-Planeten-Test“: das Netz aus „UTL-Netzverbund“ (2 × 2 City Blocks, 8 Züge,
--- Stern Eisen + Kupfer + Kohle, Stein allein) auf Nauvis, Vulcanus und Gleba. Alle Stationen und
--- Depots heißen überall gleich: zum Prüfen der Planeten-Auswahl im UTL-Manager.
--- Braucht Space Age. Ein Szenario lässt sich ohne Space Age nicht ausblenden – dann baut es
--- nichts und sagt nur Bescheid.
--- Aquilo (Züge frieren ohne Heizung ein) und Fulgora (Blitze) bleiben absichtlich außen vor.
--- Gebaut wird im ersten Tick – Szenario-Scripte laufen vor den Mods.
local Verbund = require("__UTLogistics__/scenarios/UTL-Netzverbund/netzverbund")

local AREA = { { -40, -40 }, { 808, 808 } } -- Baugebiet des Netzes (2 × 224 + Rand) mit Reserve
local PLANETS = { "nauvis", "vulcanus", "gleba" }

--- Oberflächen, auf denen gebaut wird.
local function surfaces()
  local list = {}
  for _, name in ipairs(PLANETS) do
    local planet = game.planets[name]
    if planet then list[#list + 1] = planet.surface or planet.create_surface() end
  end
  return list
end

--- Platz machen: Laborboden, alles außer Spielern weg, keine Gegner in der Nähe.
local function clear(surface)
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  surface.peaceful_mode = true
  surface.request_to_generate_chunks({ 384, 384 }, 14)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = AREA[1][1], AREA[2][1] - 1 do
    for y = AREA[1][2], AREA[2][2] - 1 do
      tiles[#tiles + 1] = { name = (x + y) % 2 == 0 and "lab-dark-1" or "lab-dark-2", position = { x, y } }
    end
  end
  surface.set_tiles(tiles, true, false, false, false)
  for _, e in pairs(surface.find_entities_filtered({ area = AREA })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  -- Gegner (Beißer, Würmer, Demolisher, Pentapoden) im weiten Umkreis entfernen
  for _, e in pairs(surface.find_entities_filtered({ force = "enemy", position = { 384, 384 }, radius = 1500 })) do
    if e.valid then e.destroy() end
  end
end

local function place(player)
  if storage.no_space_age then
    player.print({ "utl-planeten-test.needs-space-age" })
    return
  end
  local surface = game.surfaces["nauvis"]
  if not storage.start then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true
  player.print({ "utl-planeten-test.welcome", table.concat(storage.names or {}, ", ") })
end

local function setup()
  script.on_nth_tick(1, nil)
  if not script.active_mods["space-age"] then
    storage.no_space_age = true
    for _, player in pairs(game.players) do place(player) end
    return
  end
  local force = game.forces["player"]
  force.research_all_technologies() -- Test: alles erforscht (auch die Planeten)
  game.map_settings.enemy_expansion.enabled = false
  storage.names = {}
  for _, surface in ipairs(surfaces()) do
    clear(surface)
    local built = Verbund.setup(surface.name)
    force.chart(surface, AREA)
    storage.names[#storage.names + 1] = surface.name
    if surface.name == "nauvis" then storage.start = built.start end
    log(("[PLANETEN] %s: %d Stationen, %d Züge"):format(surface.name, #built.stations, #built.trains))
  end
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.start and not storage.no_space_age then script.on_nth_tick(1, setup) end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)
