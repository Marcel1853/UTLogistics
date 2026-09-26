--- Szenario „UTL-Nachladen“: das Erklärfenster. Zeigt, was gerade passiert (Schritt für Schritt,
--- der aktuelle ist markiert), eine Kamera, die dem Zug folgt, seine Ladeliste und einen Zähler,
--- wie viele Fahrten mit und ohne Nachladen nötig waren.
local Panel = {}

local NAME = "utl_demo_panel"
Panel.MODE_BUTTON = "utl_demo_mode"

-- Schritte je Modus (Locale utl-demo.step-…); 4 und 5 unterscheiden sich
local STEPS = {
  on = { "step-1", "step-2", "step-3", "step-4-on", "step-5-on", "step-6" },
  off = { "step-1", "step-2", "step-3", "step-4-off", "step-5-off", "step-6" },
}

local MODE_CAPTION = { alternate = "mode-alternate", on = "mode-on", off = "mode-off" }

local function note(parent, caption)
  local label = parent.add({ type = "label", caption = caption })
  label.style.single_line = false
  label.style.maximal_width = 340
  return label
end

--- Fenster für einen Spieler anlegen (vorhandenes wird ersetzt).
function Panel.create(player)
  if player.gui.screen[NAME] then player.gui.screen[NAME].destroy() end
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical",
    caption = { "utl-demo.title" } })
  frame.location = { 20, 120 }
  -- Abstände zwischen den Zeilen gibt es nur bei Flows, nicht bei Frames → Flow im Frame
  local box = frame.add({ type = "frame", name = "inner", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  local inner = box.add({ type = "flow", name = "content", direction = "vertical" })
  inner.style.vertical_spacing = 6
  note(inner, { "utl-demo.intro" })

  local mode_row = inner.add({ type = "flow", name = "mode_row", direction = "horizontal" })
  mode_row.style.vertical_align = "center"
  local round = mode_row.add({ type = "label", name = "round" })
  round.style.font = "default-bold"
  mode_row.add({ type = "empty-widget" }).style.horizontally_stretchable = true
  mode_row.add({ type = "button", name = Panel.MODE_BUTTON, tooltip = { "utl-demo.mode-tooltip" } })

  local steps = inner.add({ type = "flow", name = "steps", direction = "vertical" })
  steps.style.vertical_spacing = 0
  for i = 1, #STEPS.on do steps.add({ type = "label", name = "s" .. i }) end

  local camera = inner.add({ type = "camera", name = "camera", position = { 0, 0 },
    surface_index = 1, zoom = 0.35 })
  camera.style.width = 340
  camera.style.height = 190

  local cargo = inner.add({ type = "label", name = "cargo" })
  cargo.style.font = "default-large-bold"
  local stats = inner.add({ type = "label", name = "stats" })
  stats.style.single_line = false
  stats.style.maximal_width = 340
  Panel.refresh(player)
end

--- Inhalt auffrischen (einmal pro Sekunde, nur Texte).
function Panel.refresh(player)
  local frame = player.gui.screen[NAME]
  if not (frame and frame.valid) then return end
  local inner = frame.inner.content
  local demo = storage.demo or {}
  local mode = demo.round_on and "on" or "off"

  inner.mode_row.round.caption = { "utl-demo.round", demo.round or 0,
    { demo.round_on and "utl-demo.on" or "utl-demo.off" } }
  inner.mode_row[Panel.MODE_BUTTON].caption = { "utl-demo." .. MODE_CAPTION[demo.mode or "alternate"] }

  for i, key in ipairs(STEPS[mode]) do
    local label = inner.steps["s" .. i]
    local current = i == (demo.step or 0)
    local done = i < (demo.step or 0)
    -- Zeichen, die sicher im Spielfont stehen: „»“ für den aktuellen Schritt, Häkchen als Bild
    label.caption = { "", current and "» " or (done and "[img=utility/check_mark] " or "     "),
      { "utl-demo." .. key, demo.rest or 2000 } }
    label.style.font = current and "default-bold" or "default"
    label.style.font_color = current and { 1, 0.8, 0.3 } or (done and { 0.6, 0.9, 0.6 } or { 0.7, 0.7, 0.7 })
  end

  local camera = inner.camera
  local loco = demo.locomotive
  if loco and loco.valid then
    camera.surface_index = loco.surface_index
    if camera.entity ~= loco then camera.entity = loco end
  end

  inner.cargo.caption = demo.cargo and { "utl-demo.cargo", demo.cargo } or { "utl-demo.cargo-none" }
  local st = demo.stats or {}
  inner.stats.caption = { "utl-demo.stats", st.on_rounds or 0, st.on_trips or 0, st.off_rounds or 0, st.off_trips or 0 }
end

function Panel.refresh_all()
  for _, player in pairs(game.connected_players) do Panel.refresh(player) end
end

return Panel
