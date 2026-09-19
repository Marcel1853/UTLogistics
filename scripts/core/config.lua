--- Zwischenspeicher der Map-Einstellungen, damit der Heißpfad nicht ständig
--- `settings.global[...]` abfragt.
local Config = {}

function Config.refresh()
  local s = settings.global
  storage.cfg = {
    heartbeat_interval = s["utl-heartbeat-interval"].value,
    station_batch_size = s["utl-station-batch-size"].value,
    max_deliveries = s["utl-max-deliveries-per-cycle"].value,
    fuel_threshold = s["utl-fuel-threshold"].value,
    chaining = s["utl-chaining"].value,
    alert_no_train_minutes = s["utl-alert-no-train-minutes"].value,
    default_provide_threshold = s["utl-default-provide-threshold"].value,
    default_request_threshold = s["utl-default-request-threshold"].value,
    debug_log = s["utl-debug-log"].value,
  }
end

--- Nur lesen, auch in on_load erlaubt.
function Config.get()
  return storage.cfg
end

return Config
