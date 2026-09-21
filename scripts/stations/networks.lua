--- Netzwerke einer Station: ein Heimatnetz (`cfg.network`, Standard „default“) und optionale
--- Zusatznetze (`cfg.networks`, Menge von Namen). Zwei Stationen arbeiten zusammen, sobald sich
--- ihre Netzmengen überschneiden. Damit kann z. B. ein Reserve-Depot in mehrere Netze liefern,
--- ohne dass die Netze selbst zusammenwachsen.
local Networks = {}

--- Gehört `name` zu den Netzen dieser Station?
function Networks.matches(cfg, name)
  if cfg.network == name then return true end
  local extra = cfg.networks
  return extra ~= nil and extra[name] == true
end

--- Haben zwei Stationen mindestens ein gemeinsames Netz?
function Networks.shared(a, b)
  if Networks.matches(b, a.network) then return true end
  for name in pairs(a.networks or {}) do
    if Networks.matches(b, name) then return true end
  end
  return false
end

--- Alle Netze einer Station als Liste (Heimatnetz zuerst, Rest alphabetisch) – für Anzeige,
--- Zug-Pools und Vergleiche.
function Networks.list(cfg)
  local list = { cfg.network }
  local extra = {}
  for name in pairs(cfg.networks or {}) do
    if name ~= cfg.network then extra[#extra + 1] = name end
  end
  table.sort(extra)
  for _, name in ipairs(extra) do list[#list + 1] = name end
  return list
end

--- Zusatznetze als Text für Fenster und Manager, z. B. „+Erze +Platten“ (leer, wenn keine).
function Networks.extra_text(cfg)
  local parts = {}
  for i, name in ipairs(Networks.list(cfg)) do
    if i > 1 then parts[#parts + 1] = "+" .. name end
  end
  return table.concat(parts, " ")
end

--- Zusatznetz an- oder abschalten (das Heimatnetz lässt sich nicht als Zusatz setzen).
function Networks.toggle(cfg, name)
  if name == nil or name == "" or name == cfg.network then return false end
  cfg.networks = cfg.networks or {}
  cfg.networks[name] = not cfg.networks[name] or nil
  return true
end

--- Wie viele Zusatznetze hat die Station?
function Networks.extra_count(cfg)
  return #Networks.list(cfg) - 1
end

--- Zusatznetze auf `limit` kürzen (die ersten in alphabetischer Reihenfolge bleiben). Für
--- Blaupausen, eingefügte Einstellungen und die Remote-Schnittstelle. Liefert true bei Änderung.
function Networks.trim(cfg, limit)
  local list = Networks.list(cfg)
  if #list - 1 <= limit then return false end
  local keep = {}
  for i = 2, limit + 1 do keep[list[i]] = true end
  cfg.networks = keep
  return true
end

-- Alle im Spielstand vorhandenen Netznamen; nur ein Lua-Zwischenspeicher, aus storage abgeleitet.
local known = nil

function Networks.invalidate()
  known = nil
end

--- Sortierte Liste aller Netznamen, die irgendeine Station benutzt (für die Schalter im Fenster).
function Networks.known()
  if known then return known end
  local set = { default = true }
  for _, station in pairs(storage.stations.by_unit) do
    local cfg = station.config
    if cfg then
      set[cfg.network] = true
      for name in pairs(cfg.networks or {}) do set[name] = true end
    end
  end
  known = {}
  for name in pairs(set) do known[#known + 1] = name end
  table.sort(known)
  return known
end

return Networks
