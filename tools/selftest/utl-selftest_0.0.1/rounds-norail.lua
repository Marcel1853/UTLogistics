-- Selbsttest R42 (09.10.2026): Haltestelle ohne Gleis (Blaupause: Halt steht vor dem Gleis).
-- Ein Abnehmer ohne Gleis im selben Netz darf weder beim Losschicken noch bei der Anschlussfahrt
-- (Dispatch.chain → Reach.check) einen Absturz in request_train_path auslösen und bekommt keine
-- Lieferung; der Abnehmer mit Gleis wird normal beliefert. Gemeldet von Lt_Tinkle im Mod-Portal.
local NoRail = {}

local W = defines.wire_connector_id
local CARGO = defines.inventory.cargo_wagon
local LINE = 1

local function stop(s, force, name, x, y, east)
  local e = s.create_entity({ name = "utl-train-stop", position = { x, y }, direction = east and 4 or 12,
    force = force, raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

function NoRail.build(check)
  local s = game.create_surface("utl-selftest-r42")
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 4)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  for x = -85, 85, 2 do s.create_entity({ name = "straight-rail", position = { x, LINE }, direction = 4, force = force }) end
  local depot = stop(s, force, "R42-Depot", 10, LINE + 2, true)
  local prov = stop(s, force, "R42-Anbieter", 60, LINE + 2, true)
  local req = stop(s, force, "R42-Abnehmer", -60, LINE - 2, false)
  local lonely = stop(s, force, "R42-OhneGleis", -30, LINE + 40, false) -- weit weg vom Gleis
  check("R42 haltestelle ohne gleis gebaut", lonely.valid and lonely.connected_rail == nil)
  local c = s.create_entity({ name = "constant-combinator", position = { 63.5, LINE + 5.5 }, force = force }) --[[@as LuaEntity]]
  local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  behavior.get_section(1).set_slot(1, { value = { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, min = 2000 })
  c.get_wire_connector(W.circuit_green, true).connect_to(prov.get_wire_connector(W.circuit_green, true))
  local function cfg(e, changes) changes.network = "R42"; remote.call("utl", "configure_station", e.unit_number, changes) end
  cfg(depot, { mode = "depot" })
  cfg(prov, { mode = "station", provide = true, request = false })
  for _, e in ipairs({ req, lonely }) do
    cfg(e, { mode = "station", provide = false, request = true, request_threshold = 100 })
    remote.call("utl", "set_request", e.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  end
  local l1 = s.create_entity({ name = "locomotive", position = { 4, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local wagon = s.create_entity({ name = "cargo-wagon", position = { -3, LINE }, direction = 4, force = force }) --[[@as LuaEntity]]
  local l2 = s.create_entity({ name = "locomotive", position = { -10, LINE }, direction = 12, force = force }) --[[@as LuaEntity]]
  l1.insert({ name = "coal", count = 150 })
  l2.insert({ name = "coal", count = 150 })
  local schedule = l1.train.get_schedule()
  schedule.add_record({ station = "R42-Depot", wait_conditions = { { type = "inactivity", ticks = 120 } } })
  schedule.go_to_station(1)
  l1.train.manual_mode = false
  return { start = game.tick, loco = l1, wagon = wagon, req = req.unit_number }
end

--- Liefert true, wenn R42 fertig ist.
function NoRail.watch(r, check)
  if not r or r.done then return true end
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if d.to == "R42-OhneGleis" then r.wrong = true end
    if d.to == "R42-Abnehmer" then
      local inv = r.wagon.get_inventory(CARGO)
      if d.state == "loading" and not r.loaded then
        r.loaded = true
        inv.insert({ name = "iron-plate", count = d.manifest["item|iron-plate|normal"] or 400 })
      elseif d.state == "unloading" and not r.unloaded then
        r.unloaded = game.tick
        inv.clear()
        -- danach nur noch der Abnehmer ohne Gleis: Anschlussfahrt prüft ihn (früher Absturz)
        remote.call("utl", "configure_station", r.req, { request = false })
      end
    end
  end
  -- nach dem Entladen noch 20 s laufen lassen (Abfahrt, Anschlussfahrt, weitere Dispatch-Läufe)
  if r.unloaded and game.tick - r.unloaded > 1200 then
    r.done = true
    check("R42 haltestelle ohne gleis: kein absturz, keine lieferung dorthin", not r.wrong)
  elseif not r.done and game.tick - r.start > 30000 then
    r.done = true
    check("R42 haltestelle ohne gleis: kein absturz, keine lieferung dorthin", false,
      serpent.line({ geladen = r.loaded, entladen = r.unloaded, falsch = r.wrong }))
  end
  return r.done
end

return NoRail
