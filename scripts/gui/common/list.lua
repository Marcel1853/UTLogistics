--- Zeilenliste für Tabellen-Reiter (wie LTN Manager): Kopfzeile + Scroll-Bereich mit einer
--- hellen Box pro Zeile. Beim Auffrischen werden nur die Zeilen neu befüllt, der
--- Scroll-Bereich bleibt bestehen – so springt die Liste nicht jede Sekunde nach oben.
local List = {}

List.MAX_ROWS = 200

--- Spalten: { { caption = LocalisedString, width = n }, ... }. Liefert den Zeilen-Container.
function List.build(parent, columns)
  local outer = parent.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  outer.style.horizontally_stretchable = true
  outer.style.vertically_stretchable = true
  local header = outer.add({ type = "frame", style = "subheader_frame" })
  header.style.horizontally_stretchable = true
  local header_flow = header.add({ type = "flow", direction = "horizontal" })
  header_flow.style.horizontal_spacing = 8
  header_flow.style.left_padding = 8
  for _, column in ipairs(columns) do
    local label = header_flow.add({ type = "label", style = "subheader_caption_label", caption = column.caption })
    label.style.width = column.width
  end
  local scroll = outer.add({ type = "scroll-pane", style = "flib_naked_scroll_pane_no_padding",
    horizontal_scroll_policy = "never" })
  scroll.style.vertically_stretchable = true
  local rows = scroll.add({ type = "flow", direction = "vertical" })
  rows.style.vertical_spacing = 0
  rows.style.padding = 4
  -- Blättern (nur sichtbar bei mehr als MAX_ROWS Zeilen)
  local pager = outer.add({ type = "flow", name = "utl_pager", direction = "horizontal", visible = false })
  pager.style.horizontal_align = "center"
  pager.style.horizontally_stretchable = true
  pager.style.vertical_align = "center"
  pager.add({ type = "sprite-button", style = "tool_button", sprite = "utility/left_arrow",
    tooltip = { "utl-manager.page-previous" }, tags = { utl_mgr = "page", delta = -1 } })
  pager.add({ type = "label", name = "page_label" })
  pager.add({ type = "sprite-button", style = "tool_button", sprite = "utility/right_arrow",
    tooltip = { "utl-manager.page-next" }, tags = { utl_mgr = "page", delta = 1 } })
  return rows
end

--- Zeilen-Container zu einem Blättern-Knopf (für den Klick-Handler).
function List.rows_of_pager_button(button)
  local outer = button.parent and button.parent.parent
  if not outer then return nil end
  for _, child in pairs(outer.children) do
    if child.type == "scroll-pane" then return child.children[1] end
  end
  return nil
end

--- Seite wechseln (`delta` = -1 / 1); die Grenzen prüft List.sync.
function List.turn(rows, delta)
  local tags = rows.tags or {}
  tags.page = math.max(1, (tags.page or 1) + delta)
  rows.tags = tags
end

--- Zeilen befüllen. `fill(row, item)` baut die Zellen einer Zeile (horizontaler Flow).
--- Überzählige Zeilen werden entfernt, fehlende angehängt.
function List.sync(rows, items, fill)
  local children = rows.children
  local per = List.MAX_ROWS
  local pages = math.max(1, math.ceil(#items / per))
  local tags = rows.tags or {}
  local page = math.min(math.max(1, tags.page or 1), pages)
  if tags.page ~= page then
    tags.page = page
    rows.tags = tags
  end
  local offset = (page - 1) * per
  local count = math.min(per, #items - offset)
  local outer = rows.parent and rows.parent.parent
  local pager = outer and outer.utl_pager
  if pager then
    pager.visible = pages > 1
    pager.page_label.caption = { "utl-manager.page", page, pages }
  end
  for i = 1, count do
    local box = children[i]
    if not box then
      box = rows.add({ type = "frame", style = "flib_shallow_frame_in_shallow_frame" })
      box.style.horizontally_stretchable = true
      box.style.padding = 4
      box.add({ type = "flow", direction = "horizontal" }).style.vertical_align = "center"
    end
    local row = box.children[1]
    row.clear()
    row.style.horizontal_spacing = 8
    fill(row, items[offset + i])
  end
  for i = #children, count + 1, -1 do children[i].destroy() end
end

--- Feste Breite für eine Zelle setzen und zurückgeben.
function List.cell(row, width, element)
  local cell = row.add(element)
  cell.style.width = width
  return cell
end

--- Klickbarer Stationsname (zeigt die Station in der Fernsicht).
function List.station_label(row, width, name, stop)
  local tags = nil
  if stop and stop.valid then
    tags = { utl_mgr = "goto", surface = stop.surface_index, x = stop.position.x, y = stop.position.y }
  end
  local label = row.add({
    type = "label",
    style = tags and "clickable_label" or "label",
    caption = name or "?",
    tooltip = tags and { "utl-manager.goto-station" } or nil,
    tags = tags,
  })
  label.style.font = "default-bold"
  if width then label.style.width = width end
  return label
end

return List
