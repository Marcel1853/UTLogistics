--- Teams und Team-Leiter für die Team-Werte (team-config.lua).
---
---   * „Teams gibt es“, sobald Spieler auf mindestens zwei Forces verteilt sind oder ein Spieler in
---     einer eigenen Force (nicht „player“) ist. Sonst gibt es keine Team-Werte (es gelten die
---     Kartenwerte, die ein Admin ändert).
---   * Wer als Erster in ein Team kommt, wird Leiter. Leiter dürfen die Team-Werte ändern und
---     weitere Mitglieder zu Leitern machen oder Leiter entfernen – einer bleibt immer.
---   * Verlässt der letzte Leiter das Team, wird das Mitglied Leiter, das am längsten dabei ist.
---   * Admins dürfen immer (auch über /utl-admin für jedes Team).
---   * Leiter, die länger als „utl-leader-inactive-days“ offline waren, verlieren die Rechte.
---
--- Speicher: storage.teams = {
---   order = { [force_index] = { player_index, … } },   -- Beitrittsreihenfolge
---   leaders = { [force_index] = { [player_index] = true } },
---   active = bool,                                       -- es gibt Teams (siehe oben)
--- }
local Teams = {}

local function data()
  storage.teams = storage.teams or { order = {}, leaders = {}, active = false }
  return storage.teams
end

local function count(set)
  local n = 0
  for _ in pairs(set or {}) do n = n + 1 end
  return n
end

--- Prüfen, ob es Teams gibt: Spieler auf mehreren Forces oder in einer eigenen Force.
local function update_active()
  local forces, own = {}, false
  for _, player in pairs(game.players) do
    forces[player.force_index] = true
    own = own or player.force.name ~= "player"
  end
  data().active = own or count(forces) > 1
end

local function remove_from(list, player_index)
  for i = #list, 1, -1 do
    if list[i] == player_index then table.remove(list, i) end
  end
end

--- Spieler tritt einem Team bei (ans Ende der Reihenfolge; ohne Leiter wird er Leiter).
local function join(player_index, force_index)
  local d = data()
  local order = d.order[force_index] or {}
  d.order[force_index] = order
  remove_from(order, player_index)
  order[#order + 1] = player_index
  local leaders = d.leaders[force_index] or {}
  d.leaders[force_index] = leaders
  if next(leaders) == nil then leaders[player_index] = true end
end

--- Spieler verlässt ein Team; war er der letzte Leiter, rückt der Dienstälteste nach.
local function leave(player_index, force_index)
  local d = data()
  local order = d.order[force_index]
  if order then remove_from(order, player_index) end
  local leaders = d.leaders[force_index]
  if leaders then
    leaders[player_index] = nil
    if next(leaders) == nil and order and order[1] then leaders[order[1]] = true end
    if next(leaders) == nil then d.leaders[force_index] = nil end
  end
  if order and #order == 0 then d.order[force_index] = nil end
end

--- Alles aus den aktuellen Spielern neu aufbauen (Spielstand ohne Daten, nach Mod-Update).
--- Vorhandene Reihenfolge und Leiter bleiben, soweit die Spieler noch im Team sind.
function Teams.rebuild()
  local d = data()
  for force_index, order in pairs(d.order) do
    for i = #order, 1, -1 do
      local player = game.get_player(order[i])
      if not (player and player.force_index == force_index) then leave(order[i], force_index) end
    end
  end
  local players = {}
  for _, player in pairs(game.players) do players[#players + 1] = player end
  table.sort(players, function(a, b) return a.index < b.index end)
  for _, player in ipairs(players) do
    local order = d.order[player.force_index]
    local known = false
    for _, index in ipairs(order or {}) do known = known or index == player.index end
    if not known then join(player.index, player.force_index) end
  end
  update_active()
end

--- Gibt es Teams (Spieler auf mehreren Forces oder in einer eigenen Force)?
function Teams.active()
  return data().active == true
end

function Teams.is_leader(player)
  local leaders = data().leaders[player.force_index]
  return leaders ~= nil and leaders[player.index] == true
end

--- Darf der Spieler die Werte seines Teams ändern?
function Teams.can_edit(player)
  return player.admin or Teams.is_leader(player)
end

--- Leiter und übrige Mitglieder eines Teams (Spieler-Objekte, nach Beitritt sortiert).
function Teams.members(force_index)
  local d = data()
  local leaders, others = {}, {}
  for _, index in ipairs(d.order[force_index] or {}) do
    local player = game.get_player(index)
    if player then
      local list = (d.leaders[force_index] or {})[index] and leaders or others
      list[#list + 1] = player
    end
  end
  return leaders, others
end

--- `target` (Spieler-Index) zum Leiter machen; nur ein Leiter oder Admin desselben Teams.
function Teams.add_leader(by, target_index)
  local target = game.get_player(target_index)
  if not (target and target.force_index == by.force_index and Teams.can_edit(by)) then return false end
  local d = data()
  d.leaders[by.force_index] = d.leaders[by.force_index] or {}
  d.leaders[by.force_index][target_index] = true
  return true
end

--- Leiterrechte wegnehmen (auch sich selbst); der letzte Leiter bleibt.
function Teams.remove_leader(by, target_index)
  local leaders = data().leaders[by.force_index]
  if not (leaders and leaders[target_index] and Teams.can_edit(by)) then return false end
  if count(leaders) <= 1 then return false end
  leaders[target_index] = nil
  return true
end

--- Alle Teams mit Mitgliedern: { { index, name }, … } nach Name (für das Admin-Fenster).
function Teams.list()
  local list = {}
  for force_index, order in pairs(data().order) do
    local force = game.forces[force_index]
    if force and #order > 0 then list[#list + 1] = { index = force_index, name = force.name } end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

--- Admin: Spieler im Team `force_index` zum Leiter machen oder die Rechte wegnehmen. Fällt dabei
--- der letzte Leiter weg, übernimmt das dienstälteste andere Mitglied.
function Teams.admin_set(force_index, player_index, leader)
  local d = data()
  local player = game.get_player(player_index)
  if not (player and player.force_index == force_index) then return false end
  local leaders = d.leaders[force_index] or {}
  d.leaders[force_index] = leaders
  if leader then
    leaders[player_index] = true
    return true
  end
  leaders[player_index] = nil
  if next(leaders) == nil then
    for _, index in ipairs(d.order[force_index] or {}) do
      if index ~= player_index then
        leaders[index] = true
        break
      end
    end
  end
  return true
end

--- Leiter, die zu lange offline waren, verlieren die Rechte; ohne Leiter rückt das dienstälteste
--- Mitglied nach, das selbst nicht zu lange weg ist. Läuft selten (Heartbeat-Aufgabe).
function Teams.check_inactive(days)
  if not days or days <= 0 or not storage.teams then return end
  local limit = days * 24 * 60 * 60 * 60 -- Tage in Ticks
  local now = game.tick
  local function away(player)
    return not player.connected and now - player.last_online > limit
  end
  for force_index, leaders in pairs(storage.teams.leaders) do
    local removed = false
    for index in pairs(leaders) do
      local player = game.get_player(index)
      if player and away(player) then
        leaders[index] = nil
        removed = true
      end
    end
    if removed and next(leaders) == nil then
      for _, index in ipairs(storage.teams.order[force_index] or {}) do
        local player = game.get_player(index)
        if player and not away(player) then
          leaders[index] = true
          break
        end
      end
    end
  end
end

-- Ereignisse (angemeldet in scripts/gui/manager/init.lua)

function Teams.on_player_created(event)
  local player = game.get_player(event.player_index)
  if player then join(player.index, player.force_index) end
  update_active()
end

function Teams.on_player_changed_force(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.force and event.force.valid then leave(player.index, event.force.index) end
  join(player.index, player.force_index)
  update_active()
end

--- Spieler kommt zurück: Ist das Team leiterlos (alle Leiter zu lange weg), übernimmt er.
function Teams.on_player_joined(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local d = data()
  local leaders = d.leaders[player.force_index]
  if leaders == nil or next(leaders) == nil then join(player.index, player.force_index) end
  update_active()
end

function Teams.on_player_removed(event)
  local d = data()
  for force_index in pairs(d.order) do leave(event.player_index, force_index) end
  update_active()
end

function Teams.on_forces_merged(event)
  local d = data()
  local order = d.order[event.source_index] or {}
  d.order[event.source_index], d.leaders[event.source_index] = nil, nil
  local target = event.destination and event.destination.valid and event.destination.index
  if target then
    for _, player_index in ipairs(order) do join(player_index, target) end
  end
  update_active()
end

return Teams
