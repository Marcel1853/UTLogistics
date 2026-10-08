--- Züge, die ein anderer Mod festhält (Schnittstelle `hold_train`): UTL schickt sie nirgendwohin,
--- nimmt sie nicht in den Depot-Pool, bricht nichts ab und meldet sie nicht als festgefahren.
--- storage.trains.held[train_id] = Name des Mods.
local Held = {}

--- Name des Mods, der den Zug festhält, sonst nil.
function Held.owner(train_id)
  local held = storage.trains.held
  return held and held[train_id]
end

function Held.is(train_id)
  return Held.owner(train_id) ~= nil
end

return Held
