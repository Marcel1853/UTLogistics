--- Zusätzliche Signale von Add-ons für die Netz-Kombinatoren eines Netzes (Schnittstelle
--- set_network_signals). Das Add-on setzt sie, wenn sich bei ihm etwas ändert; jeder Netz-Kombinator
--- dieses Netzes (mit „verbundene Netze“ auch des Sterns) gibt sie in jedem Modus zusätzlich aus.
--- storage.addon_signals["<ort>|<netz>"][mod] = { [key] = Menge } (Ort = Oberfläche + Team).
local AddonSignals = {}

local function data()
  storage.addon_signals = storage.addon_signals or {}
  return storage.addon_signals
end

--- Signale eines Mods für ein Netz setzen; `values` = { [key] = Menge } oder nil zum Löschen.
function AddonSignals.set(place, network, mod, values)
  local key = place .. "|" .. network
  local by_net = data()[key] or {}
  by_net[mod] = values and next(values) and values or nil
  data()[key] = next(by_net) and by_net or nil
end

function AddonSignals.get(place, network)
  return data()[place .. "|" .. network]
end

--- Zu `values` addieren (in Output.compute); `add` = dessen Hilfsfunktion.
function AddonSignals.add_into(values, place, names, add)
  local all = storage.addon_signals
  if not all or next(all) == nil then return end -- ohne Add-on: nichts zu tun
  for _, name in ipairs(names) do
    local by_net = all[place .. "|" .. name]
    if by_net then
      for _, signals in pairs(by_net) do
        for key, amount in pairs(signals) do add(values, key, amount) end
      end
    end
  end
end

--- Einträge entfernter Mods löschen (api/addons-cleanup.lua).
function AddonSignals.forget_missing()
  for key, by_net in pairs(data()) do
    for mod in pairs(by_net) do
      if not script.active_mods[mod] then by_net[mod] = nil end
    end
    if next(by_net) == nil then storage.addon_signals[key] = nil end
  end
end

return AddonSignals
