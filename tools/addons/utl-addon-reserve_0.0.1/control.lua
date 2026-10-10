--- Test-Add-on „Reserve & Eilaufträge“: steuert Züge.
---   * Reserve: hält bis zu 6 freie UTL-Züge zurück (hold_train). Meldet UTL eine Anfrage ohne Zug
---     (on_request_unserved), gibt es einen davon frei (release_train, höchstens alle 30 s). Alle 3 Minuten
---     wird die Reserve wieder aufgefüllt.
---   * Eilaufträge: alle 2 Minuten eine normale UTL-Lieferung per create_delivery für einen Abnehmer.
---   * Eil-Abnehmer: drei Abnehmer bekommen die Rolle „Eil-Abnehmer“ (Grundrolle Abnehmer); für Fahrten
---     dorthin redet ein Zugfilter mit (bevorzugt Züge mit gerader ID – nur um die Reihenfolge zu ändern).
--- Nimmt dabei nie Züge, die einem anderen Add-on gehören (UTL sagt dann nein) – gezählt als „fremd“.
local MOD = "utl-addon-reserve"
local ROLE = MOD .. "/express"
local RESERVE = 6

local function stat(name)
  storage.stat = storage.stat or {}
  storage.stat[name] = (storage.stat[name] or 0) + 1
end

remote.add_interface(MOD, {
  filter = function(ids)
    stat("filter-aufruf")
    local even, odd = {}, {}
    for _, id in ipairs(ids) do
      if id % 2 == 0 then even[#even + 1] = id else odd[#odd + 1] = id end
    end
    for _, id in ipairs(odd) do even[#even + 1] = id end
    return even
  end,
})

local function register()
  remote.call("utl", "register_role", { mod = MOD, name = "express", caption = { "utl-addon-reserve.role" },
    tooltip = { "utl-addon-reserve.role-tooltip" }, base = "requester" })
  remote.call("utl", "register_train_filter", { mod = MOD, interface = MOD, filter = "filter" })
end

--- Reserve auffüllen: freie UTL-Züge festhalten.
local function refill()
  storage.reserve = storage.reserve or {}
  local count = 0
  for id in pairs(storage.reserve) do
    if remote.call("utl", "is_held", id) == MOD then count = count + 1 else storage.reserve[id] = nil end
  end
  if count >= RESERVE then return end
  for _, t in ipairs(remote.call("utl", "get_idle_trains") --[[@as table]]) do
    if count >= RESERVE then break end
    if remote.call("utl", "hold_train", t.id, MOD) then
      storage.reserve[t.id] = true
      count = count + 1
      stat("reserve-festgehalten")
    else
      stat("reserve-fremd")
    end
  end
end

--- Einmal, wenn die Karte steht: drei Abnehmer zu Eil-Abnehmern machen.
local function setup()
  if storage.ready then return end
  local requesters = remote.call("utl", "get_stations", { role = "requester" }) --[[@as table]]
  if #requesters < 10 then return end
  storage.ready = true
  storage.requesters = {}
  for i, r in ipairs(requesters) do
    storage.requesters[#storage.requesters + 1] = r.unit
    if i % 10 == 0 and i <= 30 then
      if remote.call("utl", "set_station_role", r.unit, ROLE) then stat("eil-abnehmer") end
    end
  end
  log("[ADDON-RESERVE] bereit: " .. #storage.requesters .. " Abnehmer")
end

--- Eilauftrag: nächster Abnehmer der Reihe, passender Anbieter mit genug Ware.
local function express()
  local whole = helpers.create_profiler()
  local list = storage.requesters
  if not (list and list[1]) then return end
  storage.next = (storage.next or 0) % #list + 1
  local requester = remote.call("utl", "get_station", list[storage.next]) --[[@as table?]]
  if not requester then return end
  local slot = requester.config.requests and requester.config.requests[1]
  local signal = slot and slot.signal
  if not signal then return end
  local key = (signal.type or "item") .. "|" .. signal.name .. "|" .. (signal.quality or "normal")
  for _, p in ipairs(remote.call("utl", "get_stations", { role = "provider", network = requester.config.network }) --[[@as table]]) do
    local info = remote.call("utl", "get_station", p.unit) --[[@as table?]]
    if info and (info.provide[key] or 0) >= 1000 then
      local profiler = helpers.create_profiler()
      local id, why = remote.call("utl", "create_delivery", { provider = p.unit, requester = requester.unit,
        type = signal.type, name = signal.name, quality = signal.quality, amount = 1000 })
      profiler.stop()
      log({ "", "[ADDON-ZEIT] create_delivery: ", profiler })
      stat(id and "eilauftrag" or ("eilauftrag-absage:" .. tostring(why)))
      whole.stop()
      log({ "", "[ADDON-ZEIT] Eilauftrag gesamt: ", whole })
      return
    end
  end
  stat("eilauftrag-kein-anbieter")
  whole.stop()
  log({ "", "[ADDON-ZEIT] Eilauftrag gesamt (ohne Anbieter): ", whole })
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_request_unserved, function()
    stat("anfrage-ohne-zug")
    if game.tick - (storage.last_release or -1e9) < 1800 then return end
    for id in pairs(storage.reserve or {}) do
      storage.reserve[id] = nil
      if remote.call("utl", "release_train", id) then
        storage.last_release = game.tick
        stat("reserve-freigegeben")
        return
      end
    end
  end)
end

script.on_init(function()
  register()
  listen()
end)
script.on_configuration_changed(register)
script.on_load(listen)

script.on_nth_tick(600, function(event)
  setup()
  if not storage.ready then return end
  if event.tick % 10800 == 0 then refill() end -- alle 3 Minuten
  if event.tick % 7200 == 0 then express() end -- alle 2 Minuten
end)

script.on_nth_tick(3600, function(event)
  log("[ADDON-RESERVE] min " .. event.tick / 3600 .. ": " .. serpent.line(storage.stat or {}))
end)
