--- Erklärfenster für die Szenarien (nicht für den Mod selbst): erklärt Schritt für Schritt, was
--- gerade passiert, und zeigt es in einer Kamera, die einem Objekt folgt – meist einem Zug.
---
---   ┌ Titel ─────────────────────────── [▾] ┐   Titelleiste: verschieben, einklappen
---   │ Einleitung (mehrzeilig)               │
---   │ Kopfzeile              [Knopf]        │   z. B. „Runde 2: Nachladen AN“ + Moduswahl
---   │ ✓ Schritt 1                           │   erledigt
---   │ » Schritt 2                           │   aktuell (hervorgehoben)
---   │   Schritt 3                           │   kommt noch
---   │ ┌─────── Kamera ───────┐              │   folgt `follow`
---   │ └──────────────────────┘              │
---   │ Große Zeile                           │   z. B. Ladeliste
---   │ Notiz                                 │   z. B. Zähler
---   └───────────────────────────────────────┘
---
--- Benutzung:
---   Explain.create(player, { name = "…", title = {…}, intro = {…}, button = { action = "…", tooltip = {…} } })
---   Explain.update(player, "…", { headline = {…}, button = {…}, steps = { {…}, … }, current = 2,
---     legend = false, follow = entity, big = {…}, note = {…} })
---   `legend = true`: Die Schritte sind keine Abfolge, sondern eine Legende – nur der aktuelle wird
---   hervorgehoben, nichts gilt als „erledigt“ (z. B. „was gerade zu sehen ist“).
---   in on_gui_click: local action = Explain.on_click(event)  → eigener Knopf gedrückt, sonst nil
---
--- Alle Texte sind LocalisedStrings (jeder Spieler sieht seine Sprache). Eingeklappt wird je Fenster
--- und Spieler gemerkt (`storage.explain`). Aufgefrischt wird nur, was übergeben wird, und nichts,
--- solange das Fenster eingeklappt ist.
local Explain = {}

local TAG = "utl_explain"
local WIDTH = 340

local COLOR = {
  current = { 1, 0.8, 0.3 },
  done = { 0.6, 0.9, 0.6 },
  open = { 0.7, 0.7, 0.7 },
}

--- Merkliste „eingeklappt“ für ein Fenster.
local function collapsed(name)
  storage.explain = storage.explain or { collapsed = {} }
  local map = storage.explain.collapsed
  map[name] = map[name] or {}
  return map[name]
end

local function frame_of(player, name)
  local frame = player.gui.screen[name]
  return frame and frame.valid and frame or nil
end

local function wrapped(parent, name)
  local label = parent.add({ type = "label", name = name })
  label.style.single_line = false
  label.style.maximal_width = WIDTH
  return label
end

--- Fenster anlegen (ein vorhandenes gleichen Namens wird ersetzt).
--- `spec` = { name, title, intro?, button? = { action, tooltip? }, camera? (Standard true),
---   zoom? (Standard 0.35), location? (Standard { 20, 120 }) }
function Explain.create(player, spec)
  local old = frame_of(player, spec.name)
  if old then old.destroy() end
  local frame = player.gui.screen.add({ type = "frame", name = spec.name, direction = "vertical" })
  frame.location = spec.location or { 20, 120 }

  local bar = frame.add({ type = "flow", name = "bar", style = "flib_titlebar_flow" })
  bar.drag_target = frame
  bar.add({ type = "label", style = "frame_title", caption = spec.title, ignored_by_interaction = true })
  bar.add({ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true })
  bar.add({ type = "sprite-button", name = "collapse", style = "frame_action_button", sprite = "utility/collapse",
    tooltip = { "utl-explain.collapse" }, mouse_button_filter = { "left" }, tags = { [TAG] = "collapse" } })

  -- Zeilenabstand gibt es nur bei Flows, nicht bei Frames → Flow im Frame
  local box = frame.add({ type = "frame", name = "box", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  local inner = box.add({ type = "flow", name = "inner", direction = "vertical" })
  inner.style.vertical_spacing = 6
  if spec.intro then wrapped(inner, "intro").caption = spec.intro end

  local head = inner.add({ type = "flow", name = "head", direction = "horizontal" })
  head.style.vertical_align = "center"
  head.add({ type = "label", name = "headline" }).style.font = "default-bold"
  head.add({ type = "empty-widget" }).style.horizontally_stretchable = true
  if spec.button then
    head.add({ type = "button", name = "button", tooltip = spec.button.tooltip, tags = { [TAG] = spec.button.action } })
  end

  local steps = inner.add({ type = "flow", name = "steps", direction = "vertical" })
  steps.style.vertical_spacing = 0

  if spec.camera ~= false then
    local camera = inner.add({ type = "camera", name = "camera", position = { 0, 0 }, surface_index = 1,
      zoom = spec.zoom or 0.35 })
    camera.style.width = WIDTH
    camera.style.height = 190
  end

  inner.add({ type = "label", name = "big" }).style.font = "default-large-bold"
  wrapped(inner, "note")

  if collapsed(spec.name)[player.index] then Explain.toggle(player, spec.name, true) end
end

--- Inhalt auffrischen. Nur übergebene Felder ändern sich.
--- `state` = { headline?, button?, steps? = { LocalisedString … }, current?, legend?,
---   follow? (LuaEntity), big?, note? }
function Explain.update(player, name, state)
  local frame = frame_of(player, name)
  if not (frame and frame.box.visible) then return end
  local inner = frame.box.inner
  if state.headline then inner.head.headline.caption = state.headline end
  if state.button and inner.head.button then inner.head.button.caption = state.button end

  if state.steps then
    local flow = inner.steps
    if #flow.children ~= #state.steps then
      flow.clear()
      for i = 1, #state.steps do flow.add({ type = "label", name = "s" .. i }) end
    end
    local current = state.current or 0
    for i, text in ipairs(state.steps) do
      local label = flow["s" .. i]
      local is_current = i == current
      local is_done = not state.legend and i < current
      -- Zeichen, die sicher im Spielfont stehen: „»“ und das Häkchen als Bild
      label.caption = { "", is_current and "» " or (is_done and "[img=utility/check_mark] " or "     "), text }
      label.style.font = is_current and "default-bold" or "default"
      label.style.font_color = is_current and COLOR.current or (is_done and COLOR.done or COLOR.open)
    end
  end

  local camera = inner.camera
  local follow = state.follow
  if camera and follow and follow.valid then
    camera.surface_index = follow.surface_index
    if camera.entity ~= follow then camera.entity = follow end
  end
  if state.big then inner.big.caption = state.big end
  if state.note then inner.note.caption = state.note end
end

--- Ein- bzw. ausklappen; eingeklappt bleibt nur die Titelleiste. `value` erzwingt einen Zustand.
function Explain.toggle(player, name, value)
  local frame = frame_of(player, name)
  if not frame then return end
  if value == nil then value = frame.box.visible end
  frame.box.visible = not value
  local button = frame.bar.collapse
  button.sprite = value and "utility/expand" or "utility/collapse"
  button.tooltip = { value and "utl-explain.expand" or "utl-explain.collapse" }
  collapsed(name)[player.index] = value or nil
end

--- In on_gui_click aufrufen. Einklappen erledigt es selbst; bei einem eigenen Knopf liefert es
--- dessen `action` (sonst nil).
function Explain.on_click(event)
  local element = event.element
  if not (element and element.valid) then return nil end
  local action = element.tags and element.tags[TAG]
  if not action then return nil end
  if action == "collapse" then
    local frame = element.parent and element.parent.parent
    local player = game.get_player(event.player_index)
    if player and frame then Explain.toggle(player, frame.name) end
    return nil
  end
  return action
end

return Explain
