-- Führt eine Tipps-&-Tricks-Szene (prototypes/tips/simulation-code.lua) in einer normalen
-- Welt aus und prüft, ob UTL darin wirklich liefert. Welche Szene: scene.lua.
local code = require("__UTLogistics__/prototypes/tips/simulation-code")
local scene = require("scene")
local seen = {}
script.on_nth_tick(30, function(e)
  if e.tick == 30 then
    game.surfaces[1].request_to_generate_chunks({ 0, 0 }, 3)
    game.surfaces[1].force_generate_chunk_requests()
    assert(load(code[scene]))()
    return
  end
  for _, d in pairs(remote.call("utl", "get_deliveries")) do
    if not seen[d.state] then log(("[TIPS] %s erstes %s nach %d s"):format(scene, d.state, (e.tick - 30) / 60)) end
    seen[d.state] = (seen[d.state] or 0) + 1
    if d.chained then seen.chained = true end
  end
  for _, t in pairs(game.train_manager.get_trains({})) do
    if t.station and t.station.backer_name == "Tankstelle" then seen.fuel = true end
    if t.station and t.station.backer_name == "Cleanup" then seen.cleanup = true end
    if t.station and t.station.backer_name == "Abnehmer 2" then seen.second = true end
    if t.station and t.station.backer_name == "Depot" and t.state == defines.train_state.wait_station then seen.depot = true end
  end
  if e.tick == 1500 or e.tick == 3000 then
    for _, t in pairs(game.train_manager.get_trains({})) do
      local c = {}
      for _, list in pairs(t.locomotives) do for _, l in pairs(list) do c[#c + 1] = l.get_fuel_inventory().get_item_count("coal") .. "@" .. l.position.x end end
      log("[TIPS] MANIFEST KOHLE tick " .. e.tick .. ": " .. table.concat(c, " "))
    end
  end
  if e.tick == 900 then
    for _, d in pairs(remote.call("utl", "get_deliveries")) do log("[TIPS] MANIFEST " .. serpent.line(d.manifest) .. " state " .. d.state) end
    for _, t in pairs(game.train_manager.get_trains({})) do
      log("[TIPS] MANIFEST cargo " .. serpent.line(t.get_contents()) .. " wait " .. serpent.line(t.get_schedule().get_record({ schedule_index = t.get_schedule().current })))
    end
  end
  if e.tick == 600 or e.tick == 3000 then
    local info = {}
    for _, st in pairs(game.surfaces[1].find_entities_filtered({ type = { "train-stop" } })) do
      local g = remote.call("utl", "get_station", st.unit_number)
      info[#info + 1] = st.backer_name .. "=" .. (g and (g.config.mode .. " P" .. serpent.line(g.provide) .. " R" .. serpent.line(g.request)) or "-")
    end
    local tr = {}
    for _, t in pairs(game.train_manager.get_trains({})) do tr[#tr + 1] = t.state .. "@" .. (t.station and t.station.backer_name or "-") .. " x" .. t.front_stock.position.x end
    log("[TIPS] " .. scene .. " DIAG stationen " .. remote.call("utl", "station_count") .. " frei " .. remote.call("utl", "idle_train_count") .. " | " .. table.concat(info, "; ") .. " | züge " .. table.concat(tr, " "))
  end
  if e.tick % 1800 == 0 then
    log(("[TIPS] %s tick %d: %s chained=%d"):format(scene, e.tick, serpent.line(seen), remote.call("utl", "chained_count")))
  end
end)
