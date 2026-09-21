--- Netzwerke: Jede Station hat ein Heimatnetz (`cfg.network`, Standard „default“). Netze lassen
--- sich zu einem **Stern** verbinden: ein Zentrum und bis zu drei Partner (je nach Forschung).
---
---   * Zentrum und Partner helfen sich gegenseitig: Züge, Depots, Tankstellen und Cleanups des
---     einen bedienen auch den anderen.
---   * Partner helfen sich **nicht** untereinander.
---   * Ein Netz gehört zu höchstens einem Stern – als Zentrum oder als Partner. Ein Partner kann
---     keine eigenen Partner haben und nirgends sonst Partner sein. So entstehen keine Ketten.
---   * Die Zahl der Netze ist frei; begrenzt ist nur die Zahl der Partner je Zentrum.
---   * Sterne gelten je Oberfläche – auf Vulcanus kann man eigene bilden.
---
--- Speicher: storage.network_links[surface_index] = {
---   partners = { [zentrum] = { [partner] = true } },
---   center_of = { [partner] = zentrum },
--- }
local Networks = {}

local function links_of(surface_index, create)
  local all = storage.network_links
  if not all then
    if not create then return nil end
    all = {}
    storage.network_links = all
  end
  local links = all[surface_index]
  if not links and create then
    links = { partners = {}, center_of = {} }
    all[surface_index] = links
  end
  return links
end

local function count(set)
  local n = 0
  for _ in pairs(set or {}) do n = n + 1 end
  return n
end

--- Arbeiten zwei Netze zusammen? Gleiches Netz oder Zentrum ↔ Partner.
function Networks.related(surface_index, a, b)
  if a == b then return true end
  local links = links_of(surface_index)
  if not links then return false end
  local center_of = links.center_of
  return center_of[a] == b or center_of[b] == a
end

--- Das Netz selbst und alle Netze, die ihm helfen (für die Zug-Pools des Dispatchers).
function Networks.related_list(surface_index, name)
  local list = { name }
  local links = links_of(surface_index)
  if not links then return list end
  local center = links.center_of[name]
  if center then
    list[#list + 1] = center
  else
    for partner in pairs(links.partners[name] or {}) do list[#list + 1] = partner end
  end
  return list
end

--- Rolle eines Netzes: { role = "center" | "partner" | nil, center = …, partners = { … } }.
--- Partner alphabetisch sortiert.
function Networks.star(surface_index, name)
  local links = links_of(surface_index)
  local result = { partners = {} }
  if not links then return result end
  local center = links.center_of[name]
  if center then
    result.role, result.center = "partner", center
    return result
  end
  for partner in pairs(links.partners[name] or {}) do result.partners[#result.partners + 1] = partner end
  table.sort(result.partners)
  if #result.partners > 0 then result.role, result.center = "center", name end
  return result
end

--- Kann `partner` mit `center` verbunden werden? Liefert true oder einen Locale-Schlüssel mit
--- dem Grund (utl-gui.link-…).
function Networks.can_link(surface_index, center, partner, limit)
  if not partner or partner == "" or partner == center then return "link-self" end
  local links = links_of(surface_index)
  if links then
    if links.center_of[center] then return "link-center-is-partner" end
    if links.center_of[partner] then return "link-partner-taken" end
    if count(links.partners[partner]) > 0 then return "link-partner-is-center" end
    if count(links.partners[center]) >= limit then return "link-limit" end
  elseif limit < 1 then
    return "link-limit"
  end
  return true
end

--- Zwei Netze verbinden (Zentrum ↔ Partner). Liefert true oder den Grund.
function Networks.link(surface_index, center, partner, limit)
  local ok = Networks.can_link(surface_index, center, partner, limit)
  if ok ~= true then return ok end
  local links = links_of(surface_index, true)
  if not links then return "link-limit" end
  links.partners[center] = links.partners[center] or {}
  links.partners[center][partner] = true
  links.center_of[partner] = center
  Networks.invalidate()
  return true
end

--- Verbindung zwischen zwei Netzen lösen (egal in welcher Richtung angegeben).
function Networks.unlink(surface_index, a, b)
  local links = links_of(surface_index)
  if not links then return false end
  local center, partner = a, b
  if links.center_of[a] == b then center, partner = b, a end
  if links.center_of[partner] ~= center then return false end
  links.center_of[partner] = nil
  local set = links.partners[center]
  if set then
    set[partner] = nil
    if next(set) == nil then links.partners[center] = nil end
  end
  Networks.invalidate()
  return true
end

--- Text für Manager und Stationsliste, z. B. „Eisen ↔ Kupfer, Kohle“ oder „Kupfer → Eisen“;
--- leer, wenn das Netz in keinem Stern ist.
function Networks.link_text(surface_index, name)
  local star = Networks.star(surface_index, name)
  if star.role == "partner" then return "→ " .. star.center end
  if star.role == "center" then return "↔ " .. table.concat(star.partners, ", ") end
  return ""
end

-- Alle im Spielstand vorhandenen Netznamen; nur ein Lua-Zwischenspeicher, aus storage abgeleitet.
local known = nil

function Networks.invalidate()
  known = nil
end

--- Sortierte Liste aller Netznamen: Heimatnetze der Stationen und alle verbundenen Netze.
function Networks.known()
  if known then return known end
  local set = { default = true }
  for _, station in pairs(storage.stations.by_unit) do
    local cfg = station.config
    if cfg and cfg.network then set[cfg.network] = true end
  end
  for _, links in pairs(storage.network_links or {}) do
    for center, partners in pairs(links.partners) do
      set[center] = true
      for partner in pairs(partners) do set[partner] = true end
    end
  end
  known = {}
  for name in pairs(set) do known[#known + 1] = name end
  table.sort(known)
  return known
end

return Networks
