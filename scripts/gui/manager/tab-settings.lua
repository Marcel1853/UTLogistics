--- Reiter „Einstellungen“:
---   * oben die Lade-Werte (Inaktivität beim Laden/Entladen, Fracht und/oder Inaktivität) und die
---     Team-Leiter. Mit Teams: Werte des eigenen Teams, ändern dürfen die Team-Leiter (und Admins).
---     Ohne Teams: dieselben Werte als Kartenwerte, ändern darf nur ein Admin.
---   * darunter „Karte / Server“ mit allen übrigen UTL-Kartenwerten – nur für Admins sichtbar.
--- Kein Auffrischen im Takt, sonst überschriebe es das Feld beim Tippen.
local Row = require("scripts.gui.common.setting-row")
local TeamPanel = require("scripts.gui.common.team-panel")
local TeamConfig = require("scripts.core.team-config")
local Config = require("scripts.core.config")
local Teams = require("scripts.core.teams")
local Section = require("scripts.gui.common.section")

local Tab = {}

local MOD = "UTLogistics"
local TAG = "utl_mgr"

-- Einstellungen, die oben als Lade-Werte stehen
local LOADING = {}
for _, entry in ipairs(TeamConfig.KEYS) do LOADING[entry.setting] = true end

--- Alle Karten-Einstellungen dieses Mods, sortiert wie im Einstellungsmenü.
local function map_settings()
  local list = {}
  for _, proto in pairs(prototypes.mod_setting) do
    if proto.mod == MOD and proto.setting_type == "runtime-global" then list[#list + 1] = proto end
  end
  table.sort(list, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.name < b.name
  end)
  return list
end

local function note(parent)
  local label = parent.add({ type = "label" })
  label.style.single_line = false
  label.style.font_color = { 0.7, 0.7, 0.7 }
  return label
end

function Tab.build(parent)
  local pane = parent.add({ type = "scroll-pane", style = "flib_naked_scroll_pane_no_padding",
    horizontal_scroll_policy = "never" })
  pane.style.vertically_stretchable = true
  pane.style.horizontally_stretchable = true
  -- Kästen untereinander, rechts Platz für den Scrollbalken
  local box = pane.add({ type = "flow", direction = "vertical" })
  box.style.padding = { 0, 12, 8, 0 }
  box.style.vertical_spacing = 12
  local refs = { map = {} }
  local _, header, loading = Section.add(box, "")
  refs.header = header
  refs.note = note(loading)
  refs.team = TeamPanel.build(loading, TAG)

  -- Karte / Server: nur für Admins
  local map_box, _, map_body = Section.add(box, { "utl-manager.settings-map" })
  refs.map_box = map_box
  note(map_body).caption = { "utl-manager.settings-map-note" }
  local map = map_body.add({ type = "table", column_count = 4 })
  map.draw_horizontal_lines = true -- feine Linie zwischen den Zeilen
  map.style.horizontal_spacing = 8
  map.style.vertical_spacing = 6
  map.style.vertical_align = "center"
  for _, proto in ipairs(map_settings()) do refs.map[proto.name] = Row.add(map, TAG, "map", proto.name, proto) end
  return refs
end

--- Darf der Spieler die Lade-Werte ändern? Mit Teams: Leiter/Admin, ohne: nur Admin.
local function can_edit(player)
  if Teams.active() then return Teams.can_edit(player) end
  return player.admin
end

function Tab.refresh(refs, manager)
  local player = game.get_player(manager.player_index)
  if not player then return end
  local teams, edit, admin = Teams.active(), can_edit(player), player.admin
  refs.header.caption = { teams and "utl-manager.settings-team" or "utl-manager.settings-loading" }
  if teams then
    refs.note.caption = { edit and "utl-manager.settings-team-note" or "utl-manager.settings-team-locked" }
  else
    refs.note.caption = { edit and "utl-manager.settings-solo-note" or "utl-manager.settings-solo-locked" }
  end
  TeamPanel.refresh(refs.team, player.force_index, edit, true, not teams)

  refs.map_box.visible = admin
  if not admin then return end
  for name, r in pairs(refs.map) do
    -- ohne Teams stehen die Lade-Werte schon oben
    Row.set_visible(r, teams or not LOADING[name])
    local value, own = Config.value(name), Config.is_own(name)
    Row.show(r, value)
    r.reset.enabled = own or value ~= r.proto.default_value
    r.hint.caption = own and { "utl-manager.settings-map-own", Row.text_of(r.proto, settings.global[name].value) }
      or { "utl-manager.settings-default", Row.text_of(r.proto, r.proto.default_value) }
  end
end

--- Änderung übernehmen (`action` = team_/map_ + value | bool | choice | reset). Liefert true bei
--- Änderung.
function Tab.apply(refs, player, action, id, element)
  if action:match("^team_") then
    if not can_edit(player) then return false end
    return TeamPanel.apply(refs.team, player.force_index, action, id, element, not Teams.active())
  end
  local r = refs.map[id]
  if not (r and player.admin) then return false end -- Kartenwerte nur für Admins
  local value, ok = Row.read(action, element, r.proto)
  if not ok then return false end
  -- ⟲: Manager-Wert weg; ist keiner gesetzt, zurück auf den Standard
  if value == nil and not Config.is_own(id) then value = r.proto.default_value end
  if value ~= nil and Config.value(id) == value then return false end
  Config.set(id, value)
  return true
end

return Tab
