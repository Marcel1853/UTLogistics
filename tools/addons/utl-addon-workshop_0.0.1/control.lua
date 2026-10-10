--- Test-Add-on „Werkstatt“: steuert Züge. Macht zwei Depot-Gleise zu Werkstätten (eigene Rolle ohne
--- Grundrolle). Hat ein Zug 2 Lieferungen geschafft und steht frei im Depot, schickt es ihn per Auftrag
--- (send_job) 10 s in die Werkstatt; danach fährt er von selbst zurück. Jede 7. neue Lieferung bekommt einen
--- Durchfahrts-Wegpunkt per Position (add_delivery_stop) – am Gleis des Anbieters, ändert den Weg nicht.
--- Absagen von UTL (Werkstatt voll, Zug gehört einem anderen Add-on …) werden gezählt.
local MOD = "utl-addon-workshop"
local ROLE = MOD .. "/workshop"
local SERVICE_EVERY = 2

local function stat(name)
  storage.stat = storage.stat or {}
  storage.stat[name] = (storage.stat[name] or 0) + 1
end

remote.add_interface(MOD, {
  section = function(flow, unit)
    local info = remote.call("utl", "get_station", unit) --[[@as table?]]
    if not (info and info.config.addon_role == ROLE) then return end
    local data = remote.call("utl", "get_station_data", unit, MOD) or {} --[[@as table]]
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addon-workshop.section" } })
    flow.add({ type = "label", caption = { "utl-addon-workshop.services", data.services or 0 } })
  end,
})

local function register()
  remote.call("utl", "register_role", { mod = MOD, name = "workshop", caption = { "utl-addon-workshop.role" },
    tooltip = { "utl-addon-workshop.role-tooltip" } })
  remote.call("utl", "register_gui_section", { mod = MOD, interface = MOD, build = "section" })
end

--- Zwei Depots (aus verschiedenen Netzen, wenn möglich) zu Werkstätten machen – erst wenn die Karte steht.
local function setup()
  -- bis zwei freie Gleise gefunden sind (beim Start stehen oft überall Züge)
  if storage.workshops and #storage.workshops >= 2 then return end
  local depots = remote.call("utl", "get_stations", { role = "depot" }) --[[@as table]]
  if #depots < 4 then return end
  storage.workshops = storage.workshops or {}
  local before = #storage.workshops
  local used = {}
  for _, unit in ipairs(storage.workshops) do used[unit] = true end
  for _, d in ipairs(depots) do
    -- nur leere Gleise: ein dort geparkter Zug bliebe stehen und die Werkstatt wäre dauernd voll
    local stop = d.stop and game.get_entity_by_unit_number(d.stop)
    local empty = stop and stop.valid and stop.trains_count == 0
    if empty and #storage.workshops < 2 and not used[d.network] and not used[d.unit] then
      if remote.call("utl", "set_station_role", d.unit, ROLE) then
        storage.workshops[#storage.workshops + 1] = d.unit
        used[d.network] = true
      end
    end
  end
  -- Zuordnung Station → Haltestelle einmal aufbauen (danach über on_station_created ergänzt)
  if #storage.workshops ~= before then log("[ADDON-WORKSHOP] Werkstätten: " .. serpent.line(storage.workshops)) end
  if storage.stop_of then return end
  storage.stop_of = {}
  for _, st in ipairs(remote.call("utl", "get_stations") --[[@as table]]) do storage.stop_of[st.unit] = st.stop end
end

local function send_to_workshop(train_id)
  for _, unit in ipairs(storage.workshops or {}) do
    local id, why = remote.call("utl", "send_job", train_id, MOD, { { station = unit, wait = { { type = "time", ticks = 600 } } } })
    if id then
      storage.jobs = storage.jobs or {}
      storage.jobs[id] = unit
      stat("auftrag-gesendet")
      return true
    end
    stat("absage:" .. tostring(why))
  end
  return false
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_delivery_completed, function(event) ---@param event table
    storage.done = storage.done or {}
    storage.done[event.train_id] = (storage.done[event.train_id] or 0) + 1
  end)
  script.on_event(ids.on_train_idle, function(event) ---@param event table
    if event.role then return end -- Depot eines Add-ons: nicht unsere Sache
    local done = storage.done and storage.done[event.train_id] or 0
    if done >= SERVICE_EVERY and send_to_workshop(event.train_id) then storage.done[event.train_id] = 0 end
  end)
  script.on_event(ids.on_job_finished, function(event) ---@param event table
    if event.mod ~= MOD then return end
    local unit = storage.jobs and storage.jobs[event.job_id]
    if storage.jobs then storage.jobs[event.job_id] = nil end
    if event.canceled then
      stat("auftrag-abgebrochen:" .. tostring(event.reason))
      return
    end
    stat("auftrag-fertig")
    if unit then
      local data = remote.call("utl", "get_station_data", unit, MOD) or {} --[[@as table]]
      remote.call("utl", "set_station_data", unit, MOD, "services", (data.services or 0) + 1)
    end
  end)
  script.on_event(ids.on_station_created, function(event) ---@param event table
    if storage.stop_of and event.stop then storage.stop_of[event.station] = event.stop.unit_number end
  end)
  script.on_event(ids.on_delivery_created, function(event) ---@param event table
    storage.created = (storage.created or 0) + 1
    if storage.created % 7 ~= 0 then return end
    -- Gleis vor dem Anbieter als Durchfahrts-Wegpunkt (ohne Warten); Haltestelle aus der Zuordnung
    local stop_unit = storage.stop_of and storage.stop_of[event.provider]
    local stop = stop_unit and game.get_entity_by_unit_number(stop_unit)
    local rail = stop and stop.valid and stop.connected_rail
    if not rail then return end
    local profiler = helpers.create_profiler()
    local ok, why = remote.call("utl", "add_delivery_stop", event.id, { where = "before_provider", position = rail.position })
    profiler.stop()
    if storage.created % 35 == 0 then log({ "", "[ADDON-ZEIT] add_delivery_stop: ", profiler }) end
    stat(ok and "wegpunkt-eingefügt" or ("wegpunkt-absage:" .. tostring(why)))
  end)
end

script.on_init(function()
  register()
  listen()
end)
script.on_configuration_changed(register)
script.on_load(listen)

script.on_nth_tick(600, function() setup() end)

script.on_nth_tick(3600, function(event)
  log("[ADDON-WORKSHOP] min " .. event.tick / 3600 .. ": " .. serpent.line(storage.stat or {}))
end)
