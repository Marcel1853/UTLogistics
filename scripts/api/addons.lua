--- Anmeldungen anderer Mods (Add-ons): eigene Rollen, Abschnitt im Stationsfenster, Reiter im
--- Manager. Liegt in storage.addons; das Add-on meldet sich in on_init und on_configuration_changed
--- (erneut) an. Fehlt ein Mod später, räumt UTL hier auf.
---
--- Rückrufe gehen per remote.call an das Add-on und laufen in pcall: Ein Fehler im Add-on wird
--- einmal ins Protokoll geschrieben, UTL macht ohne den Rückruf weiter, statt abzustürzen.
local Log = require("scripts.lib.log")

local Addons = {}

-- Grundrollen, auf die sich eine Add-on-Rolle stützen darf (nil = eigene Rolle ohne Vermittlung)
Addons.BASES = { provider = true, requester = true, provider_requester = true, depot = true, fuel = true,
  cleanup = true, storage = true }

function Addons.data()
  local addons = storage.addons
  if not addons then
    addons = {}
    storage.addons = addons
  end
  addons.roles = addons.roles or {}   -- ["mod/name"] = Rolle (siehe register_role)
  addons.sections = addons.sections or {} -- [mod] = { interface, build }
  addons.tabs = addons.tabs or {}     -- [mod] = { interface, build, caption }
  addons.filters = addons.filters or {} -- [mod] = { interface, build = Filterfunktion }
  return addons
end

--- Gibt es die Funktion `fn` im Interface `interface`?
function Addons.callable(interface, fn)
  local functions = type(interface) == "string" and remote.interfaces[interface]
  return functions ~= nil and functions ~= false and type(fn) == "string" and functions[fn] == true
end

-- Schon gemeldete Fehler je Mod + Funktion (nur für das Protokoll)
local reported = {}

--- Rückruf sicher ausführen. Liefert ok, Ergebnis.
function Addons.call(mod, interface, fn, ...)
  if not Addons.callable(interface, fn) then return false, nil end
  local ok, result = pcall(remote.call, interface, fn, ...)
  if not ok then
    local key = mod .. "|" .. fn
    if not reported[key] then
      reported[key] = true
      Log.info("Add-on „" .. tostring(mod) .. "“: Fehler in " .. interface .. "." .. fn .. " – " .. tostring(result))
    end
    return false, nil
  end
  return true, result
end

--- Rolle eines Add-ons (oder nil). `key` = "mod/name".
function Addons.role(key)
  local addons = storage.addons
  return key and addons and addons.roles and addons.roles[key] or nil
end

--- Alle Rollen sortiert (für das Stationsfenster).
function Addons.role_list()
  local list = {}
  for key, role in pairs(Addons.data().roles) do list[#list + 1] = { key = key, role = role } end
  table.sort(list, function(a, b) return a.key < b.key end)
  return list
end

--- Rolle anmelden. `spec` = { mod, name, caption, tooltip, base, own_trains }. Liefert true oder
--- false und einen Grund.
function Addons.register_role(spec)
  if type(spec) ~= "table" or type(spec.mod) ~= "string" or type(spec.name) ~= "string" then return false, "bad-spec" end
  if not script.active_mods[spec.mod] then return false, "unknown-mod" end
  if spec.base ~= nil and not Addons.BASES[spec.base] then return false, "bad-base" end
  local key = spec.mod .. "/" .. spec.name
  Addons.data().roles[key] = {
    key = key,
    mod = spec.mod,
    name = spec.name,
    caption = spec.caption or spec.name,
    tooltip = spec.tooltip,
    base = spec.base,
    own_trains = spec.base == "depot" and spec.own_trains == true or nil,
  }
  return true
end

--- Eintrag (Abschnitt bzw. Reiter) anmelden: { mod, interface, build, caption }.
local function register(kind, spec)
  if type(spec) ~= "table" or type(spec.mod) ~= "string" then return false, "bad-spec" end
  if not script.active_mods[spec.mod] then return false, "unknown-mod" end
  if not Addons.callable(spec.interface, spec.build) then return false, "unknown-function" end
  Addons.data()[kind][spec.mod] = { mod = spec.mod, interface = spec.interface, build = spec.build, caption = spec.caption }
  return true
end

function Addons.register_section(spec) return register("sections", spec) end
function Addons.register_tab(spec) return register("tabs", spec) end

--- Zugfilter: { mod, interface, filter }; intern wie die anderen Einträge unter `build` abgelegt.
function Addons.register_filter(spec)
  if type(spec) ~= "table" then return false, "bad-spec" end
  return register("filters", { mod = spec.mod, interface = spec.interface, build = spec.filter })
end

--- Sortierte Liste der Einträge einer Art („sections“ oder „tabs“).
function Addons.list(kind)
  local list = {}
  for _, entry in pairs(Addons.data()[kind]) do list[#list + 1] = entry end
  table.sort(list, function(a, b) return a.mod < b.mod end)
  return list
end

--- Alles von Mods entfernen, die nicht mehr aktiv sind. Liefert die Menge der entfernten Rollen.
function Addons.forget_missing()
  local addons = Addons.data()
  local gone = {}
  for key, role in pairs(addons.roles) do
    if not script.active_mods[role.mod] then
      addons.roles[key] = nil
      gone[key] = true
    end
  end
  for _, kind in ipairs({ "sections", "tabs", "filters" }) do
    for mod in pairs(addons[kind]) do
      if not script.active_mods[mod] then addons[kind][mod] = nil end
    end
  end
  return gone
end

return Addons
