-- Hilfs-Mod (nur mit Grafik, siehe tools/screenshots.sh): nimmt in einem Szenario automatisch Screenshots für das Wiki auf.
-- Wartet, bis das Szenario gebaut ist und Lieferungen laufen, dann Schritt für Schritt:
-- Fenster öffnen, im nächsten Schritt aufnehmen. Bilder: script-output/utl/<szenario>-NN-name.png
local WAIT = 60 * 75   -- Vorlauf: Züge sollen schon gefahren sein (Verlauf, Unterwegs)
local STEP = 90
local R = { 1920, 1080 }

local steps, index, prefix, next_tick = nil, 0, "x", nil

local function player() return game.get_player(1) end

local function shot(name, extra)
  local p = player()
  local spec = { player = p, by_player = p, path = ("utl/%s-%02d-%s.png"):format(prefix, index, name),
    resolution = R, show_gui = true, show_entity_info = true, anti_alias = true, quality = 90,
    allow_in_replay = true, zoom = 1 }
  for k, v in pairs(extra or {}) do spec[k] = v end
  game.take_screenshot(spec)
  log("[SHOTS] " .. spec.path)
end

local function close() remote.call("utl", "close_windows", 1) end

-- Stationen der Spieler-Oberfläche einordnen
local function stations(surface)
  local found = { provider = {}, requester = {}, depot = {}, fuel = {}, cleanup = {} }
  for _, e in pairs(surface.find_entities_filtered({ name = { "utl-train-stop", "utl-station-combinator" } })) do
    local st = remote.call("utl", "get_station", e.unit_number)
    if st and st.config then
      local roles, entry = st.config.roles or {}, { unit = e.unit_number, entity = e, st = st }
      for _, role in ipairs({ "provider", "requester", "depot", "fuel", "cleanup" }) do
        if roles[role] then table.insert(found[role], entry) end
      end
    end
  end
  return found
end

local STAR = {} -- Netzname → hat Partner

local function linked(e)
  local name = (e.st.config.network ~= "" and e.st.config.network) or "default"
  return STAR[name]
end

--- Erste passende Station; bevorzugt eine aus einem Netz mit Partnern.
local function pick(list, kind)
  local first
  for _, e in ipairs(list) do
    if not kind or e.entity.name == kind then
      if linked(e) then return e end
      first = first or e
    end
  end
  return first
end

local function world(name, entity, zoom)
  return {
    function() close() end,
    function() if entity and entity.valid then shot(name, { position = entity.position, zoom = zoom or 0.8, show_gui = false }) end end,
  }
end

local function window(name, entry, tab, standalone)
  return {
    function() close(); if entry then remote.call("utl", "open_station", 1, entry.unit, tab, standalone) end end,
    function() if entry then shot(name) end end,
  }
end

--- Alle Scroll-Bereiche in den offenen Fenstern ganz nach unten
local function scroll_down(element)
  if element.type == "scroll-pane" then element.scroll_to_bottom() end
  for _, child in pairs(element.children) do scroll_down(child) end
end

local function manager(name, tab, select)
  return {
    function() close(); remote.call("utl", "open_manager", 1, tab, select) end,
    function() shot(name) end,
  }
end

local function plan(surface)
  -- Szenario mit Teams: Spieler ins Team Rot, damit Admin-Fenster und Einstellungen ein Team zeigen
  local p = player()
  if game.forces["rot"] and p.force.name ~= "rot" then p.force = game.forces["rot"] end
  local s = stations(surface)
  for _, list in pairs(s) do
    for _, e in ipairs(list) do
      local name = (e.st.config.network ~= "" and e.st.config.network) or "default"
      if STAR[name] == nil then
        local ok, star = pcall(remote.call, "utl", "get_network_star", surface.index, name, e.entity.force.name)
        STAR[name] = ok and star and star.role == "center" or false
      end
    end
  end
  local prov_stop, prov_comb = pick(s.provider, "utl-train-stop"), pick(s.provider, "utl-station-combinator")
  local req_stop, req_comb = pick(s.requester, "utl-train-stop"), pick(s.requester, "utl-station-combinator")
  local list = {}
  local function add(pair) for _, f in ipairs(pair) do list[#list + 1] = f end end
  add({ function() end, function() shot("ueberblick") end })
  add(window("anbieter-station", prov_stop, 1))
  add(window("anbieter-werte", prov_stop, 2))
  add(window("abnehmer-station", req_stop, 1))
  add(window("combinator-fenster", req_comb or prov_comb, nil))
  add(window("cleanup-werte", pick(s.cleanup, "utl-train-stop") or pick(s.cleanup), 2))
  add(window("depot-station", pick(s.depot), 1))
  add(window("tankstelle-station", pick(s.fuel), 1))
  add(world("welt-anbieter", (prov_stop or prov_comb) and (prov_stop or prov_comb).entity, 0.9))
  add(world("welt-abnehmer", (req_stop or req_comb) and (req_stop or req_comb).entity, 0.9))
  add(world("welt-depot", pick(s.depot) and pick(s.depot).entity, 0.6))
  add(world("welt-tankstelle", pick(s.fuel) and pick(s.fuel).entity, 0.9))
  add(world("welt-cleanup", pick(s.cleanup) and pick(s.cleanup).entity, 0.9))
  local net = prov_stop or prov_comb or req_stop
  local ware
  if net then for key in pairs(net.st.provide or {}) do ware = ware or key end end
  add(manager("manager-depots", "depots"))
  add(manager("manager-stationen", "stations"))
  add(manager("manager-netzwerke", "networks",
    net and { network = surface.index .. "|" .. ((net.st.config.network ~= "" and net.st.config.network) or "default") } or nil))
  add(manager("manager-inventar", "inventory", ware and { ware = ware } or nil))
  add(manager("manager-verlauf", "history"))
  add(manager("manager-alarme", "alerts"))
  add(manager("manager-einstellungen", "settings"))
  add({ function() scroll_down(player().gui.screen) end, function() shot("manager-einstellungen-unten") end })
  -- Weitere Planeten (Planeten-Test): je Übersicht und Manager, der den Planeten zeigt
  for _, name in ipairs({ "vulcanus", "gleba" }) do
    local other = game.surfaces[name]
    local depot = other and other ~= surface and other.find_entities_filtered({ name = "utl-train-stop", limit = 1 })[1]
    if depot then
      add({
        function() close(); player().teleport(depot.position, other) end,
        function() shot(name .. "-ueberblick", { zoom = 0.5 }) end,
        function() remote.call("utl", "open_manager", 1, "depots") end,
        function() shot(name .. "-manager-depots") end,
      })
    end
  end
  add({ function() close(); if player().surface ~= surface then player().teleport(surface.find_non_colliding_position("character", player().position, 20, 1) or { 0, 0 }, surface) end end })
  -- Admin-Fenster: /utl-admin kann ein Script nicht eingeben. Die Remote-Funktion open_admin gibt es
  -- im Mod noch nicht (für die 0.0.7-Bilder in einer Wegwerf-Kopie nachgerüstet); ohne sie fehlt
  -- nur dieses Bild (Schritte sind mit pcall abgesichert).
  add({ function() close(); remote.call("utl", "open_admin", 1) end, function() shot("admin-fenster") end })
  add({ function() local p = player(); if p.gui.screen then for _, c in pairs(p.gui.screen.children) do if c.name ~= "" and string.find(c.name, "admin") then c.destroy() end end end end })
  return list
end

script.on_nth_tick(30, function(e)
  local p = player()
  if not p then return end
  if not steps then
    if e.tick < WAIT then return end
    local surface = p.surface
    prefix = string.gsub(surface.name, "^utl%-", "")
    steps = plan(surface)
    log(("[SHOTS] %s: %d Schritte"):format(surface.name, #steps))
    next_tick = e.tick
  end
  if e.tick < next_tick then return end
  index = index + 1
  local f = steps[index]
  if not f then
    if index == #steps + 1 then
      close()
      log("[SHOTS] fertig")
      p.print("[SHOTS] fertig – das Spiel kann geschlossen werden")
    end
    return
  end
  local ok, err = pcall(f)
  if not ok then log("[SHOTS] Fehler in Schritt " .. index .. ": " .. tostring(err)) end
  next_tick = e.tick + STEP
end)
