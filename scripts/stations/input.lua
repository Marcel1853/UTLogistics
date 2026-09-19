--- Liest die Eingangssignale einer Station – egal ob UTL-Combinator oder UTL-Haltestelle.
local Input = {}

local W = defines.wire_connector_id

--- Anschlüsse je Stationsart: Combinator = Eingangsseite, Haltestelle = ihr Schaltnetz.
local CONNECTORS = {
  combinator = { W.combinator_input_red, W.combinator_input_green },
  stop = { W.circuit_red, W.circuit_green },
}

--- Alle Signale (rot + grün zusammen) oder nil.
function Input.read(station)
  local entity = station.entity
  if not entity.valid then return nil end
  local c = CONNECTORS[station.kind]
  return entity.get_signals(c[1], c[2])
end

return Input
