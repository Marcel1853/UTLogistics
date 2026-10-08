"""Signal-Grundbild „Depot-Garage“ im Stil der Vanilla-Item-Icons (3D, Blender, headless).

Aufruf:
  blender --background --python tools/grafik/icon_depot_garage.py -- <ausgabe.png> [größe]

Probe für den Signal-Stil „3D“: Lokschuppen aus Wellblech mit Rolltor, Licht von links oben, Blick
schräg von vorn oben, transparenter Hintergrund (Kamera/Licht nach meshy-blender-spritesheet).
Farben aus den Vanilla-Icons gemessen (Wagen/Lok: dunkel ≈ 11–21, mittel ≈ 84/67/66, hell ≈ 184).
"""
import math
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "/tmp/icon-depot-garage.png"
SIZE = int(args[1]) if len(args) > 1 else 256

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(c):
    """sRGB 0–255 → lineare Farbe für Blender."""
    def ch(v):
        v = v / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (ch(c[0]), ch(c[1]), ch(c[2]))


def material(name, rgb, metallic=0.5, roughness=0.6, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*srgb(rgb), 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*srgb(emission), 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    else:
        # Schmutz und Abnutzung wie bei den Vanilla-Icons: Rauschen dunkelt die Grundfarbe fleckig ab
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 9.0
        noise.inputs["Detail"].default_value = 8.0
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = (0.55, 0.5, 0.47, 1)
        ramp.color_ramp.elements[1].position = 0.7
        ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["A"].default_value = (*srgb(rgb), 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], mix.inputs["B"])
        links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


WALL = material("wand", (112, 98, 90), 0.25, 0.55)        # Wellblech, Vanilla-Grau-Braun
ROOF = material("dach", (84, 70, 64), 0.3, 0.5)
RUST = material("rost", (122, 58, 40), 0.3, 0.7)          # Rostrot wie an der Vanilla-Lok
DOOR = material("tor", (176, 172, 164), 0.2, 0.45)         # helles Rolltor
DARK = material("dunkel", (22, 18, 17), 0.4, 0.7)
CONCRETE = material("beton", (120, 116, 108), 0.0, 0.9)
LAMP = material("lampe", (255, 180, 90), 0.0, 0.3, (255, 160, 70), 8.0)


def box(size, location, mat, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rot)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.data.materials.append(mat)
    return obj


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

# --- Kamera und Licht (Vorlage meshy-blender-spritesheet, Blick wie Vanilla-Icons) ----------------
bpy.ops.object.empty_add(location=(0, 0, 1.15))
aim = bpy.context.object
bpy.ops.object.camera_add()
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 5.2
elev, yaw, dist = math.radians(30), math.radians(-38), 14
cam.location = (dist * math.cos(elev) * math.sin(yaw), -dist * math.cos(elev) * math.cos(yaw),
                1.15 + dist * math.sin(elev))
track = cam.constraints.new("TRACK_TO")
track.target = aim
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam

bpy.ops.object.light_add(type="SUN", rotation=(math.radians(45), 0, math.radians(-60)))  # links oben
bpy.context.object.data.energy = 7.0
bpy.ops.object.light_add(type="AREA", location=(6, -4, 6))
bpy.context.object.data.energy = 900
bpy.context.object.data.size = 5
world = bpy.data.worlds.new("welt")
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 1.1
scene.world = world

scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("Icon gerendert:", OUT)
