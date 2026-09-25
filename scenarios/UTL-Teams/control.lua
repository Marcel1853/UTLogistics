--- Szenario „UTL-Teams“: vier Teams auf 2 × 2 City Blocks (siehe teams.lua). Zum Prüfen, ob
--- UTL die Teams sauber trennt – auch allein: mit /utl-team wechselt man das Team.
local Teams = require("__UTLogistics__/scenarios/UTL-Teams/teams")

local function place(player, force_name)
  local surface = game.surfaces[Teams.SURFACE]
  local start = storage.starts and storage.starts[force_name or player.force.name]
  if not (surface and start) then return end
  player.teleport(surface.find_non_colliding_position("character", start, 20, 1) or start, surface)
end

local function join(player, team)
  player.force = game.forces[team.force]
  player.cheat_mode = true -- zum Ausprobieren: alles verfügbar, sofort bauen
  place(player, team.force)
  player.print({ "utl-teams.joined", team.label })
end

local function setup()
  script.on_nth_tick(1, nil)
  local built = Teams.setup()
  storage.starts = built.starts
  -- jedes Team sieht die ganze Karte, damit man die vier Raster vergleichen kann
  for _, team in ipairs(Teams.LIST) do
    local force = game.forces[team.force]
    for _, area in ipairs(built.areas) do force.chart(built.surface, area) end
  end
  for _, player in pairs(game.players) do
    join(player, Teams.LIST[1])
    player.print({ "utl-teams.welcome" })
  end
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.starts then script.on_nth_tick(1, setup) end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if storage.starts then
    join(player, Teams.LIST[1])
    player.print({ "utl-teams.welcome" })
  end
end)

--- /utl-team [rot|blau|gruen|gelb] – ohne Angabe: Liste der Teams.
commands.add_command("utl-team", { "utl-teams.command-help" }, function(event)
  local player = game.get_player(event.player_index or 0)
  if not player then return end
  local wanted = event.parameter and string.lower(event.parameter) or nil
  for _, team in ipairs(Teams.LIST) do
    if wanted == team.force or wanted == string.lower(team.label) then
      join(player, team)
      return
    end
  end
  local names = {}
  for _, team in ipairs(Teams.LIST) do names[#names + 1] = team.force end
  player.print({ "utl-teams.command-list", table.concat(names, ", ") })
end)
