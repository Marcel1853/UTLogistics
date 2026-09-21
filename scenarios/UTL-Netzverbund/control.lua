--- Szenario „UTL-Netzverbund“: vier Netze auf 2 × 2 City Blocks, zwei davon als Partner des
--- Netzes „Eisen“ (siehe netzverbund.lua). Gebaut wird im ersten Tick – Szenario-Scripte laufen
--- vor den Mods, deren Speicher wird beim Start der Mod geleert.
local Verbund = require("__UTLogistics__/scenarios/UTL-Netzverbund/netzverbund")

local function place(player)
  local surface = game.surfaces[Verbund.SURFACE]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true -- zum Ausprobieren: alles verfügbar, sofort bauen
  player.print({ "utl-netzverbund.welcome" })
end

local function setup()
  script.on_nth_tick(1, nil)
  local force = game.forces["player"]
  force.research_all_technologies() -- Übungsnetz: alles erforscht
  local built = Verbund.setup()
  storage.start = built.start
  for _, area in ipairs(built.areas) do force.chart(built.surface, area) end
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
