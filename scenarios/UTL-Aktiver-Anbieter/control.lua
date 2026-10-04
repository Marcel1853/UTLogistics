--- Szenario „UTL-Aktiver-Anbieter“: zeigt die Rolle „Aktiver Anbieter“. Eine Runde läuft so:
---   1. Der aktive Anbieter bekommt 6000 Eisen.
---   2. Zuerst bekommt der Abnehmer, was er braucht (1000).
---   3. Dann füllt sich das Lager bis zum Höchstbestand (1000 → 2000), obwohl es über dem Mindest liegt.
---   4. Der Rest geht ins Cleanup.
---   5. Der Bahnhof ist leer. 20 s später beginnt die nächste Runde (Kisten werden zurückgesetzt).
local World = require("__UTLogistics__/scenarios/UTL-Aktiver-Anbieter/world")
local Explain = require("__UTLogistics__/scripts/lib/explain-panel")
local Sandbox = require("__UTLogistics__/scripts/lib/sandbox")

local PANEL = "utl_aktiv_panel"
local PAUSE = 20 * 60
local ROUND_LIMIT = 8 * 3600 -- Sicherheitsnetz: eine Runde endet spätestens nach 8 Minuten
local STEPS = { "step-1", "step-2", "step-3", "step-4", "step-5" }
-- Ziel einer Lieferung → Schritt
local STEP_OF = { requester = 2, storage = 3, cleanup = 4 }

local function create_panel(player)
  Explain.create(player, { name = PANEL, title = { "utl-aktiv.title" }, intro = { "utl-aktiv.intro" } })
end

--- Neue Runde: Kisten zurücksetzen.
local function start_round()
  local a = storage.aktiv
  World.set(a.provider_chests, World.SUPPLY)
  World.set(a.requester_chests, 0)
  World.set(a.storage_chests, World.STORAGE_START)
  a.round, a.step, a.phase = a.round + 1, 1, "running"
  a.round_until = game.tick + ROUND_LIMIT
  a.sent = { requester = 0, storage = 0, cleanup = 0 }
  a.counted = {}
end

local function setup()
  script.on_nth_tick(1, nil)
  game.forces["player"].research_all_technologies()
  local w = World.build()
  storage.aktiv = {
    provider_chests = w.provider_chests, requester_chests = w.requester_chests, storage_chests = w.storage_chests,
    stops = { requester = w.requester, storage = w.storage, cleanup = w.cleanup, provider = w.provider },
    labels = w.labels, wire = w.wire, round = 0, step = 0, phase = "pause", wait_until = game.tick + 120,
    sent = { requester = 0, storage = 0, cleanup = 0 }, counted = {},
  }
  game.forces["player"].chart(w.surface, w.area)
  for _, player in pairs(game.players) do
    player.teleport(w.surface.find_non_colliding_position("character", w.provider.position, 20, 1)
      or w.provider.position, w.surface)
    player.cheat_mode = true
    create_panel(player)
  end
end

--- Ziel einer Lieferung (requester/storage/cleanup) über den Namen der Haltestelle.
local function target_of(delivery)
  for kind, stop in pairs(storage.aktiv.stops) do
    if kind ~= "provider" and stop.valid and stop.backer_name == delivery.to then return kind end
  end
  return nil
end

local function set_label(id, text)
  if id and id.valid then id.text = text end
end

local function tick()
  local a = storage.aktiv
  if not a then return end
  if a.wire and #a.wire > 0 then a.wire = World.wire_outputs(a.wire) end
  local busy, follow = false, nil
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    local kind = target_of(d)
    if kind then
      busy = true
      local train = not follow and game.train_manager.get_train_by_id(d.train_id)
      follow = follow or (train and train.front_stock)
      if a.phase == "running" and not a.counted[d.id] then
        a.counted[d.id] = true
        local amount = 0
        for _, n in pairs(d.manifest) do amount = amount + n end
        a.sent[kind] = a.sent[kind] + amount
        if STEP_OF[kind] > a.step then a.step = STEP_OF[kind] end
      end
    end
  end
  local left = World.count(a.provider_chests)
  if a.phase == "pause" and game.tick >= a.wait_until then
    start_round()
  elseif a.phase == "running" and ((left == 0 and not busy) or game.tick >= a.round_until) then
    a.step, a.phase, a.wait_until = 5, "pause", game.tick + PAUSE
    log(("[AKTIV] Runde %d: Abnehmer %d, Lager %d, Cleanup %d, Rest %d – in den Kisten: Abnehmer %d, Lager %d"):format(
      a.round, a.sent.requester, a.sent.storage, a.sent.cleanup, left, World.count(a.requester_chests),
      World.count(a.storage_chests)))
  end

  -- schwebende Texte über den Haltestellen
  set_label(a.labels.provider, { "utl-aktiv.label-provider", left })
  set_label(a.labels.requester, { "utl-aktiv.label-requester", World.count(a.requester_chests), World.REQUEST })
  set_label(a.labels.storage, { "utl-aktiv.label-storage", World.count(a.storage_chests), World.STORAGE_MIN,
    World.STORAGE_MAX })
  set_label(a.labels.cleanup, { "utl-aktiv.label-cleanup", a.sent.cleanup })

  local steps = {}
  for i, key in ipairs(STEPS) do steps[i] = { "utl-aktiv." .. key } end
  for _, player in pairs(game.connected_players) do
    Explain.update(player, PANEL, {
      headline = { "utl-aktiv.round", a.round },
      steps = steps,
      current = a.step,
      follow = follow or (a.stops.provider.valid and a.stops.provider) or nil,
      big = { "utl-aktiv.left", left },
      note = { "utl-aktiv.sent", a.sent.requester, a.sent.storage, a.sent.cleanup },
    })
  end
end

script.on_configuration_changed(Sandbox.refresh)
script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.aktiv then script.on_nth_tick(1, setup) end
end)
script.on_nth_tick(60, tick)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.aktiv then create_panel(player) end
end)

script.on_event(defines.events.on_gui_click, function(event) Explain.on_click(event) end)
