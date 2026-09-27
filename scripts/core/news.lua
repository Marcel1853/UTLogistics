--- Update-Hinweis (Wunsch Marcel): Nach einem Update von UTL bekommt jeder Spieler einmal eine kurze
--- Zeile im Chat mit dem Wichtigsten der neuen Version. Der Tag [tip=utl-news] darin lässt sich
--- anklicken und öffnet Tipps & Tricks auf der Seite „Neu in UTL“ – ein Chat-Text kann kein eigenes
--- Fenster öffnen, ein Tipp-Link schon. Nicht bei einem neuen Spiel, nur bei einem Versionssprung.
--- Abschaltbar je Spieler: Einstellung „Update-Hinweise im Chat“.
local Events = require("scripts.core.events")

local News = {}

local SETTING = "utl-news"

--- "0.0.8" → { 0, 0, 8 }
local function parse(version)
  local parts = {}
  for number in string.gmatch(version or "", "%d+") do parts[#parts + 1] = tonumber(number) end
  return parts
end

--- Ist Version a neuer als b?
function News.newer(a, b)
  local pa, pb = parse(a), parse(b)
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

--- Hinweis an einen Spieler, höchstens einmal je Version.
function News.show(player)
  local news = storage.news
  if not (news and player.valid) then return end
  storage.news_seen = storage.news_seen or {}
  if storage.news_seen[player.index] == news.version then return end
  storage.news_seen[player.index] = news.version
  local setting = player.mod_settings[SETTING]
  if setting and setting.value == false then return end
  player.print({ "utl-news.chat", news.version, { "utl-news.highlights" }, "[tip=utl-news]" })
end

Events.on_configuration_changed(function(data)
  local change = data.mod_changes and data.mod_changes[script.mod_name]
  if not (change and change.old_version and change.new_version) then return end -- neu hinzugefügt: kein Hinweis
  if not News.newer(change.new_version, change.old_version) then return end
  storage.news = { version = change.new_version }
  storage.news_seen = {}
  log(("UTL: Update %s -> %s, Hinweis im Chat"):format(change.old_version, change.new_version))
  for _, player in pairs(game.connected_players) do News.show(player) end
end)

-- Wer beim Update nicht da war (oder im Einzelspiel erst danach verbunden ist), bekommt ihn beim Beitreten
Events.on(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if player then News.show(player) end
end)

return News
