--- Was eine Force freigeschaltet hat. Mit der Map-Einstellung „UTL-Funktionen brauchen
--- Forschung“ = aus ist alles frei; sonst zählen die Forschungen (prototypes/technologies).
--- Nur Lesezugriffe auf `force.technologies` – billig, kein Zwischenspeicher nötig.
local Config = require("scripts.core.config")

local Unlocks = {}

Unlocks.MAX_NETWORKS = 3
Unlocks.LOADING_TECH = "utl-loading-control"
Unlocks.NETWORK_TECHS = { "utl-networks-1", "utl-networks-2", "utl-networks-3" }

local function research_required()
  local cfg = Config.get()
  return not cfg or cfg.research_required ~= false
end

local function researched(force, name)
  local tech = force and force.valid and force.technologies[name]
  return tech ~= nil and tech.researched
end

--- Wie viele Zusatznetze darf eine Station dieser Force haben (0 … 3)?
function Unlocks.networks_limit(force)
  if not research_required() then return Unlocks.MAX_NETWORKS end
  local limit = 0
  for i, name in ipairs(Unlocks.NETWORK_TECHS) do
    if researched(force, name) then limit = i end
  end
  return limit
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
