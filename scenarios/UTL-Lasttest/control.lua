--- Szenario „UTL-Lasttest“: City-Block-Gitter 12 × 12, 240 Züge, rund 580 Bahnhöfe, Tankstellen
--- und Cleanup über die Karte verteilt – zum Anschauen, wie sich UTL im großen Maßstab verhält.
--- Gebaut wird im ersten Tick: Factorio startet das Szenario-Script *vor* den Mods und leert
--- deren Speicher bei ihrem Start – eine Einrichtung in on_init ginge verloren.
local Lasttest = require("lasttest")

local function place(player)
  local surface = game.surfaces["utl-lasttest"]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.print({ "utl-lasttest.welcome" })
end

local function setup()
  script.on_nth_tick(1, nil)
  Lasttest.setup()
  local surface = game.surfaces["utl-lasttest"]
  local force = game.forces["player"]
  for _, area in ipairs(storage.areas) do force.chart(surface, area) end
  local tech = force.technologies["utl-train-logistics"]
  if tech then tech.researched = true end
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function()
  script.on_nth_tick(1, setup)
end)

script.on_load(function()
  if not storage.kinds then script.on_nth_tick(1, setup) end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)

script.on_event(defines.events.on_train_changed_state, Lasttest.on_train_changed_state)
script.on_nth_tick(60, Lasttest.on_nth_tick_60)
