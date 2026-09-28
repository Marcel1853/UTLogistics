--- Bahnhofsplätze des Lasttest-Gitters und welche Station auf welchen Platz kommt (von builder.lua
--- gerufen). Reine Rechnung, baut nichts – so kennen Gleis- und Stationsbau dieselben Plätze.
local Places = {}

local BLOCK = 224 -- Rastermaß der City Blocks (wie builder.lua)

--- Anbieter und Abnehmer (Tankstellen, Cleanup und Lager verteilt assign() eigens über die Karte).
local function layout(cfg)
  local stations = {}
  for _, item in ipairs(cfg.items) do
    for k = 1, cfg.providers_per_item do stations[#stations + 1] = { kind = "provider", item = item, name = "Anbieter " .. item .. " " .. k } end
    for k = 1, cfg.requesters_per_item do
      local spec = { kind = "requester", item = item, name = "Abnehmer " .. item .. " " .. k }
      -- jeder dritte mit Stahlkisten und Abfluss über ein SR-Latch (bleibt eine Weile voll)
      spec.latch = k % 3 == 0
      -- einzelne nur für Züge einer Länge (Teile = Lok + Wagen); welche, hängt vom Netz des
      -- Platzes ab (siehe exact_length)
      spec.exact = ({ [2] = 1, [4] = 2, [5] = 3, [7] = 4 })[k] -- 1.–4. Länge der erlaubten
      stations[#stations + 1] = spec
    end
  end
  for _, fluid in ipairs(cfg.fluids or {}) do
    for k = 1, cfg.providers_per_fluid do stations[#stations + 1] = { kind = "provider", item = fluid, name = "Anbieter " .. fluid .. " " .. k } end
    for k = 1, cfg.requesters_per_fluid do stations[#stations + 1] = { kind = "requester", item = fluid, name = "Abnehmer " .. fluid .. " " .. k } end
  end
  return stations
end

--- `count` Plätze gleichmäßig über die Karte: ein Raster aus Zielpunkten, je Punkt der nächste
--- freie Platz (`used` merkt belegte Plätze).
local function spread(places, count, used, span, columns)
  local picked = {}
  if count <= 0 then return picked end
  local k = columns or math.ceil(math.sqrt(count))
  local rows = math.ceil(count / k)
  for i = 0, count - 1 do
    local tx = (i % k + 0.5) / k * span
    local ty = (math.floor(i / k) + 0.5) / rows * span
    local best, best_d
    for j, place in ipairs(places) do
      if not used[j] then
        local dx, dy = place.pa[1] - tx, place.pa[2] - ty
        local d = dx * dx + dy * dy
        if not best_d or d < best_d then best, best_d = j, d end
      end
    end
    if best then
      used[best] = true
      picked[#picked + 1] = best
    end
  end
  return picked
end

--- Feste Zuglänge (min = max) für einen Abnehmer: nur Längen, deren Züge sein Netz erreichen
--- (`cfg.lengths[Netz]`, das Netz folgt aus der Spalte des Platzes wie in lasttest.lua).
local function exact_length(cfg, spec, place)
  local column = math.floor(place.pa[1] / BLOCK)
  local net = cfg.networks[#cfg.networks].name
  for _, n in ipairs(cfg.networks) do
    if column <= n.to then net = n.name break end
  end
  local allowed = cfg.lengths and cfg.lengths[net]
  if not allowed then return end
  local length = allowed[(spec.exact - 1) % #allowed + 1]
  spec.min_length, spec.max_length = length, length
  spec.name = spec.name .. (" (nur %d Teile)"):format(length)
end

--- Jedem Platz eine Station zuordnen: Tankstellen und Cleanup im Raster verteilt, Anbieter und
--- Abnehmer mit festem Sprung über die restlichen Plätze gestreut (nicht zeilenweise, sonst
--- lägen alle Anbieter im Norden); übrige Plätze werden Abnehmer (Wunsch Marcel).
function Places.assign(cfg, places, span)
  local specs, used = {}, {}
  for _, j in ipairs(spread(places, cfg.fuel, used, span)) do specs[j] = { kind = "fuel", name = "Tankstelle" } end
  -- Cleanup: die ersten je Flüssigkeit eins mit Pumpen (nur diese Flüssigkeit), die übrigen für alle Items
  for n, j in ipairs(spread(places, cfg.cleanup, used, span)) do
    local fluid = (cfg.fluids or {})[n]
    specs[j] = fluid and { kind = "cleanup", item = fluid, name = "Cleanup " .. fluid } or { kind = "cleanup", name = "Cleanup", offer = cfg.cleanup_offer }
  end
  -- Lager: je Ware eins, 4 × 2 über die Karte (zwischen den Reihen der Tankstellen)
  for n, j in ipairs(spread(places, cfg.storage or 0, used, span, 4)) do
    local item = cfg.items[(n - 1) % #cfg.items + 1]
    specs[j] = { kind = "storage", item = item, name = "Lager " .. item }
  end
  local free = {}
  for j = 1, #places do if not used[j] then free[#free + 1] = j end end
  local list = layout(cfg)
  local counters = {}
  local extra = 0
  while #list < #free do
    extra = extra + 1
    local item = cfg.items[((extra - 1) % #cfg.items) + 1]
    counters[item] = (counters[item] or cfg.requesters_per_item) + 1
    list[#list + 1] = { kind = "requester", item = item, name = "Abnehmer " .. item .. " " .. counters[item] }
  end
  local total = #free
  local function gcd(x, y) while y ~= 0 do x, y = y, x % y end return x end
  local step = math.max(1, math.floor(total * 0.618))
  while total > 1 and gcd(step, total) ~= 1 do step = step + 1 end
  for i = 0, total - 1 do specs[free[(i * step) % total + 1]] = list[i + 1] end
  for j, spec in pairs(specs) do
    if spec.exact then exact_length(cfg, spec, places[j]) end
  end
  return specs
end

--- Abstellbahnhof im Inneren des Blocks mit Ecke (X, Y): Einfahrt vom Nord-Außengleis des
--- West-Korridors (Rechtskurve nach Osten), schräge Weichenstraße auf YARD_TRACKS parallele
--- Depotgleise, schräge Sammelstraße, Ausfahrt ins Süd-Außengleis des Ost-Korridors.

--- Alle Bahnhofsplätze des Gitters (n × n Blöcke): je Korridorstück zwei (eine je Außenseite).
--- Senkrecht: Gleis x+35 nach Süden (Bahnhof westlich), x+61 nach Norden (östlich).
--- Waagerecht: Gleis y+35 nach Westen (nördlich), y+61 nach Osten (südlich).
function Places.slots(n, skip, ox, oy)
  local list = {}
  ox, oy = ox or 0, oy or 0
  local function add_slot(o, pa)
    local key = o .. ":" .. pa[1] .. ":" .. pa[2]
    if not skip[key] then list[#list + 1] = { o = o, pa = pa } end
  end
  for k = 0, n do
    for l = 0, n - 1 do
      local x, y0 = BLOCK * k + ox, BLOCK * l + oy
      add_slot("S", { x + 35, y0 + 81 })
      add_slot("N", { x + 61, y0 + 239 })
      local y, x0 = BLOCK * k + oy, BLOCK * l + ox
      add_slot("W", { x0 + 239, y + 35 })
      add_slot("E", { x0 + 81, y + 61 })
    end
  end
  -- zeilenweise sortieren: aufeinanderfolgende Stationen liegen beieinander
  table.sort(list, function(a, b)
    local ra, rb = math.floor(a.pa[2] / BLOCK), math.floor(b.pa[2] / BLOCK)
    if ra ~= rb then return ra < rb end
    if a.pa[1] ~= b.pa[1] then return a.pa[1] < b.pa[1] end
    return a.pa[2] < b.pa[2]
  end)
  return list
end


return Places
