--- Leitet aus Modus + Schaltern die Rollen ab, mit denen Leser und Dispatcher arbeiten.
local Roles = {}

function Roles.derive(cfg)
  -- Rolle eines Add-ons, das es (nicht mehr) gibt (Blaupause aus einem anderen Spielstand, Mod
  -- entfernt): Station ohne Aufgabe, ihre Daten in cfg.ext bleiben
  if cfg.addon_role then
    local known = storage.addons and storage.addons.roles
    if known and not known[cfg.addon_role] then
      cfg.addon_role = nil
      if cfg.mode == "addon" then cfg.mode, cfg.provide, cfg.request = "station", false, false end
    end
  end
  local station = cfg.mode == "station"
  local roles = cfg.roles or {}
  -- Cleanup mit „Inhalt wieder anbieten“ ist zusätzlich Anbieter
  local offers = cfg.mode == "cleanup" and cfg.cleanup and cfg.cleanup.offer or false
  -- Lager: nimmt an und gibt ab; mit „Restladung annehmen“ zugleich Ziel für Restladung
  local storage_mode = cfg.mode == "storage"
  roles.storage = storage_mode
  roles.provider = (station and cfg.provide) or (offers and true) or storage_mode
  -- Tankstelle mit „Treibstoff anfordern“: ihre Anforderungs-Slots gelten wie bei einem Abnehmer
  roles.requester = (station and cfg.request) or storage_mode or (cfg.mode == "fuel" and cfg.fuel_request == true)
  roles.depot = cfg.mode == "depot"
  roles.addon = cfg.addon_role -- Rolle eines Add-ons ("mod/name"), siehe Roles.apply_addon
  roles.fuel = cfg.mode == "fuel"
  roles.cleanup = cfg.mode == "cleanup" or (storage_mode and cfg.storage ~= nil and cfg.storage.accept_leftover == true)
  cfg.roles = roles
  return roles
end

--- Grundrolle einer Add-on-Rolle auf die eingebauten Schalter abbilden. `base` nil = eigene Rolle
--- (mode "addon"): UTL vermittelt dort nichts, meldet nur Ankunft/Abfahrt.
local BASE = {
  provider = { mode = "station", provide = true },
  requester = { mode = "station", request = true },
  provider_requester = { mode = "station", provide = true, request = true },
  depot = { mode = "depot" },
  fuel = { mode = "fuel" },
  cleanup = { mode = "cleanup" },
  storage = { mode = "storage" },
}

--- Add-on-Rolle `key` setzen (Rolle aus api/addons.lua: { key, base }), nil = zurück zu „ohne Aufgabe“.
function Roles.apply_addon(cfg, role)
  local b = role and (BASE[role.base or ""] or { mode = "addon" }) or { mode = "station" }
  cfg.mode = b.mode
  cfg.provide = b.provide == true
  cfg.request = b.request == true
  cfg.active_provider = false
  cfg.addon_role = role and role.key or nil
  return Roles.derive(cfg)
end

return Roles
