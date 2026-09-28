--- Netz-Kombinatoren: Liste und Einstellungen. Eigene Tabelle, nicht storage.stations – ein
--- Netz-Kombinator ist keine Station (Reader und Dispatcher sollen ihn nicht sehen).
---
--- storage.readouts = { by_unit = { [unit] = { unit, entity, config, last } }, count, cursor }
---   config = { network = "default", mode = "stock"|"storage"|"shortage"|"trains",
---              star = false (mit verbundenen Netzen), transit = false (unterwegs mitzählen) }
---   last   = zuletzt geschriebene Signale { [key] = Menge } (nur neu schreiben, wenn anders)
local Aggregate = require("scripts.readout.aggregate")
local Heartbeat = require("scripts.core.heartbeat")

local Readouts = {}

Readouts.MODES = { "stock", "storage", "shortage", "trains" }
local VALID_MODE = { stock = true, storage = true, shortage = true, trains = true }

local function data()
  local readouts = storage.readouts
  if not readouts then
    readouts = { by_unit = {}, count = 0 }
    storage.readouts = readouts
  end
  return readouts
end
Readouts.data = data

--- Einstellungen prüfen und fehlende Werte ergänzen (auch für Blaupausen-Tags und Kopieren).
function Readouts.clean(config)
  local cfg = {}
  config = type(config) == "table" and config or {}
  cfg.network = type(config.network) == "string" and config.network ~= "" and config.network or "default"
  cfg.mode = VALID_MODE[config.mode] and config.mode or "stock"
  cfg.star = config.star == true
  cfg.transit = config.transit == true
  return cfg
end

function Readouts.get(unit)
  return data().by_unit[unit]
end

--- Netz-Kombinator aufnehmen (Bau, Klon, Blaupause). Liefert den Eintrag.
function Readouts.add(entity, config)
  local readouts = data()
  local unit = entity.unit_number
  local entry = readouts.by_unit[unit]
  if entry then return entry end
  entry = { unit = unit, entity = entity, config = Readouts.clean(config) }
  readouts.by_unit[unit] = entry
  readouts.count = readouts.count + 1
  script.register_on_object_destroyed(entity)
  -- Die Werte setzt UTL; der Spieler bedient das eigene Fenster, nicht das des Konstant-Kombinators.
  entity.operable = true
  Aggregate.activate()
  Heartbeat.update_registration()
  return entry
end

--- Netz-Kombinator ist weg.
function Readouts.remove(unit)
  local readouts = data()
  if not readouts.by_unit[unit] then return end
  readouts.by_unit[unit] = nil
  readouts.count = readouts.count - 1
  if readouts.cursor == unit then readouts.cursor = nil end
  if readouts.count <= 0 then
    readouts.count = 0
    Aggregate.deactivate()
  end
  Heartbeat.update_registration()
end

--- Einstellungen ändern (Fenster, Kopieren, Blaupause); beim nächsten Durchlauf neu schreiben.
function Readouts.configure(entry, changes)
  local merged = {}
  for key, value in pairs(entry.config) do merged[key] = value end
  for key, value in pairs(changes or {}) do merged[key] = value end
  entry.config = Readouts.clean(merged)
  entry.last = nil
end

return Readouts
