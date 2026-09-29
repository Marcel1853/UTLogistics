--- Netz-Kombinator mit Lampe am Startplatz des Beispiel-Szenarios: Modus „Züge“, die Lampe
--- leuchtet, solange ein Zug einen Auftrag fährt. Zum Nachbauen – Fenster per Klick öffnen.
local Signs = require("__UTLogistics__/scripts/lib/signs")

local W = defines.wire_connector_id

return function(surface, at)
  local force = game.forces["player"]
  local x, y = at.x, at.y
  local readout = surface.create_entity({ name = "utl-network-combinator", position = { x - 2.5, y - 4.5 },
    force = force, raise_built = true })
  local lamp = surface.create_entity({ name = "small-lamp", position = { x - 0.5, y - 4.5 }, force = force })
  if not (readout and lamp) then return false end
  remote.call("utl", "configure_readout", readout.unit_number, { mode = "trains" })

  local cb = lamp.get_or_create_control_behavior()
  cb.circuit_enable_disable = true
  cb.circuit_condition = { first_signal = { type = "virtual", name = "utl-trains-busy" }, comparator = ">", constant = 0 }
  readout.get_wire_connector(W.circuit_red, true).connect_to(lamp.get_wire_connector(W.circuit_red, true))

  surface.create_entity({ name = "medium-electric-pole", position = { x - 1.5, y - 5.5 }, force = force })
  local power = surface.create_entity({ name = "electric-energy-interface", position = { x - 3, y - 7 }, force = force })
  if power then
    power.power_production = 100000
    power.electric_buffer_size = 1000000
  end
  Signs.place(surface, { x - 1.5, y - 9.5 }, "bsp-readout", { type = "item", name = "utl-network-combinator" })
  return true
end
