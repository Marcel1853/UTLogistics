--- Hinweis-Fenster „Rezepte geändert“ (Wunsch Marcel): Ab 0.0.9 brauchen die UTL-Teile mehr
--- Zutaten. Maschinen, die sie herstellen, bekommen die neuen Zutaten nicht von selbst – ohne
--- Hinweis bliebe so manche Fabrik still stehen. Einmal je Spieler nach einem Update von einer
--- Version davor; nicht bei einem neuen Spiel. Die Rezeptzeilen kommen aus den Prototypen.
local Events = require("scripts.core.events")
local News = require("scripts.core.news")

local Notice = {}

local NAME = "utl_recipe_notice"
local SINCE = "0.0.9"
-- nur, was es vor 0.0.9 schon gab (Netz-Kombinator und UTL-Hafen sind neu)
local RECIPES = { "utl-train-stop", "utl-station-combinator" }

--- „[item=utl-train-stop]  ←  1 × [item=train-stop]  10 × [item=electronic-circuit] …“
local function recipe_line(name)
  local recipe = prototypes.recipe[name]
  if not recipe then return nil end
  local parts = { "[item=" .. name .. "]  ←  " }
  for _, ingredient in ipairs(recipe.ingredients) do
    parts[#parts + 1] = ("%d × [%s=%s]   "):format(ingredient.amount, ingredient.type, ingredient.name)
  end
  return table.concat(parts)
end

--- Fenster für einen Spieler öffnen (auch per Remote, zum Ansehen und für Tests).
function Notice.show(player)
  if not (player and player.valid) then return end
  local screen = player.gui.screen
  if screen[NAME] then screen[NAME].destroy() end
  local frame = screen.add({ type = "frame", name = NAME, direction = "vertical", caption = { "utl-notice.recipes-title", SINCE } })
  frame.auto_center = true
  local inner = frame.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  inner.style.maximal_width = 620
  local text = inner.add({ type = "label", caption = { "utl-notice.recipes-text" } })
  text.style.single_line = false
  for _, name in ipairs(RECIPES) do
    local line = recipe_line(name)
    if line then inner.add({ type = "label", caption = line }).style.top_margin = 6 end
  end
  local bar = frame.add({ type = "flow", style = "dialog_buttons_horizontal_flow" })
  bar.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  bar.add({ type = "button", style = "confirm_button", caption = { "utl-notice.ok" }, tags = { utl_notice = "close" } })
  player.opened = frame
end

local function close(player)
  local frame = player.gui.screen[NAME]
  if frame then frame.destroy() end
end

--- Offener Hinweis für einen Spieler, der ihn noch nicht gesehen hat.
local function show_pending(player)
  local notice = storage.recipe_notice
  if not (notice and player and player.valid) or notice.seen[player.index] then return end
  notice.seen[player.index] = true
  Notice.show(player)
end

Events.on_configuration_changed(function(data)
  local change = data.mod_changes and data.mod_changes[script.mod_name]
  if not (change and change.old_version and change.new_version) then return end -- neu hinzugefügt: kein Hinweis
  -- nur beim Sprung über 0.0.9 (alte Version davor, neue ab 0.0.9)
  if not (News.newer(SINCE, change.old_version) and not News.newer(SINCE, change.new_version)) then return end
  storage.recipe_notice = { seen = {} }
  log(("UTL: Update %s -> %s, Hinweis „Rezepte geändert“ vorgemerkt"):format(change.old_version, change.new_version))
  for _, player in pairs(game.connected_players) do show_pending(player) end
end)

Events.on(defines.events.on_player_joined_game, function(event)
  show_pending(game.get_player(event.player_index))
end)

Events.on(defines.events.on_gui_click, function(event)
  local tags = event.element.valid and event.element.tags
  if tags and tags.utl_notice == "close" then close(game.get_player(event.player_index)) end
end)

Events.on(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == NAME then
    close(game.get_player(event.player_index))
  end
end)

return Notice
