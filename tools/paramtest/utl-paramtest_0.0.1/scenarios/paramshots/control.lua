--- Bilder-Strecke (nur mit Grafik, tools/paramtest.sh paramshots): neue Fenster der Parameter-Arbeit
--- fotografieren – Stationspanel mit Positions-Pfeilen, Lager mit zwei Spalten, Tankstelle „Treibstoff
--- anfordern“, Parameter-Abfrage mit allen drei Reitern. Bilder: script-output/utl/param-NN-name.png
local W = defines.wire_connector_id
local STEP = 90
local R = { 1920, 1080 }
local ASK = { "role", "network", "fuel_request", "request", "min_train_length", "max_train_length", "max_trains",
  "provide_threshold", "provide_stack_threshold", "provide_priority", "locked_slots", "filter_load",
  "request_threshold", "request_stack_threshold", "request_priority", "depot_priority", "cleanup_all_items",
  "cleanup_all_fluids", "cleanup_offer", "cleanup_wares", "storage_limits", "storage_leftover", "output" }

local function L(text) log("[SHOTS] " .. text) end
local function player() return game.get_player(1) end

local function shot(name)
  storage.n = (storage.n or 0) + 1
  local p = player()
  local path = ("utl/param-%02d-%s.png"):format(storage.n, name)
  game.take_screenshot({ player = p, by_player = p, path = path, resolution = R, show_gui = true,
    anti_alias = true, quality = 90, zoom = 1 })
  L(path)
end

local function stop_at(s, force, name, y, cfg, request)
  for x = -15, 15, 2 do s.create_entity({ name = "straight-rail", position = { x, y }, direction = 4, force = force }) end
  local stop = s.create_entity({ name = "utl-train-stop", position = { 0, y + 2 }, direction = 4, force = force, raise_built = true })
  if not stop then return nil end
  stop.backer_name = name
  remote.call("utl", "configure_station", stop.unit_number, cfg)
  if request then remote.call("utl", "set_request", stop.unit_number, 1, request.signal, request.count) end
  return stop
end

local function setup()
  local s = game.create_surface("ps")
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies()
  local st = {}
  st.req = stop_at(s, force, "Abnehmer", 1, { mode = "station", provide = true, request = true, request_threshold = 500 },
    { signal = { type = "item", name = "iron-plate" }, count = 4000 })
  st.fuel = stop_at(s, force, "Tankstelle", 21, { mode = "fuel", fuel_request = true, request_threshold = 50 },
    { signal = { type = "item", name = "coal" }, count = 200 })
  st.store = stop_at(s, force, "Lager", 41, { mode = "storage", storage = { accept_leftover = true, limits = {
    { signal = { type = "item", name = "iron-plate" }, min = 400, max = 1200 },
    { signal = { type = "item", name = "copper-plate" }, min = 400, max = 1200 },
    { signal = { type = "item", name = "steel-plate" }, min = 100, max = 400 } } } })
  storage.st = st
  storage.step, storage.next = 1, game.tick + 120
  local p = player()
  if p then
    p.teleport({ 0, 10 }, s)
    p.cheat_mode = true
  end
end

local function open(stop)
  local p = player()
  p.teleport({ stop.position.x, stop.position.y + 6 }, stop.surface)
  p.opened = stop
end

--- Reiter des UTL-Panels (Haltestelle) bzw. des Abfrage-Fensters wählen.
local function select_tab(root, name, index)
  local frame = root[name]
  if not frame then return end
  local function find(el)
    if el.type == "tabbed-pane" then return el end
    for _, child in pairs(el.children) do
      local hit = find(child)
      if hit then return hit end
    end
  end
  local pane = find(frame)
  if not pane then return end
  pane.selected_tab_index = index
  local content = pane.parent.content -- Abfrage-Fenster: Inhalte stehen unter den Reitern
  if content then
    for i, page in ipairs(content.children) do page.visible = i == index end
  end
end

--- Parameter-Blaupause wie aus dem Planer: Tags `utl_ask` an der Station, dann als Spieler bauen.
local function place_parameter_blueprint()
  local p = player()
  local st = storage.st
  local inv = game.create_inventory(1)
  inv.insert({ name = "blueprint" })
  local s = st.req.surface
  local mapping = inv[1].create_blueprint({ surface = s, force = p.force, area = { { -16, -1 }, { 16, 6 } } })
  remote.call("utl", "tag_blueprint", inv[1], mapping, s)
  for index, entity in pairs(mapping) do
    if entity.valid and entity.name == "utl-train-stop" then inv[1].set_blueprint_entity_tag(index, "utl_ask", ASK) end
  end
  p.teleport({ 0, 68 }, s)
  inv[1].build_blueprint({ surface = s, force = p.force, position = { 0, 64 }, by_player = p,
    build_mode = defines.build_mode.forced })
  inv.destroy()
end

local STEPS = {
  function() open(storage.st.req) end,
  function() shot("station-panel-pfeile") end,
  function() player().opened = nil; open(storage.st.store) end,
  function() shot("lager-zwei-spalten") end,
  function() player().opened = nil; open(storage.st.fuel) end,
  function() select_tab(player().gui.relative, "utl_station_window", 2) end,
  function() shot("tankstelle-treibstoff") end,
  function() player().opened = nil; place_parameter_blueprint() end,
  function() shot("parameter-allgemein") end,
  function() select_tab(player().gui.screen, "utl_param_ask", 2) end,
  function() shot("parameter-waren") end,
  function() select_tab(player().gui.screen, "utl_param_ask", 3) end,
  function() shot("parameter-werte") end,
  function() L("fertig") end,
}

script.on_event(defines.events.on_player_created, function()
  if not storage.st then setup() end
end)

script.on_nth_tick(30, function()
  if not storage.step or game.tick < storage.next then return end
  local fn = STEPS[storage.step]
  if not fn then return end
  local ok, err = pcall(fn)
  if not ok then L("Fehler in Schritt " .. storage.step .. ": " .. tostring(err)) end
  storage.step = storage.step + 1
  storage.next = game.tick + STEP
end)
