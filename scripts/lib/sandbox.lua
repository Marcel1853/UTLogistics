--- Für die Szenarien (nicht für den Mod selbst): alles erforscht und Cheat-Modus – auch nach einem
--- Mod-Update. Beim Start erforscht jedes Szenario alles; bringt ein späteres Update eine neue
--- Forschung mit (z. B. „UTL: Lager“ in 0.0.8), wäre sie im laufenden Spielstand sonst gesperrt.
--- Benutzung in der control.lua eines Szenarios:
---   script.on_configuration_changed(Sandbox.refresh)
local Sandbox = {}

--- Alle Teams außer den eingebauten Gegnern: alles erforschen; alle Spieler in den Cheat-Modus.
function Sandbox.refresh()
  for _, force in pairs(game.forces) do
    if force.name ~= "enemy" and force.name ~= "neutral" then force.research_all_technologies() end
  end
  for _, player in pairs(game.players) do player.cheat_mode = true end
end

return Sandbox
