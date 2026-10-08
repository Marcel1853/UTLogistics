"""Signal-Grundbild „Depot-Garage“ im Stil der Vanilla-Item-Icons (3D, Blender, headless).

Aufruf:
  blender --background --python tools/grafik/icon_depot_garage.py -- <ausgabe.png> [größe]

Probe für den Signal-Stil „3D“: Lokschuppen aus Wellblech mit Rolltor, Licht von links oben, Blick
schräg von vorn oben, transparenter Hintergrund (Kamera/Licht nach meshy-blender-spritesheet).
Farben aus den Vanilla-Icons gemessen (Wagen/Lok: dunkel ≈ 11–21, mittel ≈ 84/67/66, hell ≈ 184).
"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "/tmp/icon-depot-garage.png"
SIZE = int(args[1]) if len(args) > 1 else 256

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon3d_common as K  # noqa: E402

srgb, material, box = K.srgb, K.material, K.box


WALL = material("wand", (112, 98, 90), 0.55, 0.45)        # Wellblech, Vanilla-Grau-Braun
ROOF = material("dach", (84, 70, 64), 0.6, 0.45)
RUST = material("rost", (122, 58, 40), 0.3, 0.7)          # Rostrot wie an der Vanilla-Lok
DOOR = material("tor", (176, 172, 164), 0.55, 0.4)         # helles Rolltor
DARK = material("dunkel", (22, 18, 17), 0.4, 0.7)
CONCRETE = material("beton", (120, 116, 108), 0.0, 0.9)
LAMP = material("lampe", (255, 180, 90), 0.0, 0.3, (255, 160, 70), 8.0)


# --- Modell: Schuppen 3 breit, 3.4 tief, Satteldach; Vorderseite zeigt nach −Y ---------------
W, D, H = 3.0, 3.4, 1.9
box((W + 0.4, D + 0.4, 0.18), (0, 0, 0.09), CONCRETE, 0.05)               # Bodenplatte
box((0.22, D, H), (-W / 2 + 0.11, 0, 0.18 + H / 2), WALL)                # Seitenwände
box((0.22, D, H), (W / 2 - 0.11, 0, 0.18 + H / 2), WALL)
box((W, 0.22, H), (0, D / 2 - 0.11, 0.18 + H / 2), WALL)                  # Rückwand
# Wellblech-Rippen auf der sichtbaren Seitenwand (links)
for i in range(7):
    y = -D / 2 + 0.3 + i * (D - 0.6) / 6
    box((0.06, 0.1, H - 0.1), (-W / 2 - 0.02, y, 0.18 + H / 2), DARK, 0.01)
# Giebel und Satteldach
top = 0.18 + H
for side in (-1, 1):
    box((W / 2 + 0.35, D + 0.45, 0.14), (side * W / 4, 0, top + 0.42),
        ROOF, 0.03, (0, math.radians(side * 26), 0))
box((0.3, D + 0.5, 0.18), (0, 0, top + 0.85), RUST, 0.03)                  # First
# Giebelfeld vorn als Dreieck (Prisma)
gable = bpy.data.meshes.new("giebel")
hw, gh, gy = W / 2, 0.75, -D / 2
verts = [(-hw, gy, top), (hw, gy, top), (0, gy, top + gh), (-hw, gy + 0.2, top), (hw, gy + 0.2, top), (0, gy + 0.2, top + gh)]
gable.from_pydata(verts, [], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)])
gobj = bpy.data.objects.new("giebel", gable)
bpy.context.collection.objects.link(gobj)
gobj.data.materials.append(WALL)
# Tor: Rahmen dunkel, Rolltor hell mit Querrippen
box((W - 0.25, 0.16, H - 0.05), (0, -D / 2 + 0.05, 0.18 + (H - 0.05) / 2), DARK, 0.02)
box((W - 0.6, 0.18, H - 0.35), (0, -D / 2 - 0.02, 0.18 + (H - 0.35) / 2), DOOR, 0.02)
for i in range(6):
    z = 0.35 + i * (H - 0.6) / 5
    box((W - 0.6, 0.04, 0.05), (0, -D / 2 - 0.12, z), DARK, 0.0)
# Rostiger Torsturz und Lampe darüber
box((W - 0.2, 0.26, 0.18), (0, -D / 2 - 0.05, 0.18 + H - 0.02), RUST, 0.02)
bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.14, depth=0.1, location=(0, -D / 2 - 0.2, top + 0.25),
                                    rotation=(math.radians(90), 0, 0))
bpy.context.object.data.materials.append(LAMP)

K.render(OUT, SIZE, target=(0, 0, 1.15), ortho=5.2)
