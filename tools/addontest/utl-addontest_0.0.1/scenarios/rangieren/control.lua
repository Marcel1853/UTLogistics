--- Testkarte „Rangieren“: Marcels Blaupause (blueprint.lua) wird nach 1 s per Script gebaut (dann hat
--- sich das Test-Add-on bei UTL angemeldet, die Rollen in den Tags sind bekannt). Danach übernimmt
--- yard.lua im Test-Add-on: Wagen von den Abstellgleisen (links) über den Wendestummel (unten) in die
--- Ladebuchten (rechts) bringen und wieder zurück.
local BLUEPRINT = require("blueprint")

local RAIL = { ["straight-rail"] = 1, ["curved-rail-a"] = 1, ["curved-rail-b"] = 1, ["half-diagonal-rail"] = 1 }

local function build()
  local s = game.create_surface("rangieren")
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 6)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies()
  local inv = game.create_inventory(1)
  inv[1].import_stack(BLUEPRINT)
  local ghosts = inv[1].build_blueprint({ surface = s, force = force, position = { 0, 0 },
    build_mode = defines.build_mode.forced })
  -- erst Gleise, dann Signale/Haltestellen, zuletzt Fahrzeuge (dazwischen gemischt, wie bei Robotern)
  local function rank(g)
    local name = g.valid and g.ghost_name or ""
    if RAIL[name] then return 0 end
    if g.valid and (g.ghost_type == "locomotive" or g.ghost_type == "cargo-wagon") then return 2 end
    return 1
  end
  table.sort(ghosts, function(a, b) return rank(a) < rank(b) end)
  for _, g in ipairs(ghosts) do
    if g.valid then g.revive({ raise_revive = true }) end
  end
  inv.destroy()
  log("[ADDONTEST] Haltestellen gebaut: " .. #s.find_entities_filtered({ name = "utl-train-stop" }) .. " von 14")
  for _, g in ipairs(s.find_entities_filtered({ type = "entity-ghost" })) do
    log("[ADDONTEST] nicht gebaut: " .. g.ghost_name .. " bei " .. serpent.line(g.position))
  end
  for _, loco in ipairs(s.find_entities_filtered({ type = "locomotive" })) do
    loco.insert({ name = "coal", count = 50 })
  end
  for _, loco in ipairs(s.find_entities_filtered({ type = "locomotive" })) do
    loco.train.manual_mode = false
  end
  remote.call("utl-addontest", "setup_yard", s.index)
  return s
end

local function welcome(player)
  player.print("[font=default-bold]UTL Rangier-Test[/font]: Die Rangierlok holt Wagen von den Abstellgleisen (links), "
    .. "wendet unten im Stummel und schiebt sie in die Ladebuchten (rechts) – danach wieder zurück. "
    .. "Ablauf im UTL-Manager, Reiter „Add-on-Test“.")
end

script.on_nth_tick(60, function()
  if storage.built then return end
  storage.built = true
  local s = build()
  for _, player in pairs(game.players) do
    player.teleport({ 3, -10 }, s)
    welcome(player)
  end
  script.on_nth_tick(60, nil)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.built then
    player.teleport({ 3, -10 }, "rangieren")
    welcome(player)
  end
end)
