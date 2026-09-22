--- Planeten-Auswahl des UTL-Managers: „Automatisch“ (die Oberfläche, auf der der Spieler ist oder
--- die er ansieht), „Alle“ oder eine bestimmte Oberfläche. Angeboten werden nur Oberflächen mit
--- UTL-Stationen – Space-Plattformen fallen so raus, Planeten anderer Mods kommen von selbst dazu.
--- Die Auswahl gibt es nur mit Space Age (Wunsch Marcel); ohne zeigt der Manager alles, gleichnamige
--- Depots auf verschiedenen Oberflächen bleiben aber getrennt (mit Oberflächenname).
local Filter = {}

local AUTO, ALL = "auto", "all"

--- Oberflächen mit UTL-Stationen, sortiert nach Index (Nauvis zuerst).
function Filter.used()
  local set, list = {}, {}
  for _, station in pairs(storage.stations.by_unit) do
    local stop = station.stop
    if stop and stop.valid and not set[stop.surface_index] then
      set[stop.surface_index] = true
      list[#list + 1] = stop.surface_index
    end
  end
  table.sort(list)
  return list
end

--- Übersetzter Name einer Oberfläche (Planet, sonst der Oberflächenname).
function Filter.label(surface_index)
  local surface = game.surfaces[surface_index]
  if not surface then return "?" end
  local planet = surface.planet
  if planet then return planet.prototype.localised_name end
  return surface.localised_name or surface.name
end

--- Auswahl anbieten? Nur mit Space Age.
function Filter.visible()
  return script.active_mods["space-age"] ~= nil
end

local function prefs(player_index)
  storage.manager_prefs[player_index] = storage.manager_prefs[player_index] or { surface = AUTO }
  return storage.manager_prefs[player_index]
end

--- Gewählte Oberfläche für diesen Durchlauf festlegen: `manager.surface` (nil = alle) und
--- `manager.several` (Planet in der Liste mit anzeigen). Gleicht die Auswahlliste ab.
function Filter.apply(manager, dropdown)
  local player = game.get_player(manager.player_index)
  local used = Filter.used()
  local shown = Filter.visible()
  local choice = shown and prefs(manager.player_index).surface or ALL

  -- „Automatisch“ zeigt immer den Planeten, auf dem der Spieler ist – auch wenn dort noch keine
  -- UTL-Station steht (dann ist der Manager eben leer, statt einen anderen Planeten zu zeigen).
  local surface = nil
  if choice == AUTO then
    surface = player and player.surface_index or nil
  elseif choice ~= ALL then
    surface = game.surfaces[choice] and choice or nil
  end
  manager.surface = surface
  manager.several = surface == nil and #used > 1
  -- ein ausdrücklich gewählter Planet bleibt in der Liste, auch wenn dort keine Station mehr steht
  if type(choice) == "number" and surface then
    local listed = false
    for _, index in ipairs(used) do listed = listed or index == choice end
    if not listed then used[#used + 1] = choice end
  end

  if dropdown and dropdown.valid then
    dropdown.visible = shown
    if shown then
      local items, values, selected = { { "utl-manager.surface-auto" }, { "utl-manager.surface-all" } }, { AUTO, ALL }, 1
      for _, index in ipairs(used) do
        items[#items + 1] = Filter.label(index)
        values[#values + 1] = index
      end
      for i, value in ipairs(values) do
        if value == choice then selected = i end
      end
      -- Nur bei neuen/weggefallenen Oberflächen neu setzen – sonst klappte eine offene Liste
      -- bei jedem automatischen Auffrischen zu.
      local old = manager.surface_values
      local same = old and #old == #values
      for i = 1, same and #values or 0 do
        if old[i] ~= values[i] then same = false end
      end
      if not same then
        dropdown.items = items
        manager.surface_values = values
      end
      if dropdown.selected_index ~= selected then dropdown.selected_index = selected end
    end
  end
end

--- Auswahl aus der Liste übernehmen (Index des gewählten Eintrags).
function Filter.choose(manager, index)
  local value = manager.surface_values and manager.surface_values[index]
  if value ~= nil then prefs(manager.player_index).surface = value end
end

--- Folgt die Auswahl dem Spieler („Automatisch“)?
function Filter.follows_player(player_index)
  local p = storage.manager_prefs[player_index]
  return p == nil or p.surface == AUTO
end

--- Gehört etwas auf dieser Oberfläche in die Anzeige?
function Filter.match(manager, surface_index)
  return manager.surface == nil or manager.surface == surface_index
end

--- „Name · Planet“, wenn mehrere Oberflächen gleichzeitig angezeigt werden.
function Filter.name(manager, name, surface_index)
  if not manager.several or not surface_index then return name end
  return { "", name, "  · ", Filter.label(surface_index) }
end

return Filter
