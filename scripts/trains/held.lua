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

--- Welchem Mod gehört der Zug gerade? Festgehalten (hold_train, Auftrag) oder frei im Depot eines
--- Add-ons mit eigenen Zügen (Rolle "mod/name"). nil = niemandem (UTL-Zug).
function Held.belongs_to(train_id)
  local owner = Held.owner(train_id)
  if owner then return owner end
  local idle = storage.trains.addon_idle and storage.trains.addon_idle[train_id]
  return idle and idle.role and idle.role:match("^(.-)/") or nil
end

return Held
