--- Szenario „UTL-Beispiele“: kleines Netz zum Ausprobieren statt zum Messen.
--- Gebaut wird im ersten Tick – Szenario-Scripte laufen vor den Mods, deren Speicher wird beim
--- Start der Mod geleert.
local Build = require("__UTLogistics__/scenarios/UTL-Beispiele/build")

local function place(player)
  local surface = game.surfaces["utl-beispiele"]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.print({ "utl-beispiele.welcome" })
end

local function setup()
  script.on_nth_tick(1, nil)
  local made = Build.run()
  storage.start = made.start
  storage.area = made.area
  local force = game.forces["player"]
  force.chart(made.surface, made.area)
  local tech = force.technologies["utl-train-logistics"]
  if tech then tech.researched = true end
  log(("[BEISPIELE] gebaut: %d Pumpen an der Auftrags-Ausgabe, Züge %s/%s, %d Objekte nicht gesetzt")
    :format(made.wired, tostring(made.train ~= nil), tostring(made.fluid_train ~= nil), made.failed))
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.start then script.on_nth_tick(1, setup) end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)
