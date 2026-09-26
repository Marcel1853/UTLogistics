-- Init-Code der Tipps-&-Tricks-Szenen (laufen als Konsolenbefehl in der Simulation, mit UTL
-- aktiv). Als Texte, damit tools/tipstest sie genauso ausführen kann. Die Bausteine liegen in
-- prototypes/tips/scenes/.
local P = require("__UTLogistics__/prototypes/tips/scenes/common")
local Links = require("__UTLogistics__/prototypes/tips/scenes/links")
local Manager = require("__UTLogistics__/prototypes/tips/scenes/manager")
local scene, window = P.scene, P.window
local SIMPLE, FUEL, CLEANUP, ROLES = P.SIMPLE, P.FUEL, P.CLEANUP, P.ROLES
local CLEANUP_RETURN = P.CLEANUP_RETURN
local REQUESTS, DEPOTS, COPY, ROLE_SIGNS = P.REQUESTS, P.DEPOTS, P.COPY, P.ROLE_SIGNS

-- Anzeigefelder mit Erklärtext je Szene: { x, y, Sprachschlüssel (utl-sign.*), Symbol }
local function signs(list)
  local out = {}
  for _, entry in ipairs(list) do
    out[#out + 1] = ("sign(%s, %s, %q, %s)"):format(entry[1], entry[2], entry[3],
      entry[4] or '{ type = "item", name = "utl-train-stop" }')
  end
  return table.concat(out, "\n")
end
local COMBINATOR = '{ type = "item", name = "utl-station-combinator" }'
local COMBINATOR_SIGNS = signs({ { 22, 8, "combinator-output", COMBINATOR }, { -16.5, -4.5, "combinator-input", COMBINATOR } })
local FUEL_SIGN = signs({ { 10, 9, "fuel", '{ type = "item", name = "coal" }' } })
local CLEANUP_ITEM = '{ type = "item", name = "copper-plate" }'

return {
  -- UTL-Haltestellen, echter Lieferbetrieb (und direkt der nächste Auftrag)
  basic = scene({ SIMPLE, ROLE_SIGNS, "train(-8, 150)", "show()" }),
  -- dazu das UTL-Panel am Abnehmer (Anforderung, Live-Waren, Unterwegs)
  stop_window = scene({ SIMPLE, "train(-8, 150)", window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- normale Haltestellen mit UTL-Stations-Combinator (Ausgang → Haltestelle, Kisten → Eingang)
  combinator = scene({ vanilla = true, SIMPLE, COMBINATOR_SIGNS, "train(-8, 150)",
    window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- alle Rollen: Depot, Anbieter, Abnehmer, Tankstelle, Cleanup
  roles = scene({ SIMPLE, FUEL, ROLES, ROLE_SIGNS, FUEL_SIGN, signs({ { 5, -4, "cleanup", CLEANUP_ITEM } }),
    "train(-8, 8)", "show()" }),
  -- Zielbestand und zwei Waren in einem Zug
  requests = scene({ REQUESTS, signs({ { -16.5, -4.5, "requests-target", CLEANUP_ITEM } }),
    "train(-8, 150)", window('remote.call("utl", "open_station", player.index, r_unit, nil, true)') }),
  -- Reiter „Werte“ am Anbieter
  values = scene({ SIMPLE, "train(-8, 150)", window('remote.call("utl", "open_station", player.index, p_unit, 2, true)') }),
  -- Zug an einer gleichnamigen Haltestelle ohne Depot-Rolle
  depots = scene({ SIMPLE, DEPOTS, signs({ { -15, 6, "depots-fake" }, { -3, 9, "depots-real" } }), "train(-18, 150)", "show()" }),
  -- Zug mit wenig Treibstoff fährt zuerst zur Tankstelle (beide Loks werden betankt)
  fuel = scene({ SIMPLE, FUEL, FUEL_SIGN, "train(-8, 8)", "show()" }),
  -- Zug mit Restladung wird zuerst an der Cleanup-Station geleert
  cleanup = scene({ SIMPLE, CLEANUP, signs({ { 13, 6, "cleanup", CLEANUP_ITEM } }), "train(-8, 150).cargo_wagons[1].insert({ name = 'copper-plate', count = 100 })",
    window('remote.call("utl", "open_station", player.index, c_unit, 2, true)') }),
  -- Cleanup bietet seinen Inhalt wieder an: der Zug holt das Kupfer dort ab
  cleanup_return = scene({ SIMPLE, CLEANUP_RETURN, signs({ { 13, 6, "cleanup-return", CLEANUP_ITEM } }), "train(-8, 150)",
    window('remote.call("utl", "open_station", player.index, c_unit, 2, true)') }),
  -- Einstellungen vom Abnehmer auf „Abnehmer 2“ kopieren (einmal, ohne Zug), danach dessen Fenster
  copy = scene({ SIMPLE, COPY, signs({ { -9, -4, "copy", '{ type = "item", name = "blueprint" }' } }), [[
show({
  { 0, nil, function() return game.simulation.move_cursor({ position = { -29, -1 } }) end },
  { 1, function() game.simulation.control_down({ control = "copy-entity-settings", notify = true }) end },
  { 0.5, function() game.simulation.control_up({ control = "copy-entity-settings" }) end },
  { 0, nil, function() return game.simulation.move_cursor({ position = { -9, -1 } }) end },
  { 0.5, function() game.simulation.control_down({ control = "paste-entity-settings", notify = true }) end },
  { 0.5, function() game.simulation.control_up({ control = "paste-entity-settings" }) end },
  { 0, nil, function() return game.simulation.move_cursor({ position = player.position }) end },
  { 1, function() remote.call("utl", "open_station", player.index, second_unit, nil, true) end },
}, true)
]] }),
  -- Zwei getrennte Netze nebeneinander, mit Kamerafahrt
  networks = require("__UTLogistics__/prototypes/tips/scenes/ring"),
  -- Netzverbund im Stationsfenster und im Manager
  links = Links.links,
  manager_networks = Links.manager_networks,
  -- Manager: Reiter nacheinander, Inventar mit angeklickter Ware
  manager = Manager.manager,
  manager_inventory = Manager.manager_inventory,
}
