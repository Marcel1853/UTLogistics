--- Leitet aus Modus + Schaltern die Rollen ab, mit denen Leser und Dispatcher arbeiten.
local Roles = {}

function Roles.derive(cfg)
  local station = cfg.mode == "station"
  local roles = cfg.roles or {}
  -- Cleanup mit „Inhalt wieder anbieten“ ist zusätzlich Anbieter
  local offers = cfg.mode == "cleanup" and cfg.cleanup and cfg.cleanup.offer or false
  roles.provider = (station and cfg.provide) or (offers and true) or false
  roles.requester = station and cfg.request or false
  roles.depot = cfg.mode == "depot"
  roles.fuel = cfg.mode == "fuel"
  roles.cleanup = cfg.mode == "cleanup"
  cfg.roles = roles
  return roles
end

return Roles
