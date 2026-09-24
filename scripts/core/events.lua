--- Zentrale Event-Verteilung. Module melden Handler mit `Events.on` an,
--- `Events.register` bindet am Ende alles genau einmal an `script`.
local State = require("scripts.core.state")
local Config = require("scripts.core.config")
local Heartbeat = require("scripts.core.heartbeat")

local Events = {}

local handlers = {} -- [event_id] = { fn, ... }
local config_changed = {} -- zusätzliche Handler für on_configuration_changed
local filters = {}  -- [event_id] = Filter-Liste (optional)

--- Meldet einen Handler an. Filter werden zusammengeführt.
function Events.on(event_id, fn, filter)
  local list = handlers[event_id]
  if not list then
    list = {}
    handlers[event_id] = list
  end
  list[#list + 1] = fn
  if filter then
    local merged = filters[event_id] or {}
    for _, f in ipairs(filter) do merged[#merged + 1] = f end
    filters[event_id] = merged
  end
end

--- Modul-Handler für on_configuration_changed (laufen nach State/Config).
function Events.on_configuration_changed(fn)
  config_changed[#config_changed + 1] = fn
end

local function on_init()
  State.init()
  Config.refresh()
  Heartbeat.update_registration()
end

local function on_load()
  Heartbeat.update_registration()
end

-- Einmalige Datenänderungen stehen als Lua-Migrationen in migrations/ (laufen vorher).
local function on_configuration_changed(data)
  State.init()
  Config.refresh()
  for i = 1, #config_changed do config_changed[i](data) end
  Heartbeat.update_registration()
end

-- Takt neu anmelden, wenn sich ein Kartenwert ändert (Menü oder UTL-Manager)
Config.listen(function() Heartbeat.update_registration() end)

local function on_setting_changed(event)
  if event.setting:sub(1, 4) ~= "utl-" then return end
  -- Im Einstellungsmenü geändert: das Menü gewinnt, ein Manager-Wert für diese Einstellung fällt weg
  if event.player_index and storage.map_config then storage.map_config[event.setting] = nil end
  Config.refresh()
  Config.changed(event.setting)
end

function Events.register()
  script.on_init(on_init)
  script.on_load(on_load)
  script.on_configuration_changed(on_configuration_changed)
  Events.on(defines.events.on_runtime_mod_setting_changed, on_setting_changed)

  for event_id, list in pairs(handlers) do
    local handler
    if #list == 1 then
      handler = list[1]
    else
      handler = function(event)
        for i = 1, #list do list[i](event) end
      end
    end
    script.on_event(event_id, handler, filters[event_id])
  end
end

return Events
