--- Abschnitt „Netzwerk“ im linken Kasten (Vorbild LTN Combinator, aber mit Namen statt Zahlen):
--- oben das Heimatnetz als Auswahlliste mit Umbenennen-Knopf, darunter der Kasten „Verbunden mit“.
--- Verbindungen gelten für das ganze Netz auf dieser Oberfläche (Stern, siehe
--- scripts/stations/networks.lua), nicht nur für diese Station.
local Networks = require("scripts.stations.networks")
local Unlocks = require("scripts.core.unlocks")

local Nets = {}

local DEFAULT_NETWORK = "default"

--- Netze, die sich mit dem Heimatnetz verbinden lassen (frei, nicht schon in einem Stern).
local function candidates(surface, home, limit)
  local list = {}
  for _, name in ipairs(Networks.known()) do
    if name ~= home and Networks.can_link(surface, home, name, math.max(limit, 1)) == true then
      list[#list + 1] = name
    end
  end
  return list
end

--- Verbundene Netze als Knöpfe; ein Klick löst die Verbindung. Ist das Heimatnetz selbst Partner,
--- steht hier sein Zentrum.
function Nets.fill_chips(chips, star)
  chips.clear()
  local names = star.role == "partner" and { star.center } or star.partners
  chips.visible = #names > 0 -- ohne Verbindungen keine leere Zeile
  for _, name in ipairs(names) do
    local center = star.role == "partner"
    chips.add({
      type = "button",
      style = "utl_net_chip",
      caption = center and { "utl-gui.link-center-chip", name } or (name .. "  ×"),
      tooltip = { center and "utl-gui.link-leave-tooltip" or "utl-gui.networks-chip-tooltip", name },
      mouse_button_filter = { "left" },
      tags = { utl_action = "network_chip", network = name },
    })
  end
end

--- Einträge der Liste „Netz hinzufügen“: nur Netze, die sich verbinden lassen. Kein Platzhalter-
--- Eintrag (sonst stünde er in der aufgeklappten Liste noch einmal).
function Nets.fill_add(add, items)
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

  -- Verbunden mit: Kasten über die volle Breite, darin die verbundenen Netze als Knöpfe und
  -- darunter die Zeile zum Hinzufügen (vorhandenes Netz wählen oder mit „Neu“ anlegen).
  local box = parent.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame", direction = "vertical" })
  box.style.padding = 8
  box.style.top_margin = 4
  box.style.horizontally_stretchable = true
  local stop = station.stop
  local surface = stop and stop.valid and stop.surface_index
  local limit = Unlocks.networks_limit(Unlocks.force_of(station))
  local star = surface and Networks.star(surface, cfg.network) or { partners = {} }
  local caption = box.add({ type = "label",
    caption = star.role == "partner" and { "utl-gui.links" }
      or { "utl-gui.links-count", #star.partners, limit },
    tooltip = { "utl-gui.links-tooltip" } })
  caption.style.font_color = { 0.7, 0.7, 0.7 }
  caption.style.bottom_margin = 4
  refs.chips = box.add({ type = "table", column_count = 3 })
  refs.chips.style.horizontal_spacing = 4
  refs.chips.style.vertical_spacing = 4
  refs.chips.style.bottom_margin = 4
  Nets.fill_chips(refs.chips, star)

  local add_row = box.add({ type = "flow", direction = "horizontal" })
  add_row.style.vertical_align = "center"
  add_row.style.horizontally_stretchable = true
  refs.add = add_row.add({ type = "drop-down", tags = { utl_action = "network_add_pick" } })
  refs.add.style.horizontally_stretchable = true
  refs.add.style.minimal_width = 120
  Nets.fill_add(refs.add, surface and candidates(surface, cfg.network, limit) or {})
  refs.new = add_row.add({ type = "button", style = "utl_net_new_button", caption = { "utl-gui.networks-new" },
    tooltip = { "utl-gui.networks-new-tooltip" }, tags = { utl_action = "network_new" } })

  -- Hinzufügen sperren und sagen, warum: Partner (kein eigener Stern), Grenze erreicht bzw. noch
  -- nicht erforscht, oder die Station hat keine Haltestelle (keine Oberfläche).
  local why
  if not surface then
    why = { "utl-gui.status-no-stop" }
  elseif star.role == "partner" then
    why = { "utl-gui.link-own-partner", star.center }
  elseif #star.partners >= limit then
    why = limit == 0 and { "utl-gui.research-needed", { "technology-name.utl-networks-1" } }
      or limit < Unlocks.MAX_NETWORKS and { "utl-gui.networks-limit-research", limit,
        { "technology-name." .. Unlocks.NETWORK_TECHS[limit + 1] } }
      or { "utl-gui.networks-limit", limit }
  end
  if why then
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
end

return Nets
