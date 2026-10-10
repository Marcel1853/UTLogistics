--- Ein Add-on wurde entfernt: Seine Anmeldungen fallen weg, Stationen mit seiner Rolle werden zu
--- Stationen ohne Aufgabe (ihre Daten in cfg.ext bleiben, falls das Add-on zurückkommt), seine
--- Aufträge enden, seine festgehaltenen Züge werden frei.
local Events = require("scripts.core.events")
local Registry = require("scripts.stations.registry")
local Roles = require("scripts.stations.roles")
local Addons = require("scripts.api.addons")
local Jobs = require("scripts.trains.jobs")
local Log = require("scripts.lib.log")
local AddonSignals = require("scripts.readout.addon-signals")

Events.on_configuration_changed(function()
  Addons.forget_missing()
  AddonSignals.forget_missing()
  local roles = Addons.data().roles
  for _, station in pairs(storage.stations.by_unit) do
    local cfg = station.config
    if cfg.addon_role and not roles[cfg.addon_role] then
      Log.info("Station " .. station.unit .. ": Rolle „" .. cfg.addon_role .. "“ gibt es nicht mehr (Add-on entfernt).")
      Roles.apply_addon(cfg, nil)
      Registry.config_changed(station)
    end
  end
  for _, job in pairs(storage.jobs.active) do
    if not script.active_mods[job.mod] then Jobs.cancel(job, "mod-removed") end
  end
  for id, mod in pairs(storage.trains.held) do
    if not script.active_mods[mod] then storage.trains.held[id] = nil end
  end
end)
