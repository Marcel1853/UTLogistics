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

-- Je Stil eigene Symbole: { classic = icons, flat = icons } – es gilt das zur Start-Einstellung
-- „Signal-Stil“ passende; fehlt es, bleibt das Symbol von UTL. Eine einfache Liste gilt für beide.
local style = settings.startup["utl-signal-style"].value == "flat" and "flat" or "classic"
local function for_style(entry)
  if type(entry) == "table" and (entry.classic or entry.flat) then return entry[style], true end
  return entry, false
end

local applied = 0
for name, entry in pairs(block.data or {}) do
  local icons, per_style = for_style(entry)
  local signal = data.raw["virtual-signal"][name]
  if not (type(name) == "string" and name:sub(1, 4) == "utl-" and signal) then
    log("UTL: Signal-Symbol für unbekanntes Signal „" .. tostring(name) .. "“ übergangen")
  elseif per_style and icons == nil then
    -- nur für den anderen Stil angegeben: UTLs Symbol bleibt
  elseif not valid(icons) then
    log("UTL: Signal-Symbol für „" .. name .. "“ ungültig (Liste von { icon = …, icon_size = … } erwartet), übergangen")
  else
    signal.icons = icons
    signal.icon = nil
    applied = applied + 1
  end
end
if applied > 0 then log("UTL: " .. applied .. " Signal-Symbole von anderen Mods übernommen") end
