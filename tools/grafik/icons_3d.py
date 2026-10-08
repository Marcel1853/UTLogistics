"""3D-Grundbilder der UTL-Signale (Stil „3D“), headless in Blender.

Aufruf:
  blender --background --python tools/grafik/icons_3d.py -- <name> <ausgabe.png> [größe]
Namen: fuel-pump, train-id, train-length, train-locos, train-wagons
(Depot-Garage: tools/grafik/icon_depot_garage.py)
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon3d_common as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
NAME, OUT = args[0], args[1]
SIZE = int(args[2]) if len(args) > 2 else 256

K.reset()
LOCO_RED = K.material("lok_rot", (128, 48, 44), 0.5, 0.42)          # Vanilla-Lok
STEEL = K.material("stahl", (112, 100, 94), 0.6, 0.45)
GREY = K.material("wagen_grau", (150, 146, 140), 0.25, 0.5)        # Vanilla-Güterwagen
DARK = K.material("dunkel", (24, 20, 19), 0.4, 0.7)
HUB = K.material("nabe", (150, 140, 130), 0.6, 0.4, grime=False)
GLASS = K.material("glas", (120, 160, 190), 0.1, 0.15, grime=False)
LAMP = K.material("lampe", (255, 200, 120), 0.0, 0.3, (255, 180, 90), 8.0)
WHITE = K.material("schild", (230, 228, 220), 0.0, 0.5, grime=False)
SCREEN = K.material("anzeige", (120, 230, 140), 0.0, 0.3, (110, 220, 130), 3.0)
HOSE = K.material("schlauch", (30, 28, 27), 0.1, 0.8, grime=False)
CONCRETE = K.material("beton", (120, 116, 108), 0.0, 0.9)


def locomotive(x0=0.0, length=3.4):
    """Lok, Front nach −X (zur Kamera, wie bei der Vanilla-Lok): Rahmen, Motorhaube, Führerhaus hinten,
    Puffer, Auspuff, Griffstangen, kleine Räder."""
    f = -1  # Fahrtrichtung −X
    K.box((length, 1.25, 0.28), (x0, 0, 0.52), DARK, 0.03)                                  # Rahmen
    K.box((length * 0.6, 1.0, 0.82), (x0 + f * length * 0.16, 0, 1.06), LOCO_RED)          # Motorhaube
    K.box((length * 0.6, 1.04, 0.07), (x0 + f * length * 0.16, 0, 1.5), STEEL)             # Haubendach
    K.box((length * 0.34, 1.2, 1.32), (x0 - f * length * 0.31, 0, 1.33), LOCO_RED)         # Führerhaus
    K.box((length * 0.37, 1.28, 0.12), (x0 - f * length * 0.31, 0, 2.03), DARK)           # Dach
    K.box((0.05, 0.75, 0.42), (x0 - f * length * 0.14 + f * 0.01, 0, 1.55), GLASS, 0.0)   # Frontscheibe
    for side in (-1, 1):
        K.box((length * 0.2, 0.05, 0.38), (x0 - f * length * 0.31, side * 0.61, 1.58), GLASS, 0.0)
        K.box((length * 0.55, 0.03, 0.04), (x0 + f * length * 0.16, side * 0.56, 1.28), HUB, 0.0)  # Griffstange
        K.cylinder(0.08, 0.16, (x0 + f * length * 0.5, side * 0.4, 0.62), HUB, (0, math.radians(90), 0), 12)  # Puffer
    K.box((0.06, 0.6, 0.28), (x0 + f * length * 0.46, 0, 1.08), DARK, 0.02)               # Kühlergrill
    K.cylinder(0.12, 0.08, (x0 + f * length * 0.47, 0, 1.36), LAMP, (0, math.radians(90), 0))  # Scheinwerfer
    K.cylinder(0.09, 0.3, (x0 + f * length * 0.05, 0, 1.66), DARK)                       # Auspuff
    for dx in (-0.36, -0.14, 0.14, 0.36):
        K.wheel((x0 + dx * length, -0.55, 0.3), DARK, HUB, 0.24, 0.16)
        K.wheel((x0 + dx * length, 0.55, 0.3), DARK, HUB, 0.24, 0.16)


def wagon(x0=0.0, length=3.2):
    """Güterwagen: Rahmen, Kastenaufbau mit Rippen, Räder."""
    K.box((length, 1.25, 0.25), (x0, 0, 0.55), DARK, 0.03)
    K.box((length * 0.95, 1.2, 1.0), (x0, 0, 1.18), GREY)
    for i in range(5):
        x = x0 - length * 0.38 + i * length * 0.19
        for side in (-1, 1):
            K.box((0.07, 0.05, 0.95), (x, side * 0.62, 1.18), DARK, 0.0)
    K.box((length * 0.95, 1.25, 0.08), (x0, 0, 1.7), STEEL)
    for dx in (-0.36, -0.2, 0.2, 0.36):
        K.wheel((x0 + dx * length, -0.55, 0.3), DARK, HUB, 0.24, 0.16)
        K.wheel((x0 + dx * length, 0.55, 0.3), DARK, HUB, 0.24, 0.16)


if NAME == "fuel-pump":
    K.box((1.6, 1.3, 0.2), (0, 0, 0.1), CONCRETE, 0.04)
    K.box((1.0, 0.8, 2.2), (0, 0, 1.3), LOCO_RED)                              # Säule
    K.box((1.06, 0.86, 0.22), (0, 0, 2.5), DARK)                               # Kopf
    K.box((0.7, 0.04, 0.45), (0, -0.42, 1.75), SCREEN, 0.0)                     # Anzeige
    K.box((0.75, 0.05, 0.5), (0, -0.41, 1.75), DARK, 0.0)
    K.box((0.22, 0.28, 0.42), (-0.62, -0.1, 1.15), DARK, 0.02)                 # Zapfpistole (sichtbare Seite)
    K.box((0.08, 0.5, 0.5), (-0.52, 0, 1.15), STEEL, 0.02)                      # Halter
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0))
    hose = bpy.context.object
    pts = hose.data.splines[0].bezier_points
    pts[0].co, pts[0].handle_right = (-0.5, -0.2, 2.1), (-1.2, -0.3, 2.0)
    pts[1].co, pts[1].handle_left = (-0.7, -0.1, 1.35), (-1.1, -0.3, 0.9)
    hose.data.bevel_depth = 0.07
    hose.data.materials.append(HOSE)
    K.render(OUT, SIZE, target=(0.1, 0, 1.3), ortho=3.6)
elif NAME == "train-id":
    locomotive()
    K.box((0.04, 0.62, 0.3), (-1.66, 0, 0.78), WHITE, 0.0)                      # Nummernschild vorn (−X)
    K.box((0.05, 0.68, 0.36), (-1.64, 0, 0.78), DARK, 0.0)
    K.render(OUT, SIZE, target=(-0.2, 0, 1.0), ortho=4.6, yaw=-55)
elif NAME == "train-length":
    locomotive(-1.7, 3.2)
    wagon(1.75, 3.0)
    K.render(OUT, SIZE, target=(0, 0, 1.0), ortho=7.6, elev=24, yaw=-12)
elif NAME == "train-locos":
    locomotive()
    K.render(OUT, SIZE, target=(0, 0, 1.0), ortho=4.6)
elif NAME == "train-wagons":
    wagon(1.65, 3.1)
    wagon(-1.65, 3.1)
    K.render(OUT, SIZE, target=(0, 0, 1.0), ortho=7.2, elev=26, yaw=-14)
else:
    raise SystemExit("unbekannt: " + NAME)
