--- Abschnitt „Netzwerk“ im linken Kasten (Vorbild LTN Combinator, aber mit Namen statt Zahlen):
--- oben das Heimatnetz als Auswahlliste mit Umbenennen-Knopf, darunter nur die Zusatznetze, die an
--- dieser Station wirklich an sind. Die Höhe hängt damit nicht daran, wie viele Netze es auf der
--- Karte gibt.
local Networks = require("scripts.stations.networks")
local Unlocks = require("scripts.core.unlocks")

local Nets = {}

local DEFAULT_NETWORK = "default"

--- Netze, die diese Station noch nicht hat (für die Liste „Netz hinzufügen“).
local function available(cfg)
  local list = {}
  local extra = cfg.networks or {}
  for _, name in ipairs(Networks.known()) do
    if name ~= cfg.network and not extra[name] then list[#list + 1] = name end
  end
  return list
end

--- Zusatznetze als Knöpfe; ein Klick nimmt das Netz wieder heraus.
function Nets.fill_chips(chips, cfg)
  chips.clear()
  local list = Networks.list(cfg)
  chips.visible = #list > 1 -- ohne Zusatznetze keine leere Zeile
  for i = 2, #list do
    local name = list[i]
    chips.add({
      type = "button",
      style = "utl_net_chip",
      caption = name .. "  ×",
      tooltip = { "utl-gui.networks-chip-tooltip", name },
      mouse_button_filter = { "left" },
      tags = { utl_action = "network_chip", network = name },
    })
  end
end

--- Einträge der Liste „Netz hinzufügen“: nur die Netze, die es schon gibt und die hier noch fehlen.
--- Kein Platzhalter-Eintrag (sonst stünde er in der aufgeklappten Liste noch einmal); ohne freie
--- Netze ist die Liste abgeschaltet – dann hilft der Knopf „Neu“.
function Nets.fill_add(add, cfg)
  local items = available(cfg)
  add.items = items
  add.selected_index = 0
  add.enabled = #items > 0
  add.tooltip = { #items > 0 and "utl-gui.networks-add-tooltip" or "utl-gui.networks-add-none" }
end

--- Eingabezeile (Textfeld, ✓, ✗); `target` = „home“ (Heimatnetz umbenennen) oder „extra“
--- (neues Zusatznetz). Sie wird nur ein- und ausgeblendet, damit beim Tippen nichts neu
--- aufgebaut wird (sonst ginge der Fokus verloren).
local function edit_row(parent, target)
  local row = parent.add({ type = "flow", direction = "horizontal" })
  row.visible = false
  row.style.vertical_align = "center"
  row.style.top_margin = 4
  local field = row.add({
    type = "textfield",
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    tooltip = { "utl-gui.network-name-tooltip" },
    tags = { utl_action = "network_name", target = target },
  })
  field.style.horizontally_stretchable = true
  field.style.maximal_width = 0
  row.add({ type = "sprite-button", style = "utl_confirm_button", sprite = "utility/check_mark",
    tooltip = { "utl-gui.network-name-tooltip" }, tags = { utl_action = "network_confirm", target = target } })
  row.add({ type = "sprite-button", style = "utl_cancel_button", sprite = "utility/close_black",
    tooltip = { "utl-gui.cancel" }, tags = { utl_action = "network_cancel", target = target } })
  return row, field
end

function Nets.build(parent, station)
  local cfg = station.config
  local refs = {}

  parent.add({ type = "label", style = "utl_header_label", caption = { "utl-gui.network" },
    tooltip = { "utl-gui.network-tooltip" } })

  -- Heimatnetz
  local row = parent.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.add({ type = "sprite", style = "utl_entry_sprite", sprite = "virtual-signal/utl-network",
    tooltip = { "utl-gui.network-tooltip" } })
  local known = Networks.known()
  local selected = 1
  for i, name in ipairs(known) do
    if name == cfg.network then selected = i end
  end
  refs.pick = row.add({
    type = "drop-down",
    items = known,
    selected_index = selected,
    tooltip = { "utl-gui.network-pick-tooltip" },
    tags = { utl_action = "network_pick" },
  })
  refs.pick.style.horizontally_stretchable = true
  refs.pick.style.minimal_width = 150
  refs.rename = row.add({ type = "sprite-button", style = "utl_net_edit_button", sprite = "utility/rename_icon",
    tooltip = { "utl-gui.network-rename-tooltip" }, tags = { utl_action = "network_rename" } })
  refs.home_edit, refs.home_field = edit_row(parent, "home")

  -- Zusatznetze: Kasten über die volle Breite, darin die aktiven Netze als Knöpfe und darunter
  -- die Zeile zum Hinzufügen (vorhandenes Netz wählen oder mit „Neu“ einen Namen eintragen).
  local box = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  box.style.padding = 8
  box.style.top_margin = 4
  box.style.horizontally_stretchable = true
  local limit = Unlocks.networks_limit(Unlocks.force_of(station))
  local count = Networks.extra_count(cfg)
  local caption = box.add({ type = "label",
    caption = { "utl-gui.networks-extra-count", count, limit },
    tooltip = { "utl-gui.networks-extra-tooltip" } })
  caption.style.font_color = { 0.7, 0.7, 0.7 }
  caption.style.bottom_margin = 4
  refs.chips = box.add({ type = "table", column_count = 3 })
  refs.chips.style.horizontal_spacing = 4
  refs.chips.style.vertical_spacing = 4
  refs.chips.style.bottom_margin = 4
  Nets.fill_chips(refs.chips, cfg)

  local add_row = box.add({ type = "flow", direction = "horizontal" })
  add_row.style.vertical_align = "center"
  add_row.style.horizontally_stretchable = true
  refs.add = add_row.add({ type = "drop-down", tags = { utl_action = "network_add_pick" } })
  refs.add.style.horizontally_stretchable = true
  refs.add.style.minimal_width = 120
  Nets.fill_add(refs.add, cfg)
  refs.new = add_row.add({ type = "button", style = "utl_net_new_button", caption = { "utl-gui.networks-new" },
    tooltip = { "utl-gui.networks-new-tooltip" }, tags = { utl_action = "network_new" } })
  -- Limit erreicht bzw. noch nicht erforscht: Hinzufügen sperren und sagen, warum.
  if count >= limit then
    local why = limit == 0 and { "utl-gui.research-needed", { "technology-name.utl-networks-1" } }
      or limit < Unlocks.MAX_NETWORKS and { "utl-gui.networks-limit-research", limit,
        { "technology-name." .. Unlocks.NETWORK_TECHS[limit + 1] } }
      or { "utl-gui.networks-limit", limit }
    refs.add.enabled, refs.new.enabled = false, false
    refs.add.tooltip, refs.new.tooltip = why, why
  end
  refs.new_edit, refs.new_field = edit_row(box, "extra")

  return refs
end

--- Eingabezeile zeigen: `target` ist „home“ (Heimatnetz umbenennen) oder „extra“ (Netz anlegen).
function Nets.start_edit(refs, target, text)
  local row, field = refs.home_edit, refs.home_field
  if target == "extra" then row, field = refs.new_edit, refs.new_field end
  field.text = text or ""
  row.visible = true
  if target == "home" then refs.pick.enabled = false end
  field.focus()
  field.select_all()
end

function Nets.stop_edit(refs, target)
  if target == "extra" then
    refs.new_edit.visible = false
  else
    refs.home_edit.visible = false
    refs.pick.enabled = true
  end
end

--- Text der Eingabezeile eines Ziels.
function Nets.edit_text(refs, target)
  return (target == "extra" and refs.new_field or refs.home_field).text
end

--- Heimatnetz setzen; leer bedeutet „default“. Ein Netz ist nie Heimat- und Zusatznetz zugleich.
function Nets.apply_home(cfg, text)
  local name = text and text:match("^%s*(.-)%s*$") or ""
  cfg.network = name ~= "" and name or DEFAULT_NETWORK
  if cfg.networks then cfg.networks[cfg.network] = nil end
end

return Nets
