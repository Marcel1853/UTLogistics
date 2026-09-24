--- Eine Einstellungszeile (⟲ | Beschriftung | Feld | Hinweis) für den Manager-Reiter
--- „Einstellungen“ und das Admin-Fenster. Das Feld richtet sich nach dem Einstellungs-Prototyp:
--- Häkchen (bool), Auswahlliste (feste Werte) oder Zahlenfeld (int/double, Rechnen erlaubt).
local Util = require("scripts.lib.util")

local Row = {}

--- Zeile in Tabelle `t` (4 Spalten) anlegen. `tag` = Tag-Name der GUI („utl_mgr“ / „utl_admin“),
--- `kind` = Präfix der Aktionen („team“ / „map“), `id` = Schlüssel der Zeile.
function Row.add(t, tag, kind, id, proto, reset_tooltip)
  local tooltip = { "mod-setting-description." .. proto.name }
  local refs = { proto = proto }
  refs.reset = t.add({ type = "sprite-button", style = "utl_reset_button", sprite = "utility/reset",
    tooltip = reset_tooltip or { "utl-gui.reset-tooltip" }, mouse_button_filter = { "left" },
    tags = { [tag] = kind .. "_reset", id = id } })
  local label = t.add({ type = "label", caption = { "mod-setting-name." .. proto.name }, tooltip = tooltip })
  label.style.width = 330
  refs.label = label
  if proto.type == "bool-setting" then
    refs.input = t.add({ type = "checkbox", state = false, tooltip = tooltip, tags = { [tag] = kind .. "_bool", id = id } })
  elseif proto.allowed_values then
    -- feste Auswahl (z. B. „und“/„oder“): Texte aus [string-mod-setting] <name>-<wert>
    local items = {}
    for i, value in ipairs(proto.allowed_values) do items[i] = { "string-mod-setting." .. proto.name .. "-" .. value } end
    refs.input = t.add({ type = "drop-down", items = items, tooltip = tooltip, tags = { [tag] = kind .. "_choice", id = id } })
    refs.input.style.width = 160
  else
    refs.input = t.add({ type = "textfield", lose_focus_on_confirm = true, clear_and_focus_on_right_click = true,
      tooltip = tooltip, tags = { [tag] = kind .. "_value", id = id } })
    refs.input.style.width = 110
  end
  refs.hint = t.add({ type = "label" })
  refs.hint.style.font_color = { 0.7, 0.7, 0.7 }
  return refs
end

--- Ganze Zeile ein- oder ausblenden.
function Row.set_visible(refs, visible)
  refs.reset.visible, refs.label.visible, refs.input.visible, refs.hint.visible = visible, visible, visible, visible
end

--- Wert ins Feld schreiben.
function Row.show(refs, value)
  local input = refs.input
  if input.type == "checkbox" then
    input.state = value == true
  elseif input.type == "drop-down" then
    for i, allowed in ipairs(refs.proto.allowed_values) do
      if allowed == value then input.selected_index = i end
    end
  else
    input.text = tostring(value)
  end
end

--- Wert als Text für Hinweise (an/aus, feste Auswahl übersetzt).
function Row.text_of(proto, value)
  if type(value) == "boolean" then return { value and "utl-manager.settings-on" or "utl-manager.settings-off" } end
  if proto.allowed_values then return { "string-mod-setting." .. proto.name .. "-" .. tostring(value) } end
  return tostring(value)
end

--- Eingabe einer Aktion lesen: liefert `value, ok`. ⟲ ergibt `nil, true`; ungültige Eingabe
--- `nil, false`. Zahlen werden gerundet (int) und auf Min/Max begrenzt.
function Row.read(action, element, proto)
  if action:match("_reset$") then return nil, true end
  if action:match("_bool$") then return element.state, true end
  if action:match("_choice$") then
    local value = proto.allowed_values[element.selected_index]
    return value, value ~= nil
  end
  local value = Util.parse_number(element.text)
  if not value then return nil, false end
  if proto.type == "int-setting" then value = math.floor(value + 0.5) end
  if proto.minimum_value and value < proto.minimum_value then value = proto.minimum_value end
  if proto.maximum_value and value > proto.maximum_value then value = proto.maximum_value end
  return value, true
end

return Row
