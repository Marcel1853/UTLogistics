-- Eigene Symbole anderer Mods für UTL-Signale übernehmen (Schnittstelle „utl-signal-icons“,
-- siehe prototypes/signals/virtual-signals.lua). Ungültige Einträge werden mit Hinweis im Log
-- übergangen, damit eine fehlerhafte Fremd-Mod UTL nicht am Laden hindert.
local block = data.raw["mod-data"] and data.raw["mod-data"]["utl-signal-icons"]
if not block then return end

local function valid(icons)
  if type(icons) ~= "table" or #icons == 0 then return false end
  for _, layer in ipairs(icons) do
    if type(layer) ~= "table" or type(layer.icon) ~= "string" then return false end
  end
  return true
end

local applied = 0
for name, icons in pairs(block.data or {}) do
  local signal = data.raw["virtual-signal"][name]
  if not (type(name) == "string" and name:sub(1, 4) == "utl-" and signal) then
    log("UTL: Signal-Symbol für unbekanntes Signal „" .. tostring(name) .. "“ übergangen")
  elseif not valid(icons) then
    log("UTL: Signal-Symbol für „" .. name .. "“ ungültig (Liste von { icon = …, icon_size = … } erwartet), übergangen")
  else
    signal.icons = icons
    signal.icon = nil
    applied = applied + 1
  end
end
if applied > 0 then log("UTL: " .. applied .. " Signal-Symbole von anderen Mods übernommen") end
