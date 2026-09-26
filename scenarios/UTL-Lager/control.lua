--- Szenario „UTL-Lager“: zeigt die drei Neuerungen aus 0.0.8 auf einem Rundkurs mit zwei Zügen –
--- Lager (Mindest/Höchst), Wende-Greifarm und „Cleanup gibt zurück“. Alles läuft gleichzeitig; das
--- Erklärfenster schaut jeweils auf einen Teil, ein Knopf wechselt zum nächsten.
--- Gesteuert wird nur die Kupfer-Werkstatt A: Damit am Cleanup Reste ankommen, füllt das Szenario
--- ihre Kiste auf, während ein Zug zu ihr unterwegs ist (das Fenster sagt das auch), und leert sie
--- 20 s nach der Abfahrt wieder – die Werkstatt „verbraucht“ ihr Kupfer.
local World = require("__UTLogistics__/scenarios/UTL-Lager/world")
local Panel = require("__UTLogistics__/scenarios/UTL-Lager/panel")

local K = {
  provider = "65/3", workshop = "115/3", cleanup = "115/19", storage = "79/83",
  factory = "33/83", copper_a = "33/99", copper_b = "83/99",
}

local function place(player)
  local st = storage.lager
  if not st then return end
  local surface = st.made.surface
  player.teleport(surface.find_non_colliding_position("character", st.made.start, 20, 1) or st.made.start, surface)
  player.cheat_mode = true
  Panel.create(player)
end

local function setup()
  script.on_nth_tick(1, nil)
  local force = game.forces["player"]
  force.research_all_technologies()
  for name, value in pairs({ ["utl-storage"] = true, ["utl-cleanup-offer"] = true, ["utl-timeout-mode"] = "or",
    ["utl-load-timeout"] = 10, ["utl-unload-timeout"] = 5 }) do
    remote.call("utl", "set_map_config", name, value)
  end
  local made = World.build()
  storage.lager = {
    made = made, chapter = 1, wired = false, provoked = {}, seen = {}, at_cleanup = {},
    counts = { into = 0, out = 0, workshop = 0, rest = 0, returned = 0, flips = 0 },
    base_dir = made.bays.storage.inserters[1].direction,
  }
  storage.lager.last_dir = storage.lager.base_dir
  force.chart(made.surface, made.area)
  log("[LAGER] gebaut")
  for _, player in pairs(game.players) do place(player) end
end

--- Während ein Zug Kupfer vom Anbieter zur Kupfer-Werkstatt A bringt: ihre Kiste so weit füllen,
--- dass nur die Hälfte der Ladung hineinpasst. Nur solange der Cleanup wenig Kupfer hat.
local function provoke_rest(st, d)
  local u = st.made.units
  if d.requester ~= u[K.copper_a] or d.provider ~= u[K.provider] or d.state ~= "to_requester" or st.provoked[d.id] then return end
  st.provoked[d.id] = true
  if World.stock(st.made.bays.cleanup, "copper-plate") >= 200 then return end
  local bay = st.made.bays.copper_a
  local load = d.manifest[World.COPPER] or 0
  local fill = World.COPPER_A - World.stock(bay, "copper-plate") - math.floor(load / 2)
  if fill > 0 and bay.chests[1].valid then
    bay.chests[1].insert({ name = "copper-plate", count = fill })
    st.filled = d.id
  end
end

local function front(train_id)
  local train = train_id and game.train_manager.get_train_by_id(train_id)
  return train and train.valid and train.front_stock or nil
end

--- Kiste der Kupfer-Werkstatt A leeren, 20 s nachdem kein Zug mehr für sie fährt.
local function consume_a(st, active)
  local chest = st.made.bays.copper_a.chests[1]
  if active or not chest.valid or chest.get_item_count("copper-plate") == 0 then
    st.clear_a = nil
  elseif not st.clear_a then
    st.clear_a = game.tick + 20 * 60
  elseif game.tick >= st.clear_a then
    chest.clear_items_inside()
    st.clear_a = nil
  end
end

-- Einmal pro Sekunde: Ausgaben verdrahten, Lieferungen einordnen, Fenster füttern
local function tick()
  local st = storage.lager
  if not st then return end
  local made, u = st.made, st.made.units
  if not st.wired then st.wired = World.wire(made) end

  local by = {}
  for _, d in pairs(remote.call("utl", "get_deliveries") --[[@as table]]) do
    provoke_rest(st, d)
    local kind = d.requester == u[K.storage] and "into"
      or d.provider == u[K.storage] and "out"
      or d.provider == u[K.cleanup] and "returned"
      or (d.provider == u[K.provider] and d.requester == u[K.workshop]) and "workshop"
      or d.requester == u[K.copper_a] and "copper_a"
      or nil
    if kind then
      by[kind] = d
      if not st.seen[d.id] and st.counts[kind] then
        st.seen[d.id] = true
        st.counts[kind] = st.counts[kind] + 1
        if st.counts[kind] == 1 then log(("[LAGER] erstes %s: %s -> %s nach %d s"):format(kind, d.from, d.to, math.floor(game.tick / 60))) end
      end
    end
  end

  consume_a(st, by.copper_a ~= nil)

  -- Züge mit Rest am Cleanup (Leeren ist kein Auftrag, also an der Haltestelle erkennen)
  local rest_train
  for _, train in pairs(made.trains) do
    if train.valid then
      local here = train.station and train.station.valid and train.station.backer_name == "Cleanup"
      local loading = by.returned and by.returned.train_id == train.id
      if here and not loading then
        rest_train = train
        if not st.at_cleanup[train.id] then
          st.at_cleanup[train.id] = true
          st.counts.rest = st.counts.rest + 1
          if st.counts.rest == 1 then log(("[LAGER] erster Rest am Cleanup nach %d s"):format(math.floor(game.tick / 60))) end
        end
      elseif not here then
        st.at_cleanup[train.id] = nil
      end
    end
  end

  local rev = made.bays.storage.inserters[1]
  local flipped = rev.valid and rev.direction ~= st.base_dir
  if rev.valid and rev.direction ~= st.last_dir then
    st.last_dir = rev.direction
    st.counts.flips = st.counts.flips + 1
  end

  Panel.refresh_all({
    out_to_workshop = by.out ~= nil and by.out.requester == u[K.workshop],
    by = by, rest_train = rest_train and rest_train.front_stock, flipped = flipped, counts = st.counts,
    front = front, filled = st.filled,
    storage_stock = World.stock(made.bays.storage, "iron-plate"),
    cleanup_stock = World.stock(made.bays.cleanup, "copper-plate"),
    stops = { storage = made.stops[K.storage], cleanup = made.stops[K.cleanup] },
    revs = { storage = rev, cleanup = made.bays.cleanup.inserters[1] },
  })
end

script.on_init(function() script.on_nth_tick(1, setup) end)
script.on_load(function()
  if not storage.lager then script.on_nth_tick(1, setup) end
end)
script.on_nth_tick(60, tick)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)

script.on_event(defines.events.on_gui_click, function(event)
  if storage.lager and Panel.on_click(event) then
    storage.lager.chapter = storage.lager.chapter % 3 + 1
    Panel.refresh_all()
  end
end)
