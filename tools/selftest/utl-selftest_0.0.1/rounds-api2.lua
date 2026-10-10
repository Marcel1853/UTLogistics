-- Selbsttest R43 (09.10.2026): Schnittstelle für Add-ons, Meilenstein 2 – der Testmod tritt selbst
-- als Add-on auf.
--   a) eigene Rollen: Rangierdepot (base depot, eigene Züge), Abstellgleis (ohne base), Ladebucht
--      (base provider); falsche Anmeldungen werden abgelehnt
--   b) Zug im Rangierdepot gehört dem Add-on: nicht im UTL-Pool, aber in get_idle_trains{ role }
--   c) send_job zum Abstellgleis: festgehalten, on_job_finished, danach wieder frei im Rangierdepot
--   d) Daten je Station reisen beim Einstellungen-Kopieren mit, get_stations{ addon_role }
--   e) Abschnitt im Stationsfenster und Reiter im Manager anmelden
local Api2 = {}

local MOD = "utl-selftest"
local LINE = 1

-- Rückrufe für Stationsfenster und Manager (Interface beim Laden anlegen)
remote.add_interface("utl-selftest-addon", {
  build_section = function(flow, unit) flow.add({ type = "label", caption = "Selbsttest-Abschnitt " .. unit }) end,
  build_tab = function(flow) flow.add({ type = "label", caption = "Selbsttest-Reiter" }) end,
  -- R44: Zugfilter – erst alle ablehnen, nach dem Umschalten alle erlauben
  filter = function(ids, info)
    storage.r44_calls = (storage.r44_calls or 0) + 1
    storage.r44_info = info
    if storage.r44_allow then return ids end
    return {}
  end,
})

--- Ereignisse mitschreiben (aus Rounds.listen).
function Api2.record(name, event)
  if name == "on_job_finished" then
    storage.r43_jobs = storage.r43_jobs or {}
    storage.r43_jobs[event.job_id] = event.canceled and ("abgebrochen " .. tostring(event.reason)) or "fertig"
  elseif name == "on_request_unserved" and event.reason then
    storage.r44_unserved = storage.r44_unserved or {}
    storage.r44_unserved[event.station] = event.reason
  elseif name == "on_train_idle" and event.role == MOD .. "/rangierdepot" then
    storage.r43_idle = (storage.r43_idle or 0) + 1
  end
end

--- `west` = Haltestelle für Züge Richtung Westen (Rückweg ins Depot klappt auf der geraden Strecke)
local function stop(s, force, name, x, west)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, LINE + (west and -2 or 2) },
    direction = west and 12 or 4, force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

function Api2.build(check)
  local s = game.create_surface("utl-selftest-r43")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end

  local function role(spec) return remote.call("utl", "register_role", spec) end
  check("R43 rollen anmelden", role({ mod = MOD, name = "rangierdepot", caption = "Rangierdepot", base = "depot", own_trains = true })
    and role({ mod = MOD, name = "abstellgleis", caption = "Abstellgleis" })
    and role({ mod = MOD, name = "ladebucht", caption = "Ladebucht", base = "provider" }))
  check("R43 falsche anmeldungen abgelehnt", not role({ mod = "gibt-es-nicht", name = "x" })
    and not role({ mod = MOD, name = "x", base = "quatsch" })
    and not remote.call("utl", "register_gui_section", { mod = MOD, interface = "utl-selftest-addon", build = "fehlt" }))
  check("R43 fenster-abschnitt und manager-reiter anmelden",
    remote.call("utl", "register_gui_section", { mod = MOD, interface = "utl-selftest-addon", build = "build_section" })
    and remote.call("utl", "register_manager_tab", { mod = MOD, interface = "utl-selftest-addon", build = "build_tab",
      caption = "Selbsttest" }))

  local depot = stop(s, force, "R43-Rangierdepot", 10)
  local siding = stop(s, force, "R43-Abstellgleis", -60, true)
  local bay = stop(s, force, "R43-Ladebucht", 40)
  local other = stop(s, force, "R43-Kopie", 60)
  for _, e in ipairs({ depot, siding, bay, other }) do
    remote.call("utl", "configure_station", e.unit_number, { network = "R43" })
  end
  check("R43 station auf add-on-rolle setzen",
    remote.call("utl", "set_station_role", depot.unit_number, MOD .. "/rangierdepot")
    and remote.call("utl", "set_station_role", siding.unit_number, MOD .. "/abstellgleis")
    and remote.call("utl", "set_station_role", bay.unit_number, MOD .. "/ladebucht")
    and not remote.call("utl", "set_station_role", bay.unit_number, MOD .. "/gibt-es-nicht"))
  local info = remote.call("utl", "get_station", bay.unit_number) --[[@as table]]
  check("R43 ladebucht verhält sich wie ein anbieter", info.config.roles.provider == true
    and info.config.addon_role == MOD .. "/ladebucht", serpent.line(info.config.roles))
  info = remote.call("utl", "get_station", siding.unit_number) --[[@as table]]
  check("R43 abstellgleis ohne grundrolle", info.config.mode == "addon" and not info.config.roles.provider
    and not info.config.roles.depot, serpent.line({ info.config.mode, info.config.roles }))

  -- Daten je Station + Kopieren
  remote.call("utl", "set_station_data", siding.unit_number, MOD, "wagen", 2)
  remote.call("utl", "copy_settings", siding.unit_number, other.unit_number)
  local copied = remote.call("utl", "get_station_data", other.unit_number, MOD) --[[@as table?]]
  local copied_info = remote.call("utl", "get_station", other.unit_number) --[[@as table]]
  check("R43 daten je station reisen beim kopieren mit", copied ~= nil and copied.wagen == 2
    and copied_info.config.addon_role == MOD .. "/abstellgleis", serpent.line({ copied, copied_info.config.addon_role }))
  check("R43 get_stations nach add-on-rolle",
    #remote.call("utl", "get_stations", { addon_role = MOD .. "/abstellgleis" }) == 2)

  -- Rangierlok: fährt ins Rangierdepot
  local loco = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local loco2 = s.create_entity({ name = "locomotive", position = { -3, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  loco.insert({ name = "coal", count = 50 })
  loco2.insert({ name = "coal", count = 50 })
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = "R43-Rangierdepot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  loco.train.manual_mode = false
  -- Netz-Kombinator im Netz R43 mit einem zusätzlichen Signal des Add-ons (set_network_signals)
  local readout = s.create_entity({ name = "utl-network-combinator", position = { 0, LINE + 20 }, force = force,
    raise_built = true }) --[[@as LuaEntity]]
  remote.call("utl", "configure_readout", readout.unit_number, { network = "R43", mode = "trains" })
  check("R43 set_network_signals", remote.call("utl", "set_network_signals", s.index, "player", "R43", MOD,
    { { signal = { type = "virtual", name = "signal-W" }, count = 7 } }) == true)
  -- abgetrenntes Gleisstück mit Haltestelle (anderes Gleisnetz)
  for x = -9, 9, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE + 40 }, direction = 4, force = force }) end
  local island = s.create_entity({ name = "utl-train-stop", position = { 0, LINE + 42 }, direction = 4, force = force,
    raise_built = true }) --[[@as LuaEntity]]
  island.backer_name = "R43-Insel"
  return { start = game.tick, loco = loco, siding = siding.unit_number, siding_stop = siding, island = island.unit_number,
    readout = readout.unit_number }
end

local function own_idle(train_id)
  for _, t in pairs(remote.call("utl", "get_idle_trains", { role = MOD .. "/rangierdepot" })) do
    if t.id == train_id then return true end
  end
  return false
end

--- Liefert true, wenn R43 fertig ist.
function Api2.watch(r, check)
  if not r or r.done then return true end
  local train = r.loco.valid and r.loco.train
  if not train then return false end
  if not r.job and own_idle(train.id) then
    local in_pool = false
    for _, t in pairs(remote.call("utl", "get_idle_trains", { network = "R43" })) do in_pool = in_pool or t.id == train.id end
    check("R43 zug im rangierdepot gehört dem add-on, nicht dem dispatcher", not in_pool)
    -- Zug im Depot dieses Add-ons gehört ihm: ein anderer Mod bekommt ihn nicht
    local other_job, other_why = remote.call("utl", "send_job", train.id, "anderer-mod", { { station = r.siding } })
    check("R43 fremdes add-on bekommt den zug nicht", other_job == nil and other_why == "owned-by-other"
      and remote.call("utl", "hold_train", train.id, "anderer-mod") == false, tostring(other_why))
    -- Haltestelle auf einem abgetrennten Gleisstück: unerreichbar
    local far_job, far_why, far_index = remote.call("utl", "send_job", train.id, MOD, { { station = r.island } })
    check("R43 getrenntes gleisnetz wird abgelehnt", far_job == nil and far_why == "unreachable" and far_index == 1,
      serpent.line({ far_job, far_why, far_index }))
    -- Zuglimit 0 am Ziel: Auftrag wird abgelehnt (UTL fährt per Wegpunkt, das Spiel zählte ihn sonst nicht)
    local siding = r.siding_stop
    siding.trains_limit = 0
    local full, full_why, full_index = remote.call("utl", "send_job", train.id, MOD,
      { { station = r.siding, wait = { { type = "time", ticks = 60 } } } })
    siding.trains_limit = nil
    check("R43 send_job: zuglimit 0 am ziel wird abgelehnt", full == nil and full_why == "station-full" and full_index == 1,
      serpent.line({ full, full_why, full_index }))
    -- eigener temporärer Eintrag des Add-ons (an UTL vorbei) muss send_job überstehen
    local schedule = train.get_schedule()
    schedule.add_record({ station = "R43-Fremd", temporary = true, wait_conditions = {},
      index = { schedule_index = schedule.get_record_count() + 1 } })
    -- Wegpunkt per Position (Gleis am Abstellgleis), Richtung bestimmt UTL selbst
    local id, why = remote.call("utl", "send_job", train.id, MOD,
      { { position = r.siding_stop.connected_rail.position, wait = { { type = "time", ticks = 60 } } } })
    local kept, rail_target = false, false
    for _, record in pairs(schedule.get_records() or {}) do
      if record.temporary and record.station == "R43-Fremd" then kept = true end
      if record.temporary and record.rail then rail_target = true end
    end
    check("R43 eigener temporärer eintrag bleibt, wegpunkt per position", kept and rail_target, serpent.line({ kept, rail_target }))
    for i = schedule.get_record_count(), 1, -1 do -- Eintrag wieder entfernen (nur für den Test)
      local record = schedule.get_record({ schedule_index = i })
      if record and record.station == "R43-Fremd" then schedule.remove_record({ schedule_index = i }) end
    end
    check("R43 send_job", id ~= nil and remote.call("utl", "is_held", train.id) == MOD
      and remote.call("utl", "get_job", id) ~= nil, tostring(why))
    r.job = id or -1
  elseif r.job and r.job > 0 and not r.finished and (storage.r43_jobs or {})[r.job] then
    r.finished = storage.r43_jobs[r.job]
    check("R43 on_job_finished", r.finished == "fertig" and remote.call("utl", "is_held", train.id) == nil
      and remote.call("utl", "get_job", r.job) == nil, r.finished)
  elseif r.finished and own_idle(train.id) then
    local out = remote.call("utl", "get_readout", r.readout) --[[@as table?]]
    local w = out and out.values["virtual|signal-W|normal"]
    check("R43 netz-kombinator gibt das signal des add-ons aus", w == 7, serpent.line(out and out.values))
    check("R43 nach dem auftrag wieder frei im rangierdepot", (storage.r43_idle or 0) >= 2, tostring(storage.r43_idle))
    r.done = true
  end
  if not r.done and game.tick - r.start > 30000 then
    r.done = true
    check("R43 auftrag eines add-ons", false, serpent.line({ job = r.job, fertig = r.finished, zug = train.state,
      idle = storage.r43_idle }))
  end
  return r.done
end

-- ── R44: Zugfilter ──────────────────────────────────────────────────────────────────────────

function Api2.build_filter(check)
  local s = game.create_surface("utl-selftest-r44")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  -- „Anfrage ohne Zug“ sofort melden (Wartezeit 0), am Ende von R44 wieder zurück
  remote.call("utl", "set_map_config", "utl-alert-no-train-minutes", 0)
  check("R44 zugfilter anmelden", remote.call("utl", "register_train_filter",
    { mod = MOD, interface = "utl-selftest-addon", filter = "filter" }) == true)
  local depot = stop(s, force, "R44-Depot", 10)
  local bay = stop(s, force, "R44-Ladebucht", 60)
  local req = stop(s, force, "R44-Abnehmer", -60, true)
  local c = s.create_entity({ name = "constant-combinator", position = { 63.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  c.get_wire_connector(defines.wire_connector_id.circuit_green, true).connect_to(
    bay.get_wire_connector(defines.wire_connector_id.circuit_green, true))
  local function cfg(e, changes) changes.network = "R44"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg(depot, { mode = "depot" })
  cfg(bay, { network = "R44" })
  remote.call("utl", "set_station_role", bay.unit_number, MOD .. "/ladebucht")
  cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  local l1 = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local wagon = s.create_entity({ name = "cargo-wagon", position = { -3, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local l2 = s.create_entity({ name = "locomotive", position = { -10, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "R44-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  -- Station bauen und gleich wieder abreißen: on_station_created/_removed
  local temp = s.create_entity({ name = "utl-train-stop", position = { -30, LINE + 2 }, direction = 4, force = force,
    raise_built = true }) --[[@as LuaEntity]]
  local temp_unit = temp.unit_number
  temp.destroy({ raise_destroy = true })
  return { start = game.tick, loco = l1, wagon = wagon, req = req.unit_number, temp = temp_unit }
end

function Api2.watch_filter(r, check)
  if not r or r.done then return true end
  local seen = false
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if d.to == "R44-Abnehmer" then seen = d end
  end
  if not r.opened then
    if seen then r.early = true end
    -- 15 s lang abgelehnt (der Zug steht längst im Depot): dann erlauben
    if game.tick - r.start > 900 and (storage.r44_calls or 0) > 0 then
      r.opened = game.tick
      storage.r44_allow = true
    end
  elseif seen and not r.done then
    r.done = true
    local info = storage.r44_info or {}
    check("R44 zugfilter: erst abgelehnt, dann erlaubt", not r.early and info.provider_role == MOD .. "/ladebucht",
      serpent.line({ zu_frueh = r.early, aufrufe = storage.r44_calls, info = info }))
    remote.call("utl", "set_map_config", "utl-alert-no-train-minutes", nil)
    local unserved = (storage.r44_unserved or {})[r.req]
    check("R44 on_request_unserved (filter lehnt alle züge ab)", unserved == "no-free-train" or unserved == "no-fitting-train",
      tostring(unserved))
    local ev = storage.r36 or {}
    check("R44 stations-ereignisse und warnungen", (ev.on_station_created or 0) > 0 and (ev.on_station_changed or 0) > 0
      and (ev.on_station_removed or 0) > 0 and (ev.on_alert or 0) > 0,
      serpent.line({ ev.on_station_created, ev.on_station_changed, ev.on_station_removed, ev.on_alert }))
    remote.call("utl", "cancel_delivery", seen.id)
  end
  if not r.done and game.tick - r.start > 20000 then
    r.done = true
    check("R44 zugfilter: erst abgelehnt, dann erlaubt", false, serpent.line({ zu_frueh = r.early, offen = r.opened,
      aufrufe = storage.r44_calls }))
  end
  return r.done
end

return Api2
