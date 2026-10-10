--- Test-Add-on „Statistik“: steuert keine Züge, beobachtet nur. Zählt alle UTL-Ereignisse, merkt sich je
--- Station die Ankünfte (Daten je Station) und zeigt alles in einem eigenen Reiter im UTL-Manager und in
--- einem Abschnitt im Stationsfenster. Jede Minute eine Zeile „[ADDON-STATS]“ im Log.
local MOD = "utl-addon-stats"

local function counts()
  storage.counts = storage.counts or {}
  return storage.counts
end

local function bump(name, by)
  local c = counts()
  c[name] = (c[name] or 0) + (by or 1)
end

remote.add_interface(MOD, {
  --- Reiter im Manager: alle Zähler, die zehn Stationen mit den meisten Ankünften
  tab = function(flow)
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addon-stats.events" } })
    local names = {}
    for name in pairs(counts()) do names[#names + 1] = name end
    table.sort(names)
    local grid = flow.add({ type = "table", column_count = 4 })
    for _, name in ipairs(names) do
      grid.add({ type = "label", caption = name })
      grid.add({ type = "label", caption = tostring(counts()[name]) })
    end
    flow.add({ type = "line" })
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addon-stats.top" } })
    local list = {}
    for unit, n in pairs(storage.arrivals or {}) do list[#list + 1] = { unit = unit, n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    for i = 1, math.min(10, #list) do
      local info = remote.call("utl", "get_station", list[i].unit) --[[@as table?]]
      flow.add({ type = "label", caption = (info and info.stop_name or "?") .. ": " .. list[i].n })
    end
  end,

  --- Abschnitt im Stationsfenster: Ankünfte dieser Station
  section = function(flow, unit)
    local data = remote.call("utl", "get_station_data", unit, MOD) --[[@as table?]]
    if not data then return end
    flow.add({ type = "label", style = "caption_label", caption = { "utl-addon-stats.section" } })
    flow.add({ type = "label", caption = { "utl-addon-stats.arrivals", data.arrivals or 0 } })
  end,
})

local function register()
  remote.call("utl", "register_manager_tab", { mod = MOD, interface = MOD, build = "tab", caption = { "utl-addon-stats.tab" } })
  remote.call("utl", "register_gui_section", { mod = MOD, interface = MOD, build = "section" })
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  for name, id in pairs(ids) do
    script.on_event(id, function(event) ---@param event table
      bump(name)
      if name == "on_delivery_canceled" then bump("abbruch:" .. tostring(event.reason)) end
      if name == "on_alert" then bump("warnung:" .. tostring(event.group)) end
      if name == "on_train_arrived" and event.station then
        storage.arrivals = storage.arrivals or {}
        local n = (storage.arrivals[event.station] or 0) + 1
        storage.arrivals[event.station] = n
        -- Daten je Station nur alle 10 Ankünfte schreiben (wenig Aufwand je Ereignis)
        if n % 10 == 0 then remote.call("utl", "set_station_data", event.station, MOD, "arrivals", n) end
      end
    end)
  end
end

script.on_init(function()
  register()
  listen()
end)
script.on_configuration_changed(register)
script.on_load(listen)

script.on_nth_tick(3600, function(event)
  local c = counts()
  local parts = {}
  for _, name in ipairs({ "on_delivery_created", "on_delivery_completed", "on_delivery_canceled", "on_train_arrived",
    "on_train_idle", "on_job_finished", "on_alert", "on_request_unserved", "on_station_changed", "on_train_rebuilt" }) do
    parts[#parts + 1] = name:gsub("^on_", "") .. "=" .. (c[name] or 0)
  end
  log("[ADDON-STATS] min " .. event.tick / 3600 .. ": " .. table.concat(parts, " "))
end)
