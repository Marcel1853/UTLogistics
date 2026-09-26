--- Szenario „UTL-Beispiele“: kleines Netz zum Ausprobieren statt zum Messen.
--- Gebaut wird im ersten Tick – Szenario-Scripte laufen vor den Mods, deren Speicher wird beim
--- Start der Mod geleert.
local Build = require("__UTLogistics__/scenarios/UTL-Beispiele/build")
local place_signs = require("__UTLogistics__/scenarios/UTL-Beispiele/signs")
local Panel = require("__UTLogistics__/scenarios/UTL-Beispiele/panel")

local function place(player)
  local surface = game.surfaces["utl-beispiele"]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true -- zum Ausprobieren: alles verfügbar, sofort bauen
  player.print({ "utl-beispiele.welcome" })
  Panel.create(player)
end

--- Zweiter Schritt: Pumpen an die Auftrags-Ausgaben hängen (siehe Build.wire).
local function wire()
  script.on_nth_tick(30, nil)
  if storage.made and not storage.wired then
    storage.wired = true
    log(("[BEISPIELE] %d Pumpen an der Auftrags-Ausgabe"):format(Build.wire(storage.made)))
  end
end

local function setup()
  script.on_nth_tick(1, nil)
  local made = Build.run()
  storage.made = made
  script.on_nth_tick(30, wire)
  storage.start = made.start
  storage.area = made.area
  local force = game.forces["player"]
  force.chart(made.surface, made.area)
  force.research_all_technologies() -- Übungsnetz: alles erforscht
  local signs = place_signs(made.stops)
  log(("[BEISPIELE] gebaut: Züge %s/%s, %d Objekte nicht gesetzt, %d Anzeigefelder")
    :format(tostring(made.train ~= nil), tostring(made.fluid_train ~= nil), made.failed, signs))
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  -- Nach dem Laden sind die Takt-Anmeldungen weg: das Offene wieder anmelden.
  if not storage.start then
    script.on_nth_tick(1, setup)
  elseif not storage.wired then
    script.on_nth_tick(30, wire)
  end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)

-- Erklärfenster: einmal pro Sekunde auffrischen, Knopf wechselt den verfolgten Zug
script.on_nth_tick(60, Panel.tick)
script.on_event(defines.events.on_gui_click, Panel.on_click)
