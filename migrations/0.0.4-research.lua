--- 0.0.4: Ladesteuerung und Zusatznetze brauchen jetzt Forschung. Wer UTL schon erforscht hat,
--- soll beim Update nichts verlieren: Für jede Force mit „Unified Train Logistics“ werden die
--- neuen Forschungen gleich mit freigeschaltet. Neue Spielstände erforschen sie ganz normal.
--- Läuft einmal je Spielstand (vor on_configuration_changed).
local NEW = { "utl-loading-control", "utl-networks-1", "utl-networks-2", "utl-networks-3" }

for _, force in pairs(game.forces) do
  local base = force.technologies["utl-train-logistics"]
  if base and base.researched then
    for _, name in ipairs(NEW) do
      local tech = force.technologies[name]
      if tech and not tech.researched then tech.researched = true end
    end
  end
end
