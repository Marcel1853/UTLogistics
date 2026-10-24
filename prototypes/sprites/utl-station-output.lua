-- Erzeugt von tools/grafik/sprites.py – nicht von Hand ändern.
return {
  animations = {
    north = { layers = {
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-north.png", width = 130, height = 149, shift = { 0.4844, -0.7359 }, scale = 0.5 },
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-north-shadow.png", width = 130, height = 149, shift = { 0.4844, -0.7359 }, scale = 0.5, draw_as_shadow = true },
    } },
    east = { layers = {
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-east.png", width = 119, height = 154, shift = { 0.5703, -0.6969 }, scale = 0.5 },
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-east-shadow.png", width = 119, height = 154, shift = { 0.5703, -0.6969 }, scale = 0.5, draw_as_shadow = true },
    } },
    south = { layers = {
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-south.png", width = 125, height = 150, shift = { 0.5234, -0.7281 }, scale = 0.5 },
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-south-shadow.png", width = 125, height = 150, shift = { 0.5234, -0.7281 }, scale = 0.5, draw_as_shadow = true },
    } },
    west = { layers = {
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-west.png", width = 118, height = 158, shift = { 0.5781, -0.6656 }, scale = 0.5 },
        { filename = "__UTLogistics__/graphics/entity/utl-station-output/utl-station-output-west-shadow.png", width = 118, height = 158, shift = { 0.5781, -0.6656 }, scale = 0.5, draw_as_shadow = true },
    } },
  },
  circuit_wire_connection_points = {
    { wire = { red = { -0.1600, -0.7909 }, green = { 0.1600, -0.7909 } }, shadow = { red = { 0.6622, -0.1289 }, green = { 0.9822, -0.1289 } } }, -- north
    { wire = { red = { 0.1700, -0.7809 }, green = { 0.1700, -0.4609 } }, shadow = { red = { 0.9922, -0.1189 }, green = { 0.9922, 0.2011 } } }, -- east
    { wire = { red = { 0.1600, -0.4509 }, green = { -0.1600, -0.4509 } }, shadow = { red = { 0.9822, 0.2111 }, green = { 0.6622, 0.2111 } } }, -- south
    { wire = { red = { -0.1700, -0.4609 }, green = { -0.1700, -0.7809 } }, shadow = { red = { 0.6522, 0.2011 }, green = { 0.6522, -0.1189 } } }, -- west
  },
}
