--- Blocklängen im Lasttest-Gleisnetz (Wunsch Marcel): In einen Knoten hinein ein Kettensignal,
--- hinaus ein normales Signal, und hinter jedem normalen Signal mindestens Platz für einen großen
--- Zug (Lok + 4 Wagen). Die Blocksignale der Korridore aus dem City Block stehen alle 32 Felder –
--- zu kurz. Diese Stufe entfernt zu dicht stehende Korridorsignale; Ausfahrtsignale hinter einer
--- Weiche bleiben immer stehen (dort geht es nicht anders). Die Kreisel selbst bleiben, wie sie
--- sind (Marcel hat sie schon ordentlich beschildert): nur Signale auf den Korridoren fallen weg.
---
--- API (lua-api.factorio.com, LuaEntity): Ein Signal ist der *Ausgang* des Segments, an dessen
--- Gleis es hängt (get_rail_segment_signal(dir, false)); der Block dahinter beginnt am nächsten
--- Gleis. Ein Segment endet an Weichen, Signalen und Haltestellen, ein Block nur an Signalen.
local Blocks = {}

Blocks.MIN_LENGTH = 35 -- Lok + 4 Wagen à 7 Felder

local D = defines.rail_direction
local CONN = { defines.rail_connection_direction.left, defines.rail_connection_direction.straight,
  defines.rail_connection_direction.right }
local RAILS = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail" }
local SIGNALS = { "rail-signal", "rail-chain-signal" }

local function is_fork(rail)
  for _, d in ipairs({ D.front, D.back }) do
    local n = 0
    for _, c in ipairs(CONN) do
      if rail.get_connected_rail({ rail_direction = d, rail_connection_direction = c }) then n = n + 1 end
    end
    if n > 1 then return true end
  end
  return false
end

--- Gleise nach dem Ende des Segments von `rail` in Fahrtrichtung `dir`, je { Gleis, Richtung }.
local function step(rail, dir)
  local e, edir = rail.get_rail_segment_end(dir)
  local out = {}
  for _, c in ipairs(CONN) do
    local n = e.get_connected_rail({ rail_direction = edir, rail_connection_direction = c })
    if n then
      for _, x in ipairs({ D.front, D.back }) do
        for _, c2 in ipairs(CONN) do
          if n.get_connected_rail({ rail_direction = x, rail_connection_direction = c2 }) == e then
            out[#out + 1] = { n, x == D.front and D.back or D.front }
          end
        end
      end
    end
  end
  return out
end

--- Länge des Blocks hinter `sig` und das Signal an seinem Ende; nil, wenn der Block gleich
--- verzweigt oder im Nichts endet (Kartenrand). Endet er an einer Weiche, deren Kettensignal genau
--- auf dem Weichengleis sitzt (so erkennt ihn die Segment-Abfrage nicht), liefert sie Länge, nil, true.
local function block_after(sig)
  for _, rail in pairs(sig.get_connected_rails()) do
    for _, d in ipairs({ D.front, D.back }) do
      local o = rail.get_rail_segment_signal(d, false)
      if o and o.unit_number == sig.unit_number then
        local nexts = step(rail, d)
        if #nexts ~= 1 then return nil end
        local r, dir, len = nexts[1][1], nexts[1][2], 0
        for _ = 1, 100 do
          len = len + r.get_rail_segment_length()
          local last = r.get_rail_segment_signal(dir, false)
          if last then return len, last end
          nexts = step(r, dir)
          if #nexts > 1 then return len, nil, true end
          if #nexts == 0 then return nil end
          r, dir = nexts[1][1], nexts[1][2]
        end
        return nil
      end
    end
  end
  return nil
end

local BLOCK = 224  -- Rastermaß der City Blocks
local CROSSING = 96 -- Kreisel: 0 … 96 Felder ab der Blockecke, in beiden Richtungen

--- Werden alle Einfahrten in den Block vor `sig` von Kettensignalen bewacht? Dann bleibt dort
--- nie ein Zug stehen, und `sig` darf vor einer Einfahrt wegfallen, auch wenn es eine Ausfahrt ist.
local function chained_before(sig)
  for _, rail in pairs(sig.get_connected_rails()) do
    for _, d in ipairs({ D.front, D.back }) do
      local o = rail.get_rail_segment_signal(d, false)
      if o and o.unit_number == sig.unit_number then
        local inbound = rail.get_inbound_signals()
        if #inbound == 0 then return false end
        for _, other in pairs(inbound) do
          if other.name ~= "rail-chain-signal" then return false end
        end
        return true
      end
    end
  end
  return false
end

--- Zu kurze Blöcke im Bereich `area` zusammenlegen (`origin` = Ecke des Rasters). Liefert die Zahl
--- entfernter Signale.
function Blocks.fit(surface, area, origin)
  local function in_crossing(sig)
    local x, y = (sig.position.x - origin[1]) % BLOCK, (sig.position.y - origin[2]) % BLOCK
    return x <= CROSSING and y <= CROSSING
  end
  -- Ausfahrten: Signale, die einen Block mit Weiche verlassen – bleiben stehen
  local exits = {}
  for _, rail in pairs(surface.find_entities_filtered({ area = area, type = RAILS })) do
    if is_fork(rail) then
      for _, sig in pairs(rail.get_outbound_signals()) do exits[sig.unit_number] = true end
    end
  end
  local removed = 0
  local function remove(sig)
    sig.destroy()
    removed = removed + 1
  end
  -- Vom Anfang jeder Signalreihe in Fahrtrichtung: ist der Block dahinter zu kurz, fällt das nächste
  -- Korridorsignal weg; vor einer Einfahrt (Kettensignal) fällt das kurze Signal selbst weg.
  -- In Fahrtrichtung, damit beide Richtungen eines Korridors gleich aufgeteilt werden.
  -- Anfang jeder Signalreihe: normale Signale, zu denen kein anderes normales Signal hinführt
  local signals = surface.find_entities_filtered({ area = area, name = "rail-signal" })
  local reached = {}
  for _, sig in pairs(signals) do
    local _, last = block_after(sig)
    if last and last.valid and last.name == "rail-signal" then reached[last.unit_number] = true end
  end
  for _, start in pairs(signals) do
    local current = start.valid and not reached[start.unit_number] and start or nil
    for _ = 1, 50 do
      if not current then break end
      local len, last, fork = block_after(current)
      if not len then break end
      local next_name = last and last.valid and last.name
      if fork or next_name == "rail-chain-signal" then
        local plain = not exits[current.unit_number] or chained_before(current)
        if len < Blocks.MIN_LENGTH and plain and not in_crossing(current) then remove(current) end
        break
      elseif not (next_name and last) then
        break
      elseif len < Blocks.MIN_LENGTH and not exits[last.unit_number] and not in_crossing(last) then
        remove(last) -- Block wird länger, gleich noch einmal messen
      else
        current = last
      end
    end
  end
  return removed
end

Blocks.block_after = block_after
Blocks.SIGNALS = SIGNALS

return Blocks
