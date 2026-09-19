--- Leitet aus Modus + Schaltern die Rollen ab, mit denen Leser und Dispatcher arbeiten.
local Roles = {}

function Roles.derive(cfg)
  local station = cfg.mode == "station"
  local roles = cfg.roles or {}
  roles.provider = station and cfg.provide or false
  roles.requester = station and cfg.request or false
  roles.depot = cfg.mode == "depot"
  roles.fuel = cfg.mode == "fuel"
  roles.cleanup = cfg.mode == "cleanup"
  cfg.roles = roles
  return roles
end

return Roles
