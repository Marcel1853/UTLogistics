-- Farbige Haltestellen-Lampen (0.0.19, Start-Einstellung „utl-station-lamps“): Die zwei Lampen oben an
-- der Haltestelle steuert das Spiel selbst (gelb/rot), ihre Farbe kann kein Mod ändern. UTL zeichnet
-- deshalb zur Laufzeit eingefärbte Lampen darüber (scripts/stations/lamps.lua). Form, Lage und Größe
-- stammen aus light1/light2 der Vanilla-Haltestelle; die Bilder sind weiße Fassungen der gelben
-- Lampen (graphics/entity/stop-lamps/), damit sich jede Farbe sauber einfärben lässt.
-- Immer definiert, auch wenn die Einstellung aus ist: Ein Spielstand mit gezeichneten Lampen verweist
-- sonst beim Laden auf fehlende Sprites (die Lampen werden dann in on_configuration_changed entfernt).

local base = data.raw["train-stop"]["train-stop"]
local DIR = "__UTLogistics__/graphics/entity/stop-lamps/"
local sprites = {}
for n, light in ipairs({ base.light1, base.light2 }) do
  for _, direction in ipairs({ "north", "east", "south", "west" }) do
    local picture = light and light.picture and light.picture[direction]
    if picture and picture.filename then
      local sprite = table.deepcopy(picture)
      sprite.type = "sprite"
      sprite.name = "utl-stop-lamp-" .. direction .. "-" .. n
      sprite.filename = DIR .. picture.filename:match("[^/]+$")
      sprite.draw_as_glow = true
      sprites[#sprites + 1] = sprite
    end
  end
end
data:extend(sprites)
