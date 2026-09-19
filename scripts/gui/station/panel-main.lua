--- Linker Kasten (wie LTN Combinator): Status, Vorschau, Netzwerk, Rollen-Häkchen.
local Builder = require("scripts.gui.common.builder")
local Roles = require("scripts.stations.roles")

local Main = {}

local DEFAULT_NETWORK = "default"

-- Häkchen in zwei Spalten: links Station (Anbieter/Abnehmer), rechts Sonderrollen.
local ROLE_COLUMNS = {
  { "provider", "requester" },
  { "depot", "fuel", "cleanup" },
}

local function role_checked(cfg, role)
  if role == "provider" then return cfg.mode == "station" and cfg.provide end
  if role == "requester" then return cfg.mode == "station" and cfg.request end
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

  -- Netzwerk: Symbol, Beschriftung, Textfeld (leer = Standard-Netzwerk).
  local net = parent.add({ type = "flow", style = "flib_indicator_flow" })
  net.style.top_margin = 4
  net.add({ type = "sprite", style = "utl_entry_sprite", sprite = "virtual-signal/utl-network" })
  net.add({ type = "label", style = "caption_label", caption = { "utl-gui.network" }, tooltip = { "utl-gui.network-tooltip" } })
  net.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  local field = net.add({
    type = "textfield",
    text = cfg.network ~= DEFAULT_NETWORK and cfg.network or "",
    lose_focus_on_confirm = true,
    tooltip = { "utl-gui.network-tooltip" },
    tags = { utl_action = "network" },
  })
  field.style.width = 150

  -- Rollen
  local roles = parent.add({ type = "flow", direction = "horizontal" })
  roles.style.top_margin = 4
  for _, column in ipairs(ROLE_COLUMNS) do
    local flow = roles.add({ type = "flow", direction = "vertical" })
    flow.style.width = 190
    flow.style.vertical_spacing = 4
    for _, role in ipairs(column) do
      flow.add({
        type = "checkbox",
        state = role_checked(cfg, role),
        caption = { "utl-gui.role-" .. role },
        tooltip = { "utl-gui.role-" .. role .. "-tooltip" },
        tags = { utl_action = "role", role = role },
      })
    end
  end

  return refs
end

--- Rolle umschalten. Depot/Tankstelle/Cleanup schließen sich gegenseitig und Anbieter/
--- Abnehmer aus. Rückgabe: true (Fenster neu aufbauen, Abschnitte ändern sich).
function Main.apply_role(cfg, role, state)
  if role == "provider" or role == "requester" then
    cfg.mode = "station"
    if role == "provider" then cfg.provide = state else cfg.request = state end
  elseif state then
    cfg.mode = role
  else
    cfg.mode = "station"
  end
  Roles.derive(cfg)
end

function Main.apply_network(cfg, text)
  cfg.network = text ~= "" and text or DEFAULT_NETWORK
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
