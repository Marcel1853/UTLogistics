"""Icon „UTL-Haltestelle“ in Blender modellieren und rendern (headless).

Aufruf:
  blender --background --python tools/grafik/icon_train_stop.py -- <ausgabe.png> [größe]

Licht und Kamera nach der Vorlage des Skills meshy-blender-spritesheet (Licht von links oben,
transparenter Hintergrund, orthografische Kamera, Cycles). Das Modell ist für Icon-Größe gebaut:
kräftige, einfache Formen, die auch bei 32 px noch lesbar sind – keine Gitter, keine Kleinteile.
"""
import math
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "/tmp/utl-train-stop-icon.png"
SIZE = int(args[1]) if len(args) > 1 else 256

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, color, metallic=0.4, roughness=0.55, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


# Farben nach Vanilla (warmes Grau-Braun) + UTL-Blau als Erkennungsfarbe
STEEL = material("stahl", (0.20, 0.185, 0.18), 0.55, 0.5)
DARK = material("dunkel", (0.07, 0.065, 0.06), 0.5, 0.6)
CONCRETE = material("beton", (0.34, 0.33, 0.31), 0.0, 0.85)
BLUE = material("utl_blau", (0.05, 0.32, 0.85), 0.2, 0.35)
LAMP = material("lampe", (1.0, 0.55, 0.12), 0.0, 0.3, (1.0, 0.5, 0.1), 6.0)
GLASS = material("glas", (0.85, 0.9, 1.0), 0.0, 0.15)


def box(name, size, location, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, mat, rotation=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location,
                                        rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


# --- Modell (Einheiten frei; Höhe ≈ 3) -----------------------------------------------------------
box("sockel", (1.4, 1.4, 0.3), (0, 0, 0.15), CONCRETE)
box("fuss", (0.85, 0.85, 0.25), (0, 0, 0.42), STEEL)
box("mast", (0.48, 0.48, 2.3), (0, 0, 1.6), STEEL)
box("mast_kante", (0.52, 0.52, 0.14), (0, 0, 0.95), DARK, 0.02)
box("ausleger", (1.3, 0.38, 0.34), (0.6, 0, 2.65), STEEL)
box("strebe", (0.12, 0.2, 0.75), (0.42, 0, 2.25), DARK, 0.02).rotation_euler = (0, math.radians(-40), 0)
# Schild in UTL-Blau mit dunklem Rahmen (Erkennungszeichen auch bei 32 px)
box("schild_rahmen", (0.1, 1.2, 0.95), (-0.29, 0, 2.0), DARK, 0.03)
box("schild", (0.08, 1.08, 0.83), (-0.34, 0, 2.0), BLUE, 0.02)
box("schild_streifen", (0.09, 1.08, 0.16), (-0.36, 0, 2.0), material("weiss", (0.9, 0.9, 0.88), 0.0, 0.5), 0.0)
# Lampe am Auslegerende
box("lampe_haus", (0.5, 0.5, 0.38), (1.15, 0, 2.32), DARK, 0.05)
cylinder("lampe", 0.21, 0.14, (1.15, 0, 2.1), LAMP)
cylinder("kappe", 0.3, 0.1, (0, 0, 2.86), DARK)

# --- Kamera und Licht nach der Skill-Vorlage ----------------------------------------------------
bpy.ops.object.camera_add()
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.1
elev, yaw = math.radians(32), math.radians(-35)
dist = 12
target = (0.3, 0, 1.4)
cam.location = (target[0] + dist * math.cos(elev) * math.sin(yaw),
                target[1] - dist * math.cos(elev) * math.cos(yaw),
                target[2] + dist * math.sin(elev))
bpy.ops.object.empty_add(location=target)
aim = bpy.context.object
track = cam.constraints.new("TRACK_TO")
track.target = aim
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam

bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(-40)))  # von links oben
bpy.context.object.data.energy = 4.0
bpy.ops.object.light_add(type="AREA", location=(4, -5, 5))
bpy.context.object.data.energy = 600
bpy.context.object.data.size = 4

world = bpy.data.worlds.new("welt")
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.8
scene.world = world

scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("Icon gerendert:", OUT)
