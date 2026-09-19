--- Warnungen wie bei LTN: Factorio-Warnungen (rechts unten, anklickbar, auf der Karte),
--- pro Spieler in drei Gruppen abschaltbar (Einstellungen → Mod-Einstellungen → Spieler):
---   no_train  – Bedarf und Anbieter da, aber kein passender freier Zug
---   cargo     – Restladung, Fehlmenge beim Anbieter
---   train     – kein Weg, kein freies Depot, Tanken fehlgeschlagen, Lieferung abgebrochen
--- Gleiche Warnung (Schlüssel) höchstens alle REPEAT_TICKS, damit nichts flackert oder spammt.
local Alerts = {}

local REPEAT_TICKS = 600

local SETTINGS = {
  no_train = "utl-alerts-no-train",
  cargo = "utl-alerts-cargo",
  train = "utl-alerts-trains",
}

local ICONS = {
  no_train = { type = "virtual", name = "signal-hourglass" },
  cargo = { type = "virtual", name = "signal-trash-bin" },
  missing = { type = "virtual", name = "signal-alert" },
  no_path = { type = "virtual", name = "signal-no-entry" },
  fuel = { type = "virtual", name = "signal-fuel" },
  canceled = { type = "virtual", name = "signal-deny" },
}

--- Warnung an alle verbundenen Spieler der Force von `entity`, die diese Gruppe nicht
--- abgeschaltet haben. `icon` = Schlüssel aus ICONS, `key` = Schlüssel für die Wiederholsperre.
function Alerts.raise(group, icon, entity, message, key)
  if not (entity and entity.valid) then return end
  local last = storage.alerts
  if key then
    local tick = last[key]
    if tick and game.tick - tick < REPEAT_TICKS then return end
    last[key] = game.tick
  end
  Alerts.log(group, icon, entity, message, key)
  local setting = SETTINGS[group]
  for _, player in pairs(entity.force.connected_players) do
    if player.mod_settings[setting].value then
      player.add_custom_alert(entity, ICONS[icon], message, true)
    end
  end
end

--- Liste für den Manager-Reiter „Alarme“ (neueste zuerst, höchstens LOG_SIZE). Gleicher
--- Schlüssel: vorhandenen Eintrag nach oben holen und hochzählen statt neue Zeile.
local LOG_SIZE = 100

function Alerts.log(group, icon, entity, message, key)
  local list = storage.alert_log
  local entry
  if key then
    for i = 1, #list do
      if list[i].key == key then
        entry = table.remove(list, i)
        break
      end
    end
  end
  if entry then
    entry.count = entry.count + 1
    entry.message = message
  else
    entry = { key = key, group = group, icon = icon, message = message, count = 1 }
  end
  entry.tick = game.tick
  entry.entity = entity
  entry.surface = entity.surface_index
  entry.position = entity.position
  table.insert(list, 1, entry)
  list[LOG_SIZE + 1] = nil
end

--- Sprite-Pfad zum Symbol einer Warnung (für den Manager).
function Alerts.sprite(icon)
  local signal = ICONS[icon]
  return signal and ("virtual-signal/" .. signal.name) or "utility/warning_icon"
end

--- Anzeigename eines Zugs: Name der vorderen Lok, sonst „Zug <id>“.
function Alerts.train_name(train)
  local front = train.valid and train.front_stock
  if front and front.backer_name and front.backer_name ~= "" then return front.backer_name end
  return { "utl-alert.train", train.valid and train.id or "?" }
end

--- Wiederholsperren aufräumen (seltene Heartbeat-Aufgabe), damit storage nicht wächst.
function Alerts.cleanup()
  local now = game.tick
  for key, tick in pairs(storage.alerts) do
    if now - tick >= REPEAT_TICKS then storage.alerts[key] = nil end
  end
end

return Alerts
