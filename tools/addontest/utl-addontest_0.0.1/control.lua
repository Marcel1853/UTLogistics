--- Test-Add-on für die UTL-Schnittstelle (nur zum Ausprobieren, wird nicht veröffentlicht).
--- Zeigt die sichtbaren Teile: eigene Rollen im Stationsfenster, eigener Abschnitt mit Daten je
--- Station, eigener Reiter im Manager, Aufträge (Rangierlok pendelt zum Abstellgleis), Zugfilter.
local Shunting = require("shunting")
local Yard = require("yard")
local MOD = "utl-addontest"
local KEY = { depot = MOD .. "/depot", siding = MOD .. "/siding", bay = MOD .. "/bay" }

local function note(text)
  storage.log = storage.log or {}
  table.insert(storage.log, 1, "[" .. math.floor(game.tick / 60) .. " s] " .. text)
  storage.log[13] = nil
  log("[ADDONTEST] " .. text)
end
Shunting.note = note
Yard.note = note

-- ── Rückrufe für UTL ────────────────────────────────────────────────────────────────────────
remote.add_interface(MOD, {
  --- Testkarte: Wagen und Halte für die Rangier-Vorführung
  setup = function(spec) Shunting.setup(spec) end,
  --- Testkarte „rangieren“: Bahnhof aus Marcels Blaupause erkennen
  setup_yard = function(surface_index) Yard.setup(surface_index) end,

  --- Abschnitt im Stationsfenster: nur an Stationen mit einer Rolle dieses Add-ons
  section = function(flow, unit)
    local info = remote.call("utl", "get_station", unit) --[[@as table?]]
    local role = info and info.config.addon_role
    if not (role and role:sub(1, #MOD) == MOD) then return end
    local data = remote.call("utl", "get_station_data", unit, MOD) or {} --[[@as table]]
    flow.add({ type = "line" })
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addontest.section" } })
    local row = flow.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    row.add({ type = "label", caption = { "utl-addontest.tracks", data.tracks or 0 }, name = "tracks" })
    row.add({ type = "button", caption = "−", style = "mini_button", tags = { addontest = "minus", unit = unit } })
    row.add({ type = "button", caption = "+", style = "mini_button", tags = { addontest = "plus", unit = unit } })
  end,

  --- Reiter im Manager
  tab = function(flow)
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addontest.stations" } })
    for _, key in pairs(KEY) do
      for _, s in ipairs(remote.call("utl", "get_stations", { addon_role = key })) do
        local data = remote.call("utl", "get_station_data", s.unit, MOD) or {} --[[@as table]]
        flow.add({ type = "label", caption = "• " .. (s.stop_name or "?") .. " – " .. key
          .. (data.tracks and ("  (Gleise " .. data.tracks .. ")") or "") })
      end
    end
    flow.add({ type = "line" })
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addontest.jobs" } })
    for id in pairs(storage.jobs or {}) do
      local job = remote.call("utl", "get_job", id) --[[@as table?]]
      if job then flow.add({ type = "label", caption = "• Auftrag " .. id .. ": Zug " .. job.train_id .. ", " .. job.stops .. " Halt(e)" }) end
    end
    flow.add({ type = "label", caption = { "utl-addontest.filter", storage.filter_calls or 0 } })
    flow.add({ type = "line" })
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addontest.events" } })
    for _, line in ipairs(storage.log or {}) do flow.add({ type = "label", caption = line }) end
  end,

  --- Zugfilter: lässt alle Züge zu, zählt nur mit
  filter = function(ids)
    storage.filter_calls = (storage.filter_calls or 0) + 1
    return ids
  end,
})

local function register()
  local r = function(spec) return remote.call("utl", "register_role", spec) end
  r({ mod = MOD, name = "depot", caption = { "utl-addontest.depot" }, tooltip = { "utl-addontest.depot-tooltip" },
    base = "depot", own_trains = true })
  r({ mod = MOD, name = "siding", caption = { "utl-addontest.siding" }, tooltip = { "utl-addontest.siding-tooltip" } })
  r({ mod = MOD, name = "bay", caption = { "utl-addontest.bay" }, tooltip = { "utl-addontest.bay-tooltip" },
    base = "provider" })
  remote.call("utl", "register_gui_section", { mod = MOD, interface = MOD, build = "section" })
  remote.call("utl", "register_manager_tab", { mod = MOD, interface = MOD, build = "tab", caption = { "utl-addontest.tab" } })
  remote.call("utl", "register_train_filter", { mod = MOD, interface = MOD, filter = "filter" })
end

-- ── Ereignisse von UTL ──────────────────────────────────────────────────────────────────────
local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  -- Rangierlok frei im Rangierdepot: nach 3 s den Wagen holen (shunting.lua)
  script.on_event(ids.on_train_idle, function(event) ---@param event table
    if event.role ~= KEY.depot then return end
    note("frei im Rangierdepot: Zug " .. event.train_id)
    storage.waiting = storage.waiting or {}
    storage.waiting[event.train_id] = game.tick + 180
  end)
  script.on_event(ids.on_job_finished, function(event) ---@param event table
    if event.mod ~= MOD then return end
    if storage.jobs then storage.jobs[event.job_id] = nil end
    note("Auftrag " .. event.job_id .. (event.canceled and (" abgebrochen: " .. tostring(event.reason)) or " fertig"))
  end)
  script.on_event(ids.on_train_arrived, function(event) ---@param event table
    note("Ankunft: Zug " .. event.train_id .. " an „" .. (event.stop and event.stop.backer_name or "?") .. "“"
      .. (event.job_id and (" (Auftrag " .. event.job_id .. ")") or "") .. (event.delivery_id and (" (Lieferung " .. event.delivery_id .. ")") or ""))
    if not Yard.arrived(event) then Shunting.arrived(event) end
  end)
  -- Normale Lieferung von der Ladebucht: Laden und Entladen spielt das Script (keine Greifarme nötig)
  script.on_event(ids.on_delivery_state_changed, function(event) ---@param event table
    local train = event.train
    if not (train and train.valid) then return end
    if event.state == "loading" then
      for key, amount in pairs(event.manifest) do
        local name = key:match("^item|([^|]+)|")
        if name then train.insert({ name = name, count = amount }) end
      end
    elseif event.state == "unloading" then
      train.clear_items_inside()
    end
  end)
end

script.on_init(function()
  register()
  listen()
end)
script.on_configuration_changed(register)
script.on_load(listen)

-- Wartende Rangierloks losschicken, Heranschieben beim Kuppeln
script.on_nth_tick(60, function()
  for train_id, tick in pairs(storage.waiting or {}) do
    if game.tick >= tick then
      storage.waiting[train_id] = nil
      local train = game.train_manager.get_train_by_id(train_id)
      if train and not Yard.idle(train) then Shunting.idle(train) end
    end
  end
end)
script.on_nth_tick(5, function()
  Shunting.tick()
  Yard.tick()
end)

-- +/− im eigenen Abschnitt des Stationsfensters
script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  local tags = element.valid and element.tags
  if not (tags and tags.addontest) then return end
  local data = remote.call("utl", "get_station_data", tags.unit, MOD) or {} --[[@as table]]
  local tracks = math.max(0, (data.tracks or 0) + (tags.addontest == "plus" and 1 or -1))
  remote.call("utl", "set_station_data", tags.unit, MOD, "tracks", tracks)
  local label = element.parent.tracks
  if label then label.caption = { "utl-addontest.tracks", tracks } end
end)
