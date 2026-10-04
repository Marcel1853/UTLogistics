--- Linker Kasten (wie LTN Combinator): Status, Vorschau, Netzwerk, Rollen-Häkchen.
local Builder = require("scripts.gui.common.builder")
local Roles = require("scripts.stations.roles")
local Nets = require("scripts.gui.station.section-networks")
local Unlocks = require("scripts.core.unlocks")

local Main = {}

-- Häkchen in zwei Spalten: links Station (Anbieter/aktiver Anbieter/Abnehmer), rechts Sonderrollen.
local ROLE_COLUMNS = {
  { "provider", "active_provider", "requester" },
  { "depot", "fuel", "cleanup", "storage" },
}

local function role_checked(cfg, role)
  if role == "provider" then return cfg.mode == "station" and cfg.provide end
  if role == "requester" then return cfg.mode == "station" and cfg.request end
  if role == "active_provider" then return cfg.mode == "station" and cfg.provide and cfg.active_provider == true end
  return cfg.mode == role
end

--- `with_preview` = false beim Panel an der UTL-Haltestelle (Vanilla zeigt sie schon).
function Main.build(parent, station, with_preview)
  local cfg = station.config
  local refs = {}

  refs.status = Builder.status(parent)

  if with_preview then
    local frame = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame" })
    local preview = frame.add({ type = "entity-preview" })
    preview.style.minimal_height = 128
    preview.style.horizontally_stretchable = true
    preview.style.vertically_stretchable = true
    preview.entity = station.entity
  end

  refs.net = Nets.build(parent, station)

  -- Rollen (im Rahmen wie die Werte rechts)
  local box = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  box.style.top_margin = 4
  box.style.padding = 6
  box.style.horizontally_stretchable = true
  local roles = box.add({ type = "flow", direction = "horizontal" })
  for _, column in ipairs(ROLE_COLUMNS) do
    local flow = roles.add({ type = "flow", direction = "vertical" })
    flow.style.width = 184
    flow.style.vertical_spacing = 4
    for _, role in ipairs(column) do
      -- Lager nur mit Forschung „UTL: Lager“ und eingeschaltetem Kartenschalter
      local allowed = true
      if role == "storage" then
        allowed = storage.cfg.storage_enabled ~= false and Unlocks.storage(Unlocks.force_of(station))
      end
      flow.add({
        type = "checkbox",
        state = role_checked(cfg, role),
        caption = { "utl-gui.role-" .. role },
        tooltip = { allowed and ("utl-gui.role-" .. role .. "-tooltip") or "utl-gui.role-storage-locked" },
        enabled = allowed or role_checked(cfg, role),
        tags = { utl_action = "role", role = role },
      })
    end
  end

  return refs
end

--- Rolle umschalten. Depot/Tankstelle/Cleanup schließen sich gegenseitig und Anbieter/
--- Abnehmer aus. Rückgabe: true (Fenster neu aufbauen, Abschnitte ändern sich).
function Main.apply_role(cfg, role, state)
  if role == "provider" or role == "requester" or role == "active_provider" then
    cfg.mode = "station"
    if role == "requester" then
      cfg.request = state
    elseif role == "active_provider" then
      cfg.active_provider = state
      if state then cfg.provide = true end -- aktiver Anbieter ist immer auch Anbieter
    else
      cfg.provide = state
      if not state then cfg.active_provider = false end
    end
  elseif state then
    cfg.mode = role
  else
    cfg.mode = "station"
  end
  Roles.derive(cfg)
end

--- Status: grün = bereit, gelb = Halt fehlt, grau = Station ohne Aufgabe.
function Main.refresh(refs, station)
  local stop = station.stop
  local cfg = station.config
  if not (stop and stop.valid) then
    Builder.set_status(refs.status, "yellow", { "utl-gui.status-no-stop" })
  elseif cfg.mode == "station" and not (cfg.provide or cfg.request) then
    Builder.set_status(refs.status, "white", { "utl-gui.status-idle", stop.backer_name })
  else
    Builder.set_status(refs.status, "green", { "utl-gui.status-ok", stop.backer_name })
  end
end

return Main
