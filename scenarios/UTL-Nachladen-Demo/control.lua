--- Szenario „UTL-Nachladen“: zeigt, was das Nachladen bringt. Eine Runde läuft so:
---   1. Abnehmer braucht 1000 Eisen
---   2. der Zug fährt mit Ladeliste 1000 los
---   3. unterwegs steigt der Bedarf auf 3000
---   4./5. mit Nachladen: dieselbe Fahrt bringt 3000 – ohne: 1000, der Rest braucht eine 2. Fahrt
---   6. Pause, nächste Runde
--- Die Runden wechseln sich ab (mit/ohne), per Knopf auch „immer an“ oder „immer aus“.
--- Die Kiste des Abnehmers vernichtet alles – damit es sich wie im echten Spiel verhält, senkt das
--- Szenario den Bedarf beim Entladen um das Gelieferte.
local World = require("__UTLogistics__/scenarios/UTL-Nachladen-Demo/world")
local Panel = require("__UTLogistics__/scenarios/UTL-Nachladen-Demo/panel")

local KEY = World.KEY
local FIRST, GROWN = 1000, 3000
local NEXT_MODE = { alternate = "on", on = "off", off = "alternate" }

local function set_request(amount)
  remote.call("utl", "set_request", storage.demo.requester_unit, 1,
    amount and { type = "item", name = "iron-plate" } or nil, amount)
  storage.demo.need = amount or 0
end

local function setup()
  script.on_nth_tick(1, nil)
  game.forces["player"].research_all_technologies()
  local w = World.build()
  storage.demo = {
    requester_unit = w.requester_unit, locomotive = w.locomotive, train_label = w.train_label,
    need_label = w.need_label, mode = "alternate", round = 0, step = 0, need = 0,
    stats = { on_rounds = 0, on_trips = 0, off_rounds = 0, off_trips = 0 }, counted = {},
    phase = "pause", wait_until = game.tick + 300,
  }
  game.forces["player"].chart(w.surface, w.area)
  for _, player in pairs(game.players) do
    player.teleport(w.surface.find_non_colliding_position("character", w.provider.position, 20, 1)
      or w.provider.position, w.surface)
    player.cheat_mode = true
    Panel.create(player)
  end
end

--- Neue Runde: Modus festlegen und Bedarf setzen.
local function start_round()
  local demo = storage.demo
  demo.round = demo.round + 1
  if demo.mode == "alternate" then demo.round_on = demo.round % 2 == 1 else demo.round_on = demo.mode == "on" end
  remote.call("utl", "set_map_config", "utl-top-up", demo.round_on)
  demo.id, demo.first, demo.topped, demo.rest = nil, nil, nil, nil
  set_request(FIRST)
  demo.step = 1
  demo.phase = "wait-train"
end

--- Fahrt zählen, sobald sie beim Abnehmer ankommt (jede Lieferung nur einmal).
local function count_trip(delivery)
  local demo = storage.demo
  if demo.counted[delivery.id] then return end
  demo.counted[delivery.id] = true
  local st = demo.stats
  if demo.round_on then st.on_trips = st.on_trips + 1 else st.off_trips = st.off_trips + 1 end
end

-- Ablauf, einmal pro Sekunde
local function tick()
  local demo = storage.demo
  if not demo then return end
  local mine
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if d.requester == demo.requester_unit then mine = d end
  end
  if mine and mine.state == "unloading" then count_trip(mine) end

  if demo.phase == "pause" and game.tick >= demo.wait_until then
    start_round()
  elseif demo.phase == "wait-train" and mine and (mine.state == "to_provider" or mine.state == "loading") then
    demo.id, demo.first = mine.id, mine.manifest[KEY] or 0
    demo.step = 2
    demo.phase = "raise"
    demo.wait_until = game.tick + 180 -- Schritt 2 kurz stehen lassen
  elseif demo.phase == "raise" and (game.tick >= demo.wait_until or (mine and mine.state == "loading")) then
    set_request(GROWN)
    demo.step = 3
    demo.phase = "watch"
  elseif demo.phase == "watch" then
    local now = mine and mine.id == demo.id and mine.manifest[KEY] or nil
    if now and now > demo.first then
      demo.topped, demo.step, demo.phase = true, 4, "to-unload"
    elseif (mine and mine.id == demo.id and mine.state == "to_requester") or not mine then
      demo.topped, demo.step, demo.phase = false, 4, "to-unload"
    end
  elseif demo.phase == "to-unload" and mine and mine.id == demo.id and mine.state == "unloading" then
    if demo.topped then
      set_request(nil)
    else
      demo.rest = GROWN - demo.first
      set_request(demo.rest)
    end
    demo.step = 5
    demo.phase = "rest"
  elseif demo.phase == "rest" then
    if mine and mine.id ~= demo.id and mine.state == "unloading" then
      set_request(nil) -- die zweite Fahrt ist da, der Bedarf ist gedeckt
    elseif not mine then
      local st = demo.stats
      if demo.round_on then st.on_rounds = st.on_rounds + 1 else st.off_rounds = st.off_rounds + 1 end
      demo.step = 6
      demo.phase = "pause"
      demo.wait_until = game.tick + 600
    end
  end

  -- schwebende Texte
  if mine and mine.manifest[KEY] then
    demo.cargo = mine.manifest[KEY]
    local extra = demo.first and demo.cargo > demo.first and mine.id == demo.id and (demo.cargo - demo.first) or nil
    local second = demo.id and mine.id ~= demo.id
    if demo.train_label and demo.train_label.valid then
      demo.train_label.text = extra and { "utl-demo.train-topped", demo.cargo, extra }
        or second and { "utl-demo.train-second", demo.cargo }
        or { "utl-demo.train-cargo", demo.cargo }
      demo.train_label.color = extra and { 0.4, 1, 0.4 } or second and { 1, 0.8, 0.3 } or { 1, 1, 1 }
    end
  else
    demo.cargo = nil
    if demo.train_label and demo.train_label.valid then
      demo.train_label.text = { "utl-demo.train-idle" }
      demo.train_label.color = { 1, 1, 1 }
    end
  end
  if demo.need_label and demo.need_label.valid then demo.need_label.text = { "utl-demo.need", demo.need } end
  Panel.refresh_all()
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.demo then script.on_nth_tick(1, setup) end
end)
script.on_nth_tick(60, tick)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player and storage.demo then Panel.create(player) end
end)

script.on_event(defines.events.on_gui_click, function(event)
  if event.element.valid and event.element.name == Panel.MODE_BUTTON and storage.demo then
    storage.demo.mode = NEXT_MODE[storage.demo.mode] or "alternate"
    Panel.refresh_all()
  end
end)
