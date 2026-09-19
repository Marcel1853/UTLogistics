--- /utl-status: zeigt den Zustand des Mods (Version, Takt, Zähler).
local Heartbeat = require("scripts.core.heartbeat")

local function status(command)
  local interval = Heartbeat.registered_interval()
  local message = { "utl-command.status",
    script.active_mods[script.mod_name],
    interval and tostring(interval) or { "utl-command.status-sleeping" },
    storage.heartbeat.count,
    storage.stations.count,
    storage.trains.count,
    storage.deliveries.count,
  }
  local player = command.player_index and game.get_player(command.player_index)
  if player then
    player.print(message)
  else
    game.print(message)
  end
end

commands.add_command("utl-status", { "utl-command.status-help" }, status)
