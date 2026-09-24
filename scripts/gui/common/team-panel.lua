--- Team-Bereich (Leiter + Lade-Werte) für den Manager-Reiter „Einstellungen“ und das
--- Admin-Fenster. `tag` = Tag-Name der GUI („utl_mgr“ / „utl_admin“).
--- Ohne Teams („solo“) zeigt er dieselben Werte als Kartenwerte (Config), ohne Leiter-Zeile.
local Row = require("scripts.gui.common.setting-row")
local TeamConfig = require("scripts.core.team-config")
local Teams = require("scripts.core.teams")
local Config = require("scripts.core.config")

local Panel = {}

function Panel.build(parent, tag)
  local refs = { tag = tag, rows = {} }
  local leader_row = parent.add({ type = "flow", direction = "horizontal" })
  refs.leader_row = leader_row
  leader_row.style.vertical_align = "center"
  leader_row.style.horizontal_spacing = 4
  leader_row.add({ type = "label", caption = { "utl-manager.settings-leaders" },
    tooltip = { "utl-manager.settings-leaders-tooltip" } })
  refs.leaders = leader_row.add({ type = "flow", direction = "horizontal" })
  refs.leaders.style.horizontal_spacing = 4
  refs.leader_add = leader_row.add({ type = "drop-down", tooltip = { "utl-manager.settings-leader-add" },
    tags = { [tag] = "leader_add" } })
  refs.leader_add.style.width = 200

  local t = parent.add({ type = "table", column_count = 4 })
  t.style.horizontal_spacing = 8
  t.style.vertical_spacing = 4
  t.style.vertical_align = "center"
  for _, entry in ipairs(TeamConfig.KEYS) do
    local proto = prototypes.mod_setting[entry.setting]
    if proto then
      refs.rows[entry.key] = Row.add(t, tag, "team", entry.key, proto, { "utl-manager.settings-team-reset" })
    end
  end
  return refs
end

--- Ohne Teams: die Lade-Werte als Kartenwerte zeigen (nur Admins dürfen ändern).
local function refresh_solo(refs, can_edit)
  refs.leader_row.visible = false
  for _, r in pairs(refs.rows) do
    local name = r.proto.name
    local value, own = Config.value(name), Config.is_own(name)
    Row.show(r, value)
    r.input.enabled = can_edit
    r.reset.enabled = can_edit and (own or value ~= r.proto.default_value)
    r.hint.caption = own and { "utl-manager.settings-map-own", Row.text_of(r.proto, settings.global[name].value) }
      or { "utl-manager.settings-default", Row.text_of(r.proto, r.proto.default_value) }
  end
end

--- Team `force_index` anzeigen; `can_edit` = Felder und Leiter-Knöpfe bedienbar.
--- `keep_last` = den letzten Leiter nicht entfernbar machen (Admins dürfen auch den letzten).
--- `solo` = es gibt keine Teams (siehe refresh_solo).
function Panel.refresh(refs, force_index, can_edit, keep_last, solo)
  if solo then return refresh_solo(refs, can_edit) end
  refs.leader_row.visible = true
  local leaders, others = Teams.members(force_index)
  refs.leaders.clear()
  local removable = can_edit and (not keep_last or #leaders > 1)
  for _, leader in ipairs(leaders) do
    refs.leaders.add({ type = "button", style = "utl_net_chip",
      caption = removable and (leader.name .. "  ×") or leader.name,
      tooltip = { removable and "utl-manager.settings-leader-remove" or "utl-manager.settings-leader-last", leader.name },
      enabled = removable, mouse_button_filter = { "left" },
      tags = { [refs.tag] = "leader_remove", player = leader.index } })
  end
  local items, candidates = {}, {}
  for i, member in ipairs(others) do items[i], candidates[i] = member.name, member.index end
  refs.leader_add.items = items
  if #refs.leader_add.items > 0 then refs.leader_add.selected_index = 0 end
  refs.leader_add.enabled = can_edit and #items > 0
  refs.candidates = candidates

  for key, r in pairs(refs.rows) do
    Row.show(r, TeamConfig.get(force_index, key))
    local own = TeamConfig.is_own(force_index, key)
    r.input.enabled = can_edit
    r.reset.enabled = own and can_edit
    r.hint.caption = own and { "utl-manager.settings-team-own", Row.text_of(r.proto, Config.value(r.proto.name)) }
      or { "utl-manager.settings-team-map" }
  end
end

--- Team-Wert aus einer Aktion übernehmen (Rechte prüft der Aufrufer). Ohne Teams (`solo`) wird
--- der Kartenwert gesetzt. Liefert true bei Änderung.
function Panel.apply(refs, force_index, action, id, element, solo)
  local r = refs.rows[id]
  if not r then return false end
  local value, ok = Row.read(action, element, r.proto)
  if not ok then return false end
  if solo then
    local name = r.proto.name
    -- ⟲: Manager-Wert weg; ist keiner gesetzt, zurück auf den Standard
    if value == nil and not Config.is_own(name) then value = r.proto.default_value end
    if value ~= nil and Config.value(name) == value then return false end
    Config.set(name, value)
    return true
  end
  TeamConfig.set(force_index, id, value)
  return true
end

return Panel
