--- Einstellungs-Kombinator (`utl-station-settings`): unsichtbarer Konstant-Kombinator auf jeder
--- Haltestelle. Er spiegelt die Einstellungen der Station in zwei **ausgeschaltete** Abschnitte
--- (geben nichts aufs Kabel):
---   1. Anforderungs-Slots 1–20 (Ware und Menge),
---   2. Rolle (`utl-role`) und die Zahlenwerte, die vom Standard abweichen (Signal je Feld aus
---      fields.lua) – nur geänderte, damit das Parameter-Menü übersichtlich bleibt (Wunsch Marcel).
--- Factorio erkennt darin Blaupausen-Parameter und fragt sie beim Platzieren ab (die UTL-Tags
--- der Haltestelle sieht es nicht). Wird der Kombinator aus einer Blaupause gebaut, liest UTL die
--- Abschnitte zurück – die gewählten Werte gewinnen gegen die Tags.
local C = require("scripts.core.constants")
local Fields = require("scripts.stations.fields")
local Requests = require("scripts.stations.requests")
local Roles = require("scripts.stations.roles")

local Settings = {}

local ROLE_SIGNAL = "utl-role"

-- Rolle ↔ Zahl (Signal utl-role). 0 = Station ohne Aufgabe.
local ROLE_OF = {
  { mode = "station", provide = true },
  { mode = "station", provide = true, active = true },
  { mode = "station", request = true },
  { mode = "station", provide = true, request = true },
  { mode = "depot" },
  { mode = "fuel" },
  { mode = "cleanup" },
  { mode = "storage" },
  { mode = "station", provide = true, request = true, active = true },
}

local function role_code(cfg)
  if cfg.mode ~= "station" then
    for code, r in ipairs(ROLE_OF) do
      if r.mode == cfg.mode then return code end
    end
    return 0
  end
  local active = cfg.provide and cfg.active_provider == true
  for code, r in ipairs(ROLE_OF) do
    if r.mode == "station" and (r.provide or false) == (cfg.provide or false)
      and (r.request or false) == (cfg.request or false) and (r.active or false) == (active or false) then
      return code
    end
  end
  return 0
end

local function apply_role(cfg, code)
  local r = ROLE_OF[code]
  if code == 0 then r = { mode = "station" } end
  if not r then return end
  cfg.mode = r.mode
  if r.mode == "station" then
    cfg.provide, cfg.request = r.provide == true, r.request == true
    cfg.active_provider = r.active == true
  end
end

Settings.role_code, Settings.apply_role, Settings.ROLE_COUNT = role_code, apply_role, #ROLE_OF

--- Zahlenfelder in fester Reihenfolge (Abschnitt 2 nach der Rolle).
local FIELD_ORDER, BY_SIGNAL = {}, {}
for _, group in ipairs(Fields.groups) do
  for _, field in ipairs(group.fields) do
    FIELD_ORDER[#FIELD_ORDER + 1] = field
    BY_SIGNAL[field.signal] = field
  end
end

local function virtual(name) return { type = "virtual", name = name, quality = "normal", comparator = "=" } end

--- Inhalt der beiden Abschnitte als Liste { [slot] = LogisticFilter }.
local function wanted(cfg)
  local requests = {}
  for slot = 1, Requests.slot_count do
    local r = cfg.requests[slot]
    if r and r.signal and r.signal.name then
      requests[slot] = { value = { type = r.signal.type or "item", name = r.signal.name,
        quality = r.signal.quality or "normal", comparator = "=" }, min = r.count }
    end
  end
  local values = { { value = virtual(ROLE_SIGNAL), min = role_code(cfg) } }
  for _, field in ipairs(FIELD_ORDER) do
    local value = cfg[field.key]
    if value ~= nil and value ~= Fields.default(field) then
      values[#values + 1] = { value = virtual(field.signal), min = value }
    end
  end
  return requests, values
end

local function signature(requests, values)
  local parts = {}
  for slot = 1, Requests.slot_count do
    local f = requests[slot]
    parts[#parts + 1] = f and (f.value.type .. f.value.name .. f.value.quality .. f.min) or "-"
  end
  for _, f in ipairs(values) do parts[#parts + 1] = f.value.name .. "=" .. f.min end
  return table.concat(parts, "|")
end

--- Abschnitt `index` holen bzw. anlegen, ausgeschaltet.
local function section(behavior, index)
  while behavior.sections_count < index do behavior.add_section() end
  local s = behavior.get_section(index)
  s.active = false
  return s
end

--- Einstellungen der Station in den Kombinator schreiben (nur bei Änderung).
function Settings.write(station)
  local entity = station.settings
  if not (entity and entity.valid) then return end
  local requests, values = wanted(station.config)
  local sig = signature(requests, values)
  if station.settings_sig == sig then return end
  local behavior = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  local s1, s2 = section(behavior, 1), section(behavior, 2)
  s1.filters = {}
  for slot, filter in pairs(requests) do s1.set_slot(slot, filter) end
  s2.filters = {}
  for i, filter in ipairs(values) do s2.set_slot(i, filter) end
  station.settings_sig = sig
end

--- Abschnitte zurück in die Einstellungen lesen (nach dem Bau aus einer Blaupause). Platzhalter
--- (`parameter-0…9`, nicht aufgelöst) werden übergangen. Liefert true, wenn sich etwas geändert hat.
function Settings.read(station)
  local entity = station.settings
  if not (entity and entity.valid) then return false end
  local behavior = entity.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior?]]
  if not behavior then return false end
  local cfg = station.config
  local s1, s2 = behavior.get_section(1), behavior.get_section(2)
  if s1 then
    for slot = 1, Requests.slot_count do
      local f = s1.get_slot(slot)
      local v = f and f.value
      if v and v.name then
        local proto = (v.type == "fluid" and prototypes.fluid or prototypes.item)[v.name]
        if proto and not proto.parameter then
          cfg.requests[slot] = { signal = { type = v.type or "item", name = v.name, quality = v.quality },
            count = f.min or 0 }
        end
      else
        cfg.requests[slot] = nil
      end
    end
    Requests.rebuild_map(cfg)
  end
  if s2 then
    for i = 1, #FIELD_ORDER + 1 do
      local f = s2.get_slot(i)
      local name = f and f.value and f.value.name
      if name == ROLE_SIGNAL then
        apply_role(cfg, f.min or 0)
      elseif name then
        local field = BY_SIGNAL[name]
        if field and f.min then cfg[field.key] = Fields.clamp(field, f.min) end
      end
    end
  end
  Roles.derive(cfg)
  station.settings_sig = nil -- beim nächsten Schreiben ohne Platzhalter neu setzen
  return true
end

--- Kombinator einer Station finden, aus einem Geist wiederbeleben oder neu bauen. Liefert ihn und
--- `revived` = true, wenn er aus einer Blaupause kam (dann gelten seine Werte).
function Settings.ensure(station)
  local existing = station.settings
  local stop = station.stop
  if existing and existing.valid then
    -- Station hat eine andere Haltestelle bekommen (Stations-Kombinator umverkabelt): mitziehen
    local p = existing.position
    if stop and stop.valid and existing.surface == stop.surface
      and math.abs(p.x - stop.position.x) < 0.7 and math.abs(p.y - stop.position.y) < 0.7 then
      return existing, false
    end
    existing.destroy()
  end
  station.settings = nil
  station.settings_sig = nil
  if not (stop and stop.valid) then return nil, false end
  local surface, p = stop.surface, stop.position
  local area = { { p.x - 0.6, p.y - 0.6 }, { p.x + 0.6, p.y + 0.6 } }
  local entity = surface.find_entities_filtered({ area = area, name = C.station_settings })[1]
  -- vor der Haltestelle aus einer Blaupause gebaut (Settings.adopt): seine Werte gelten
  local pending = storage.settings_pending
  local revived = entity ~= nil and pending ~= nil and pending[entity.unit_number] == true
  if revived then pending[entity.unit_number] = nil end
  if not entity then
    local ghost = surface.find_entities_filtered({ area = area, ghost_name = C.station_settings })[1]
    if ghost then
      local _, created = ghost.revive({ raise_revive = false })
      entity, revived = created, created ~= nil
    end
  end
  entity = entity or surface.create_entity({ name = C.station_settings, position = p, force = stop.force,
    raise_built = false })
  if not entity then return nil, false end
  entity.operable = false
  entity.minable_flag = false
  entity.destructible = false
  station.settings = entity
  return entity, revived
end

--- Station gebaut oder geändert: Kombinator sicherstellen; kam er aus einer Blaupause, seine Werte
--- übernehmen, sonst die Einstellungen hineinschreiben. Liefert true, wenn Werte übernommen wurden.
function Settings.refresh(station)
  local entity, revived = Settings.ensure(station)
  if not entity then return false end
  if revived then return Settings.read(station) end
  Settings.write(station)
  return false
end

--- Station weg: Kombinator mit abreißen.
function Settings.destroy(station)
  local entity = station.settings
  station.settings = nil
  station.settings_sig = nil
  if entity and entity.valid then entity.destroy() end
end

--- Ein Einstellungs-Kombinator wurde einzeln gebaut (Blaupause, Bau-Reihenfolge: Haltestelle zuerst):
--- der Station darunter zuordnen und seine Werte übernehmen. Liefert die Station oder nil.
function Settings.adopt(entity)
  local stop = entity.surface.find_entities_filtered({ position = entity.position, radius = 0.6, type = "train-stop" })[1]
  local unit = stop and storage.stations.by_stop[stop.unit_number]
  local station = unit and storage.stations.by_unit[unit]
  if not station then
    -- Haltestelle steht noch nicht (Geist): merken, ihr Bau übernimmt die Werte (Settings.ensure)
    entity.operable = false
    entity.minable_flag = false
    entity.destructible = false
    storage.settings_pending = storage.settings_pending or {}
    storage.settings_pending[entity.unit_number] = true
    return nil
  end
  if station.settings and station.settings.valid and station.settings ~= entity then station.settings.destroy() end
  entity.operable = false
  entity.minable_flag = false
  entity.destructible = false
  station.settings = entity
  Settings.read(station)
  return station
end

return Settings
