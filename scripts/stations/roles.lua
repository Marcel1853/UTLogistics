--- Leitet aus Modus + Schaltern die Rollen ab, mit denen Leser und Dispatcher arbeiten.
local Roles = {}

function Roles.derive(cfg)
  local station = cfg.mode == "station"
  local roles = cfg.roles or {}
  -- Cleanup mit „Inhalt wieder anbieten“ ist zusätzlich Anbieter
  local offers = cfg.mode == "cleanup" and cfg.cleanup and cfg.cleanup.offer or false
  -- Lager: nimmt an und gibt ab; mit „Restladung annehmen“ zugleich Ziel für Restladung
  local storage_mode = cfg.mode == "storage"
  roles.storage = storage_mode
  roles.provider = (station and cfg.provide) or (offers and true) or storage_mode
  roles.requester = (station and cfg.request) or storage_mode
  roles.depot = cfg.mode == "depot"
  roles.fuel = cfg.mode == "fuel"
  roles.cleanup = cfg.mode == "cleanup" or (storage_mode and cfg.storage ~= nil and cfg.storage.accept_leftover == true)
  cfg.roles = roles
  return roles
end

return Roles
