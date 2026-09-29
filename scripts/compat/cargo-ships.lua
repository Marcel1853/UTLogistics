--- Cargo Ships: Blaupause „Gleis ↔ Wasserweg“ (Wunsch Marcel). Der Upgrade-Planer bietet diese
--- Zuordnung nicht an (andere Austauschgruppen), deshalb tauscht UTL die Namen in der Blaupause
--- selbst: Gleise ↔ Wasserwege (ohne die veralteten), Signal ↔ Boje, Kettensignal ↔ Kettenboje,
--- Haltestelle ↔ Hafen, UTL-Haltestelle ↔ UTL-Hafen. Ein zweiter Klick tauscht zurück. Nur in
--- Blaupausen – gebaut wird wie immer (Wasserwege nur auf Wasser).
local Events = require("scripts.core.events")
local C = require("scripts.core.constants")

local Water = {}

Water.SHORTCUT = "utl-blueprint-water"

-- Paare in beide Richtungen; nur die, die es als Prototyp gibt
local PAIRS = {
  { "straight-rail", "straight-waterway" },
  { "half-diagonal-rail", "half-diagonal-waterway" },
  { "curved-rail-a", "curved-waterway-a" },
  { "curved-rail-b", "curved-waterway-b" },
  { "rail-signal", "buoy" },
  { "rail-chain-signal", "chain_buoy" },
  { "train-stop", "port" },
  { C.train_stop, C.utl_port },
}

local swap_map = nil
local function swaps()
  if swap_map then return swap_map end
  swap_map = {}
  for _, pair in ipairs(PAIRS) do
    local a, b = pair[1], pair[2]
    if prototypes.entity[a] and prototypes.entity[b] then
      swap_map[a], swap_map[b] = b, a
    end
  end
  return swap_map
end

--- Namen in einer Blaupause (LuaItemStack oder LuaRecord) tauschen. Liefert die Zahl getauschter
--- Bauteile oder nil, wenn es keine Blaupause mit Inhalt ist.
function Water.convert(blueprint)
  if not (blueprint and blueprint.valid) then return nil end
  if blueprint.object_name == "LuaItemStack" and not (blueprint.valid_for_read and blueprint.is_blueprint) then return nil end
  if blueprint.object_name == "LuaRecord" and blueprint.type ~= "blueprint" then return nil end
  local ok, entities = pcall(blueprint.get_blueprint_entities)
  if not (ok and entities) then return nil end
  local map, changed = swaps(), 0
  for _, entity in pairs(entities) do
    local other = map[entity.name]
    if other then
      entity.name = other
      changed = changed + 1
    end
  end
  if changed > 0 and not pcall(blueprint.set_blueprint_entities, entities) then return nil end
  return changed
end

Events.on(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= Water.SHORTCUT then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local stack = player.cursor_stack
  local target = player.cursor_record --[[@as LuaRecord|LuaItemStack|nil]]
  if not target and stack and stack.valid_for_read and stack.is_blueprint then target = stack end
  local changed = Water.convert(target)
  if changed == nil then
    player.create_local_flying_text({ text = { "utl-water.no-blueprint" }, create_at_cursor = true })
  else
    player.create_local_flying_text({ text = { "utl-water.done", changed }, create_at_cursor = true })
  end
end)

return Water
