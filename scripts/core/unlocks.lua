--- Was eine Force freigeschaltet hat. Mit der Map-Einstellung „UTL-Funktionen brauchen
--- Forschung“ = aus ist alles frei; sonst zählen die Forschungen (prototypes/technologies).
--- Nur Lesezugriffe auf `force.technologies` – billig, kein Zwischenspeicher nötig.
local Config = require("scripts.core.config")

local Unlocks = {}

Unlocks.MAX_NETWORKS = 3
Unlocks.LOADING_TECH = "utl-loading-control"
Unlocks.NETWORK_TECHS = { "utl-networks-1", "utl-networks-2", "utl-networks-3" }
-- Waren je Lager: Grundstufe (utl-storage) und die Forschungen II–IV
Unlocks.STORAGE_SLOTS = { 8, 12, 16, 20 }
Unlocks.STORAGE_SLOT_TECHS = { "utl-storage-2", "utl-storage-3", "utl-storage-4" }

local function research_required()
  local cfg = Config.get()
  return not cfg or cfg.research_required ~= false
end

local function researched(force, name)
  local tech = force and force.valid and force.technologies[name]
  return tech ~= nil and tech.researched
end

--- Wie viele Partner darf ein Netz dieser Force haben (0 … 3)?
function Unlocks.networks_limit(force)
  if not research_required() then return Unlocks.MAX_NETWORKS end
  local limit = 0
  for i, name in ipairs(Unlocks.NETWORK_TECHS) do
    if researched(force, name) then limit = i end
  end
  return limit
end

Unlocks.STORAGE_TECH = "utl-storage"

--- Lager freigeschaltet?
function Unlocks.storage(force)
  return not research_required() or researched(force, Unlocks.STORAGE_TECH)
end

--- Wie viele Waren darf ein Lager dieser Force haben (8 … 20)?
function Unlocks.storage_slots(force)
  local slots = Unlocks.STORAGE_SLOTS
  if not research_required() then return slots[#slots] end
  local count = slots[1]
  for i, name in ipairs(Unlocks.STORAGE_SLOT_TECHS) do
    if researched(force, name) then count = slots[i + 1] end
  end
  return count
end

--- Wagenfilter und Auftrags-Ausgabe freigeschaltet?
function Unlocks.loading(force)
  return not research_required() or researched(force, Unlocks.LOADING_TECH)
end

--- Force einer Station (Signalquelle oder Haltestelle).
function Unlocks.force_of(station)
  local entity = station and (station.entity or station.stop)
  return entity and entity.valid and entity.force or nil
end

return Unlocks
