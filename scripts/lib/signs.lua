--- Anzeigefelder mit Erklärtext für die Szenarien (nicht für den Mod selbst). Ein Anzeigefeld
--- kennt nur festen Text, und die Sprache der Spieler steht beim Aufbau noch nicht fest – den Text
--- zeichnet deshalb rendering.draw_text aus der Sprachdatei (utl-sign.<key>) über das Feld. So
--- sieht ihn jeder Spieler in seiner Sprache, auch im Mehrspieler.
local Signs = {}

-- Plätze rund um den Wunschort, nächste zuerst
local OFFSETS = {}
for r = 0, 4 do
  for dx = -r, r do
    for dy = -r, r do
      if math.max(math.abs(dx), math.abs(dy)) == r then OFFSETS[#OFFSETS + 1] = { dx, dy } end
    end
  end
end

--- Anzeigefeld mit Symbol `icon` (SignalID, optional) und Text utl-sign.<key> setzen.
--- Liefert das Anzeigefeld oder nil (kein Platz).
function Signs.place(surface, position, key, icon)
  local x, y = position.x or position[1], position.y or position[2]
  for _, o in ipairs(OFFSETS) do
    local p = { x + o[1], y + o[2] }
    if surface.can_place_entity({ name = "display-panel", position = p, force = "player" }) then
      local panel = surface.create_entity({ name = "display-panel", position = p, force = "player" })
      if panel then
        if icon then panel.display_panel_icon = icon end
        rendering.draw_text({ text = { "utl-sign." .. key }, surface = surface, target = { p[1], p[2] - 0.6 },
          color = { 1, 1, 1 }, scale = 1.5, font = "default-bold", alignment = "center",
          vertical_alignment = "bottom", use_rich_text = true })
        return panel
      end
    end
  end
  return nil
end

return Signs
