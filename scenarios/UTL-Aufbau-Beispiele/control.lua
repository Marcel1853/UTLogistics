--- Szenario „UTL-Aufbau-Beispiele“: Sammlung von Aufbauten zum Anschauen und Nachbauen – jede Frage „wie
--- baue ich …?“ bekommt hier ein eigenes Beispiel in einem eigenen Bereich. Ein kleines Fenster springt
--- per Knopf zu jedem Beispiel.
---
--- Neues Beispiel: Datei in examples/ (Felder key, size, build(origin) → Startpunkt), hier in EXAMPLES
--- eintragen, Texte in locale/*/aufbau.cfg. Gebaut wird im ersten Tick – Szenario-Scripte laufen vor den
--- Mods, UTL ist erst danach bereit.
local Build = require("__UTLogistics__/scenarios/UTL-Aufbau-Beispiele/build")
local Sandbox = require("__UTLogistics__/scripts/lib/sandbox")

local EXAMPLES = {
  require("__UTLogistics__/scenarios/UTL-Aufbau-Beispiele/examples/faesser"),
}

local SURFACE = "utl-aufbau"
local GAP = 64 -- Abstand zwischen den Bereichen (gerade, damit das Gleisraster passt)
local WINDOW = "utl_aufbau_window"

local function place(player, index)
  local spot = storage.spots and storage.spots[index or 1]
  local surface = game.surfaces[SURFACE]
  if not (spot and surface) then return end
  player.teleport(surface.find_non_colliding_position("character", spot, 20, 1) or spot, surface)
end

local function window(player)
  if player.gui.screen[WINDOW] then player.gui.screen[WINDOW].destroy() end
  local frame = player.gui.screen.add({ type = "frame", name = WINDOW, direction = "vertical",
    caption = { "utl-aufbau.window-title" } })
  frame.location = { 20, 120 }
  frame.add({ type = "label", caption = { "utl-aufbau.window-intro" } }).style.single_line = false
  for i, example in ipairs(EXAMPLES) do
    frame.add({ type = "button", caption = { "utl-aufbau." .. example.key .. "-title" },
      tooltip = { "utl-aufbau." .. example.key .. "-text" }, tags = { utl_aufbau = i } })
  end
end

local function setup()
  script.on_nth_tick(1, nil)
  local surface = game.surfaces[SURFACE] or game.create_surface(SURFACE)
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  local force = game.forces["player"]
  force.research_all_technologies()
  storage.spots = {}
  local x = 0
  for i, example in ipairs(EXAMPLES) do
    local origin = { x, 0 }
    surface.request_to_generate_chunks({ x + example.size[1] / 2, example.size[2] / 2 },
      math.ceil(math.max(example.size[1], example.size[2]) / 64) + 1)
    surface.force_generate_chunk_requests()
    Build.begin(surface, force)
    storage.spots[i] = example.build(origin)
    local problems = Build.problems()
    log(("[AUFBAU] %s gebaut, Probleme: %s"):format(example.key, #problems == 0 and "keine" or table.concat(problems, "; ")))
    force.chart(surface, { { x - 8, -8 }, { x + example.size[1] + 8, example.size[2] + 8 } })
    x = x + example.size[1] + GAP
    x = x - x % 2
  end
  for _, player in pairs(game.players) do
    place(player, 1)
    player.cheat_mode = true
    window(player)
    player.print({ "utl-aufbau.welcome" })
  end
end

script.on_configuration_changed(Sandbox.refresh)
script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.spots then script.on_nth_tick(1, setup) end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if not (player and storage.spots) then return end
  place(player, 1)
  player.cheat_mode = true
  window(player)
end)
script.on_event(defines.events.on_gui_click, function(event)
  local index = event.element.valid and event.element.tags and event.element.tags.utl_aufbau
  if index then place(game.get_player(event.player_index), index) end
end)
