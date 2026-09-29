--- Zeilenliste für Tabellen-Reiter (wie LTN Manager): Kopfzeile + Scroll-Bereich mit einer
--- hellen Box pro Zeile. Beim Auffrischen werden nur die Zeilen neu befüllt, der
--- Scroll-Bereich bleibt bestehen – so springt die Liste nicht jede Sekunde nach oben.
local List = {}

List.MAX_ROWS = 200

--- Spalten: { { caption = LocalisedString, width = n, tooltip = LocalisedString, sort = fn, desc_first = bool }, ... }.
--- Mit `sort` (liefert je Zeile einen Zahl- oder Textwert) sortiert ein Klick auf die Überschrift
--- nach dieser Spalte, ein zweiter Klick kehrt die Richtung um. `desc_first`: erster Klick
--- absteigend (für Zahlen: größte zuerst). Liefert den Zeilen-Container.
function List.build(parent, columns)
  local outer = parent.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
  outer.style.horizontally_stretchable = true
  outer.style.vertically_stretchable = true
  local header = outer.add({ type = "frame", style = "subheader_frame" })
  header.style.horizontally_stretchable = true
  local header_flow = header.add({ type = "flow", direction = "horizontal" })
  header_flow.style.horizontal_spacing = 8
  header_flow.style.left_padding = 8
  for i, column in ipairs(columns) do
    local tooltip = column.sort and (column.tooltip and { "", column.tooltip, "\n", { "utl-manager.sort-tooltip" } }
      or { "utl-manager.sort-tooltip" }) or column.tooltip
    if column.sort then
      -- sortierbar: Text + kleiner Pfeil (12 px, nur an der sortierten Spalte sichtbar)
      local tags = { utl_mgr = "sort", column = i, desc_first = column.desc_first == true }
      local box = header_flow.add({ type = "flow", name = "col_" .. i, direction = "horizontal" })
      box.style.width = column.width
      box.style.horizontal_spacing = 2
      box.style.vertical_align = "center"
      box.add({ type = "label", name = "label", style = "subheader_caption_label", caption = column.caption,
        tooltip = tooltip, tags = tags }).style.maximal_width = column.width - 14
      local arrow = box.add({ type = "sprite", name = "arrow", sprite = "utility/collapse", tooltip = tooltip, tags = tags,
        visible = false })
      arrow.style.size = 12
      arrow.style.stretch_image_to_widget_size = true
    else
      local label = header_flow.add({ type = "label", name = "col_" .. i, style = "subheader_caption_label",
        caption = column.caption, tooltip = tooltip })
      label.style.width = column.width
    end
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

local function rows_in(outer)
  if not outer then return nil end
  for _, child in pairs(outer.children) do
    if child.type == "scroll-pane" then return child.children[1] end
  end
  return nil
end

--- Zeilen-Container zu einem Blättern-Knopf (für den Klick-Handler).
function List.rows_of_pager_button(button)
  return rows_in(button.parent and button.parent.parent)
end

--- Zeilen-Container zu einer Spaltenüberschrift (Text oder Pfeil → Spalte → Flow → Kopfzeile → Rahmen).
function List.rows_of_header(element)
  local outer = element
  for _ = 1, 5 do
    outer = outer and outer.parent
    local rows = outer and outer.valid and rows_in(outer)
    if rows then return rows end
  end
  return nil
end

--- Klick auf eine Spaltenüberschrift: nach ihr sortieren bzw. die Richtung umkehren.
function List.sort_by(rows, column, desc_first)
  local tags = rows.tags or {}
  if tags.sort == column then
    tags.desc = not tags.desc
  else
    tags.sort, tags.desc = column, desc_first == true
  end
  tags.page = 1
  rows.tags = tags
end

--- Gewählte Sortierung anwenden (stabil: bei gleichem Wert bleibt die Reihenfolge des Reiters)
--- und den Pfeil in der Überschrift setzen.
local function apply_sort(rows, items, columns)
  local tags = rows.tags or {}
  local column = tags.sort and columns[tags.sort]
  if column and column.sort then
    local value, index = {}, {}
    for i, item in ipairs(items) do value[item], index[item] = column.sort(item), i end
    local desc = tags.desc
    table.sort(items, function(a, b)
      local va, vb = value[a], value[b]
      if va ~= vb then
        if desc then return va > vb end
        return va < vb
      end
      return index[a] < index[b]
    end)
  end
  local shown = column and column.sort and (tags.sort * 2 + (tags.desc and 1 or 0)) or 0
  if tags.shown == shown then return end
  tags.shown = shown
  rows.tags = tags
  local outer = rows.parent and rows.parent.parent
  local header = outer and outer.children[1] and outer.children[1].children[1]
  if not header then return end
  for i, col in ipairs(columns) do
    local box = header["col_" .. i]
    local arrow = box and box.type == "flow" and box.arrow
    if arrow then
      arrow.visible = col.sort ~= nil and tags.sort == i
      arrow.sprite = tags.desc and "utility/expand" or "utility/collapse"
    end
  end
end

--- Seite wechseln (`delta` = -1 / 1); die Grenzen prüft List.sync.
function List.turn(rows, delta)
  local tags = rows.tags or {}
  tags.page = math.max(1, (tags.page or 1) + delta)
  rows.tags = tags
end

--- Zeilen befüllen. `fill(row, item)` baut die Zellen einer Zeile (horizontaler Flow).
--- Überzählige Zeilen werden entfernt, fehlende angehängt. `columns` (wie bei List.build)
--- schaltet das Sortieren per Klick auf die Überschrift ein.
function List.sync(rows, items, fill, columns)
  if columns then apply_sort(rows, items, columns) end
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
