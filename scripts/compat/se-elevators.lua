--- Weltraumaufzüge von Space Exploration: welche es gibt, wo ihre Haltestellen stehen und welche
--- Netze über sie liefern dürfen. Ein Aufzug steht auf einem Planeten, sein Gegenstück im Orbit
--- desselben Planeten; jede Seite hat eine eigene Haltestelle („… ↑“ unten, „… ↓“ oben).
---
--- storage.elevators = { by_unit = { [unit] = { main, stop, opposite = unit, place, ok } } }
---   je Seite ein Eintrag; `ok` = fertig gebaut und mit Strom (nur dann fahren Züge durch).
--- storage.elevator_networks = { [force_index] = { [netz] = true } }
---   Schalter „über den Aufzug liefern“ je Team und Netz (Standard aus). Er gilt für das
---   gleichnamige Netz auf beiden Seiten.
--- Ohne SE bleibt alles leer; nichts davon läuft.
local Networks = require("scripts.stations.networks")

local Elevators = {}

local INTERFACE = "space-exploration"
local NAME = "se-space-elevator"

local function data()
  local d = storage.elevators
  if not d then
    d = { by_unit = {} }
    storage.elevators = d
  end
  return d
end

--- Ist SE aktiv (und kennt die Aufzug-Schnittstelle)?
function Elevators.available()
  local interface = remote.interfaces[INTERFACE]
  return interface ~= nil and interface.get_space_elevator_info ~= nil
end

local function info(unit)
  local ok, result = pcall(remote.call, INTERFACE, "get_space_elevator_info", { unit_number = unit })
  return ok and result or nil
end

--- Eine Seite (und ihr Gegenstück) neu einlesen. `entity` = Aufzug-Hauptobjekt einer Seite.
function Elevators.refresh(entity)
  if not (entity and entity.valid and Elevators.available()) then return end
  local d = data()
  local here = info(entity.unit_number)
  local other = here and here.opposite and here.opposite.valid and info(here.opposite.unit_number)
  if not (here and other and here.main and here.main.valid) then
    d.by_unit[entity.unit_number] = nil
    return
  end
  for _, side in ipairs({ { here, other }, { other, here } }) do
    local own, opposite = side[1], side[2]
    local main = own.main
    if main and main.valid then
      d.by_unit[main.unit_number] = {
        main = main,
        stop = own.train_stop,
        opposite = opposite.main.unit_number,
        place = Networks.place_of(main),
        ok = own.constructed == true and own.powered == true,
      }
      script.register_on_object_destroyed(main)
    end
  end
end

--- Alle Aufzüge auf allen Oberflächen neu einlesen (Mod-Änderung, neuer Spielstand).
function Elevators.scan()
  if not Elevators.available() then
    storage.elevators = nil
    return
  end
  data().by_unit = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = NAME })) do
      if not data().by_unit[entity.unit_number] then Elevators.refresh(entity) end
    end
  end
end

--- Aufzug abgerissen: beide Seiten vergessen.
function Elevators.forget(unit)
  local d = storage.elevators
  local entry = d and d.by_unit[unit]
  if not entry then return end
  d.by_unit[unit] = nil
  d.by_unit[entry.opposite] = nil
end

--- Schalter „über den Aufzug liefern“ für ein Netz eines Teams.
function Elevators.enabled(force_index, network)
  local all = storage.elevator_networks
  local of_force = all and all[force_index]
  return of_force ~= nil and of_force[network] == true
end

function Elevators.set_enabled(force_index, network, on)
  storage.elevator_networks = storage.elevator_networks or {}
  local of_force = storage.elevator_networks[force_index] or {}
  of_force[network] = on and true or nil
  storage.elevator_networks[force_index] = next(of_force) and of_force or nil
end

--- Aufzüge, über die `network` von `place` aus liefern darf: Liste von { here, there } (beide Seiten
--- fertig und mit Strom, Schalter des Netzes an).
function Elevators.links(place, network)
  local d = storage.elevators
  if not d then return {} end
  local _, force_index = Networks.split_place(place)
  if not Elevators.enabled(force_index, network) then return {} end
  local list = {}
  for _, entry in pairs(d.by_unit) do
    if entry.place == place and entry.ok and entry.main.valid then
      local there = d.by_unit[entry.opposite]
      if there and there.ok and there.main.valid then list[#list + 1] = { here = entry, there = there } end
    end
  end
  return list
end

--- Gibt es auf `place` überhaupt einen Aufzug (egal ob fertig)? Für die Anzeige des Schalters.
function Elevators.at(place)
  local d = storage.elevators
  if not d then return false end
  for _, entry in pairs(d.by_unit) do
    if entry.place == place then return true end
  end
  return false
end

return Elevators
