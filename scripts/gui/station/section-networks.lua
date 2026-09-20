--- Abschnitt „Netzwerk“ im linken Kasten (Vorbild LTN Combinator, aber mit Namen statt Zahlen):
--- oben das Heimatnetz als Auswahlliste mit Umbenennen-Knopf, darunter nur die Zusatznetze, die an
--- dieser Station wirklich an sind. Die Höhe hängt damit nicht daran, wie viele Netze es auf der
--- Karte gibt.
local Networks = require("scripts.stations.networks")

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
  for i = 2, #list do
    local name = list[i]
    chips.add({
      type = "button",
      style = "utl_net_chip",
      caption = name,
      tooltip = { "utl-gui.networks-chip-tooltip", name },
      mouse_button_filter = { "left" },
      tags = { utl_action = "network_chip", network = name },
    })
  end
end

--- Einträge der Liste „Netz hinzufügen“: Platzhalter, vorhandene Netze, zuletzt „Neu …“.
function Nets.fill_add(add, cfg)
  local items = { { "utl-gui.networks-add" } }
  for _, name in ipairs(available(cfg)) do items[#items + 1] = name end
  items[#items + 1] = { "utl-gui.networks-new" }
  add.items = items
  add.selected_index = 1
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
  refs.rename = row.add({ type = "sprite-button", style = "utl_reset_button", sprite = "utility/rename_icon",
    tooltip = { "utl-gui.network-rename-tooltip" }, tags = { utl_action = "network_rename" } })

  -- Eingabefeld für einen neuen Namen; es wird nur ein- und ausgeblendet, damit beim Tippen
  -- nichts neu aufgebaut wird (sonst ginge der Fokus verloren).
  refs.edit = parent.add({ type = "flow", direction = "horizontal" })
  refs.edit.visible = false
  refs.edit.style.vertical_align = "center"
  refs.field = refs.edit.add({
    type = "textfield",
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    tooltip = { "utl-gui.network-name-tooltip" },
    tags = { utl_action = "network_name", target = "home" },
  })
  refs.field.style.horizontally_stretchable = true
  refs.edit.add({ type = "sprite-button", style = "utl_confirm_button", sprite = "utility/check_mark",
    tooltip = { "utl-gui.network-name-tooltip" }, tags = { utl_action = "network_confirm" } })
  refs.edit.add({ type = "sprite-button", style = "utl_cancel_button", sprite = "utility/close_black",
    tooltip = { "utl-gui.cancel" }, tags = { utl_action = "network_cancel" } })

  -- Zusatznetze
  local box = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  box.style.padding = 6
  box.style.top_margin = 4
  box.tooltip = { "utl-gui.networks-extra-tooltip" }
  local caption = box.add({ type = "label", caption = { "utl-gui.networks-extra" } })
  caption.style.font_color = { 0.7, 0.7, 0.7 }
  caption.style.bottom_margin = 4
  refs.chips = box.add({ type = "table", column_count = 2 })
  refs.chips.style.horizontal_spacing = 4
  refs.chips.style.vertical_spacing = 4
  Nets.fill_chips(refs.chips, cfg)
  refs.add = box.add({
    type = "drop-down",
    tooltip = { "utl-gui.networks-add-tooltip" },
    tags = { utl_action = "network_add_pick" },
  })
  refs.add.style.top_margin = 4
  refs.add.style.minimal_width = 150
  Nets.fill_add(refs.add, cfg)

  return refs
end

--- Eingabefeld zeigen: `target` ist „home“ (Heimatnetz umbenennen) oder „extra“ (Netz anlegen).
function Nets.start_edit(refs, target, text)
  refs.field.tags = { utl_action = "network_name", target = target }
  refs.field.text = text or ""
  refs.edit.visible = true
  refs.pick.enabled = false
  refs.field.focus()
  refs.field.select_all()
end

function Nets.stop_edit(refs)
  refs.edit.visible = false
  refs.pick.enabled = true
end

--- Heimatnetz setzen; leer bedeutet „default“. Ein Netz ist nie Heimat- und Zusatznetz zugleich.
function Nets.apply_home(cfg, text)
  local name = text and text:match("^%s*(.-)%s*$") or ""
  cfg.network = name ~= "" and name or DEFAULT_NETWORK
  if cfg.networks then cfg.networks[cfg.network] = nil end
end

return Nets
