--- Szenario „UTL-Lasttest“: City-Block-Gitter 12 × 12, 240 Züge, rund 580 Bahnhöfe, Tankstellen
--- und Cleanup über die Karte verteilt – zum Anschauen, wie sich UTL im großen Maßstab verhält.
--- Gebaut wird im ersten Tick: Factorio startet das Szenario-Script *vor* den Mods und leert
--- deren Speicher bei ihrem Start – eine Einrichtung in on_init ginge verloren.
local Lasttest = require("lasttest")
local Signs = require("__UTLogistics__/scripts/lib/signs")

-- Erklärfelder: je Art das Beispiel, das dem Start am nächsten liegt (Text: utl-sign.<key>).
local SIGNS = {
  { match = function(spec) return spec.kind == "depot" end,
    key = "last-yard" },
  { match = function(spec) return spec.kind == "provider" and not spec.combinator and not prototypes.fluid[spec.item] end,
    key = "last-siding" },
  { match = function(spec) return spec.kind ~= "depot" and spec.combinator end,
    key = "last-combinator" },
  { match = function(spec) return spec.kind == "provider" and prototypes.fluid[spec.item] ~= nil end,
    key = "last-fluid" },
  { match = function(spec) return spec.kind == "fuel" end,
    key = "fuel-low" },
  { match = function(spec) return spec.kind == "cleanup" end,
    key = "cleanup" },
}

local function place_signs(built)
  local start = built.start
  for _, sign in ipairs(SIGNS) do
    local best, best_d
    for _, spec in ipairs(built.stations) do
      if spec.stop and spec.stop.valid and sign.match(spec) then
        local dx, dy = spec.stop.position.x - start.x, spec.stop.position.y - start.y
        local d = dx * dx + dy * dy
        if not best_d or d < best_d then best, best_d = spec, d end
      end
    end
    if best then
      local p = best.stop.position
      Signs.place(built.surface, { p.x, p.y - 3 }, sign.key, { type = "item", name = "utl-train-stop" })
    end
  end
  log(("[LOAD] %d Anzeigefelder"):format(built.surface.count_entities_filtered({ name = "display-panel" })))
end

local function place(player)
  local surface = game.surfaces["utl-lasttest"]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true -- zum Ausprobieren: alles verfügbar, sofort bauen
  player.print({ "utl-lasttest.welcome" })
end

local function setup()
  script.on_nth_tick(1, nil)
  place_signs(Lasttest.setup())
  local surface = game.surfaces["utl-lasttest"]
  local force = game.forces["player"]
  for _, area in ipairs(storage.areas) do force.chart(surface, area) end
  force.research_all_technologies() -- Testnetz: alles erforscht
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
