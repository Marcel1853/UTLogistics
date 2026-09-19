--- Kleine Helfer: Schlüssel für Items/Flüssigkeiten inkl. Qualität.
--- Schlüssel-Format: "<typ>|<name>|<qualität>", z. B. "item|iron-plate|normal".
local Util = {}

-- Cache nur im Lua-Zustand (deterministisch aus den Eingaben ableitbar, kein storage nötig).
local key_cache = { item = {}, fluid = {} }

--- Liefert den Schlüssel zu einer SignalID oder nil für andere Signaltypen.
function Util.signal_key(signal_id)
  local kind = signal_id.type or "item"
  local by_name = key_cache[kind]
  if not by_name then return nil end -- virtuelle Signale usw. sind keine Ware
  local name = signal_id.name
  if not name then return nil end
  local quality = signal_id.quality or "normal"
  local by_quality = by_name[name]
  if not by_quality then
    by_quality = {}
    by_name[name] = by_quality
  end
  local key = by_quality[quality]
  if not key then
    key = kind .. "|" .. name .. "|" .. quality
    by_quality[quality] = key
  end
  return key
end

--- Zerlegt einen Schlüssel wieder in Typ, Name und Qualität.
function Util.split_key(key)
  return key:match("^([^|]+)|(.+)|([^|]+)$")
end

--- Sprite-Pfad für einen Schlüssel.
function Util.sprite_for_key(key)
  local kind, name = Util.split_key(key)
  return kind .. "/" .. name
end

local stack_cache = {}

--- Stapelgröße eines Items zu einem Schlüssel, nil bei Flüssigkeiten.
function Util.stack_size(key)
  local cached = stack_cache[key]
  if cached ~= nil then return cached or nil end
  local kind, name = Util.split_key(key)
  local proto = kind == "item" and prototypes.item[name]
  local size = proto and proto.stack_size or false
  stack_cache[key] = size
  return size or nil
end

--- Zahl aus einem Eingabefeld: normale Zahl oder Rechenausdruck wie „100*2“, „8000/4“,
--- „(1+2)*3“ (über helpers.evaluate_expression). nil, wenn ungültig oder unvollständig.
function Util.parse_number(text)
  local value = tonumber(text)
  if not value then
    local ok, result = pcall(helpers.evaluate_expression, text)
    value = ok and result or nil
  end
  if value and value == value and value ~= math.huge and value ~= -math.huge then return value end
  return nil
end

--- Abstand zum Quadrat (spart die Wurzel).
function Util.dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

return Util
