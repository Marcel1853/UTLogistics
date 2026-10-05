-- Selbsttest R40 (05.10.2026): Blaupausen-Parameter über den Einstellungs-Kombinator.
-- Vorlage: Abnehmer mit Anforderung parameter-1 = 500. In der Blaupause wird – wie es Factorio nach
-- dem Parameter-Dialog tut – parameter-1 durch Eisen 4000 und die Rolle 3 durch 5 (Depot) ersetzt.
-- Gebaut wird zweimal: Haltestelle zuerst und Einstellungs-Kombinator zuerst.
local Param = {}

local function is_settings(e) return (e.ghost_name or e.name) == "utl-station-settings" and 1 or 0 end

local function place(s, force, stack, y, settings_first)
  local entities = stack.get_blueprint_entities() or {}
  for _, e in ipairs(entities) do
    if e.name == "utl-station-settings" then
      for _, section in ipairs(e.control_behavior.sections.sections) do
        for _, f in ipairs(section.filters or {}) do
          if f.name == "parameter-1" then f.name, f.count = "iron-plate", 4000 end
          if f.name == "utl-role" then f.count = 5 end
        end
      end
    end
  end
  stack.set_blueprint_entities(entities)
  local ghosts = stack.build_blueprint({ surface = s, force = force, position = { 0, y }, build_mode = defines.build_mode.forced })
  table.sort(ghosts, function(a, b)
    if settings_first then return is_settings(a) > is_settings(b) end
    return is_settings(a) < is_settings(b)
  end)
  for _, ghost in ipairs(ghosts) do
    if ghost.valid then ghost.revive({ raise_revive = true }) end
  end
  return s.find_entities_filtered({ name = "utl-train-stop", position = { 0, y + 2 }, radius = 3 })[1]
end

function Param.run(check)
  local s = game.create_surface("utl-selftest-r40")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 3)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -19, 19, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end
  local stop = s.create_entity({ name = "utl-train-stop", position = { 0, 3 }, direction = 4, force = force, raise_built = true })
  if not stop then return check("R40 vorlage gebaut", false) end
  remote.call("utl", "configure_station", stop.unit_number, { mode = "station", provide = false, request = true, network = "R40" })
  remote.call("utl", "set_request", stop.unit_number, 1, { type = "item", name = "parameter-1" }, 500)
  local info = remote.call("utl", "get_station", stop.unit_number) --[[@as table]]
  check("R40 platzhalter ist keine ware", next(info.request) == nil, serpent.line(info.request))

  local inv = game.create_inventory(2)
  inv.insert({ name = "blueprint", count = 2 })
  for i = 1, 2 do
    local mapping = inv[i].create_blueprint({ surface = s, force = force, area = { { -20, -2 }, { 20, 8 } } })
    remote.call("utl", "tag_blueprint", inv[i], mapping, s)
  end
  for i, settings_first in ipairs({ false, true }) do
    local built = place(s, force, inv[i], 20 * i, settings_first)
    local st = built and remote.call("utl", "get_station", built.unit_number) --[[@as table?]]
    local r = st and st.config.requests[1]
    check("R40 parameter aus der blaupause (" .. (settings_first and "kombinator zuerst" or "haltestelle zuerst") .. ")",
      st ~= nil and st.config.mode == "depot" and r ~= nil and r.signal.name == "iron-plate" and r.count == 4000,
      serpent.line(st and { st.config.mode, st.config.requests }))
  end
  inv.destroy()
end

return Param
