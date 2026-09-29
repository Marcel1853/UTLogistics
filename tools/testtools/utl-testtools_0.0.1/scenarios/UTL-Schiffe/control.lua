--- Szenario „UTL-Schiffe“ (nur mit Cargo Ships): Marcels Rundkurs als Wasserweg mit UTL-Häfen und
--- zwei Frachtschiffen, daneben eine kleine Zugstrecke im selben UTL-Netz. Gebaut wird im ersten
--- Takt – Szenario-Scripte laufen vor den Mods, deren Speicher wird beim Start der Mod geleert.
local World = require("__utl-testtools__/scenarios/UTL-Schiffe/world")
local Harbor = require("__utl-testtools__/scenarios/UTL-Schiffe/harbor")
local Rail = require("__utl-testtools__/scenarios/UTL-Schiffe/rail")
local Signs = require("__UTLogistics__/scripts/lib/signs")
local Sandbox = require("__UTLogistics__/scripts/lib/sandbox")

local START = { x = 74, y = 50 }

local function place(player)
  local surface = game.surfaces["utl-schiffe"]
  if not surface then
    player.print({ "utl-schiffe.need-cargo-ships" })
    return
  end
  player.teleport(surface.find_non_colliding_position("character", START, 20, 1) or START, surface)
  player.cheat_mode = true
  player.print({ "utl-schiffe.welcome" })
end

-- Schilder: vor dem Hafen, auf der Landseite
local SIGNS = {
  ["11/41"] = "ship-depot", ["65/3"] = "ship-provider", ["115/3"] = "ship-requester",
  ["69/19"] = "ship-fuel", ["83/99"] = "cleanup",
}

local function setup()
  script.on_nth_tick(1, nil)
  if not script.active_mods["cargo-ships"] then
    game.print({ "utl-schiffe.need-cargo-ships" })
    return
  end
  local surface = game.create_surface("utl-schiffe")
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  surface.request_to_generate_chunks({ 74, 60 }, 6)
  surface.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies() -- Übungsnetz: alles erforscht
  local world = World.build(surface, force)
  local depots = Harbor.setup(world.ports, surface, force)
  storage.ships = {}
  for _, port in ipairs(depots) do storage.ships[#storage.ships + 1] = Harbor.ship(port) end
  local train = Rail.build(surface, force)
  local signs = 0
  for key, text in pairs(SIGNS) do
    local port = world.ports[key]
    if port and Signs.place(surface, { port.position.x, port.position.y }, text, { type = "item", name = "utl-port" }) then
      signs = signs + 1
    end
  end
  if Signs.place(surface, { 83, 123 }, "ship-train", { type = "item", name = "locomotive" }) then signs = signs + 1 end
  force.chart(surface, { { -8, -8 }, { 160, 130 } })
  log(("[SCHIFFE] gebaut: Häfen %d, Fehler %d, Wasserfelder %d, Schiffe %d, Zug %s, Anzeigefelder %d"):format(
    table_size(world.ports), world.failed, world.water, #storage.ships, tostring(train ~= nil), signs))
  script.on_nth_tick(30, function()
    script.on_nth_tick(30, nil)
    local started = 0
    for _, body in ipairs(storage.ships) do if Harbor.start(body) then started = started + 1 end end
    log("[SCHIFFE] Schiffe gestartet: " .. started)
  end)
  storage.built = true
  for _, player in pairs(game.players) do place(player) end
end

script.on_configuration_changed(Sandbox.refresh)
script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.built then script.on_nth_tick(1, setup) end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.built then place(player) end
end)
