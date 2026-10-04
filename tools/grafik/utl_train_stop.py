# UTL-Haltestelle als 3D-Modell für Factorio-Sprites (Blender 5.x, headless):
#   blender -b --python tools/grafik/utl_train_stop.py -- [--render AUSGABEORDNER] [--preview]
# Ohne --render wird nur das Modell gebaut und als .blend gespeichert (kein Rendern).
# Aufbau wie die Vanilla-Haltestelle (Gittermast, Ausleger, Kasten), UTL-Kennzeichen:
# blaue Netztafel mit Drei-Punkte-Symbol, orange Warnstreifen, Signallampe.
# Maße in Factorio-Feldern (1 Feld = 1 Blender-Einheit), Haltestelle 2 × 2 Felder.
import bpy, bmesh, math, sys, os
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[args.index("--render") + 1] if "--render" in args else None
PREVIEW = "--preview" in args

# ---------- Szene leeren ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, color, metallic=0.8, rough=0.45, noise=0.0, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if noise > 0:
        # Gebrauchsspuren: Rauschen mischt Grundfarbe mit Rost/Schmutz
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 18.0
        tex.inputs["Detail"].default_value = 8.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.45
        ramp.color_ramp.elements[0].color = (0.18, 0.09, 0.05, 1)  # Rost
        ramp.color_ramp.elements[1].position = 0.62
        ramp.color_ramp.elements[1].color = (*color, 1)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["Factor"].default_value = noise
        mix.inputs[6].default_value = (*color, 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 6.0
    return m

STEEL = mat("Stahl", (0.42, 0.42, 0.44), 0.9, 0.5, noise=0.35)
DARK = mat("Stahl dunkel", (0.16, 0.16, 0.17), 0.85, 0.55, noise=0.2)
CONCRETE = mat("Beton", (0.38, 0.37, 0.34), 0.0, 0.9, noise=0.25)
BLUE = mat("UTL-Blau", (0.07, 0.22, 0.45), 0.4, 0.35, noise=0.15)
ORANGE = mat("UTL-Orange", (0.85, 0.42, 0.05), 0.2, 0.4, noise=0.2)
WHITE = mat("Weiß", (0.85, 0.87, 0.9), 0.1, 0.4)
LAMP = mat("Lampe", (0.2, 0.9, 0.25), 0.0, 0.2, emission=(0.2, 1.0, 0.3))

def box(name, size, loc, material, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new("Fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    o.data.materials.append(material)
    return o

def beam(name, a, b, thick, material):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = box(name, (thick, thick, d.length), (a + b) / 2, material, bevel=thick * 0.15)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return o

def cyl(name, r, h, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=24)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o

# ---------- Modell (Haltestelle zeigt nach Norden, Gleis links/Westen) ----------
H = 2.6          # Masthöhe in Feldern
M = (0.35, 0.35) # Mastmitte (x, y) innerhalb des 2×2-Felds (Mitte = 0,0)

# Betonsockel und Fundamentplatte
box("Sockel", (0.9, 0.9, 0.18), (M[0], M[1], 0.09), CONCRETE, bevel=0.04)
box("Platte", (0.62, 0.62, 0.08), (M[0], M[1], 0.22), DARK, bevel=0.02)

# Gittermast: vier Eckstiele, Querstreben und Diagonalen
w = 0.16
corners = [(M[0] - w, M[1] - w), (M[0] + w, M[1] - w), (M[0] + w, M[1] + w), (M[0] - w, M[1] + w)]
for i, (x, y) in enumerate(corners):
    beam(f"Stiel{i}", (x, y, 0.25), (x, y, H), 0.045, STEEL)
levels = [0.25 + k * (H - 0.25) / 6 for k in range(7)]
for k in range(6):
    z0, z1 = levels[k], levels[k + 1]
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        beam(f"Quer{k}_{i}", (x0, y0, z1), (x1, y1, z1), 0.028, STEEL)
        if k % 2 == 0:
            beam(f"Diag{k}_{i}", (x0, y0, z0), (x1, y1, z1), 0.02, DARK)
        else:
            beam(f"Diag{k}_{i}", (x1, y1, z0), (x0, y0, z1), 0.02, DARK)

# Orange Warnstreifen am Mastfuß
for k in range(3):
    box(f"Streifen{k}", (0.40, 0.40, 0.05), (M[0], M[1], 0.32 + k * 0.12), ORANGE if k % 2 == 0 else DARK, bevel=0.01)

# Kopf: Ausleger nach Westen über das Gleis, mit Zugstange
box("Kopf", (0.46, 0.46, 0.22), (M[0], M[1], H + 0.08), DARK, bevel=0.03)
box("Ausleger", (1.5, 0.16, 0.12), (M[0] - 0.75, M[1], H + 0.12), STEEL, bevel=0.025)
beam("Zugstange", (M[0], M[1], H + 0.55), (M[0] - 1.35, M[1], H + 0.18), 0.025, DARK)
beam("Spitze", (M[0], M[1], H + 0.12), (M[0], M[1], H + 0.6), 0.05, STEEL)

# UTL-Netztafel hängt am Ausleger (beidseitig sichtbar)
box("Tafel", (0.06, 0.62, 0.48), (M[0] - 1.05, M[1], H - 0.25), BLUE, bevel=0.02)
box("Tafelrahmen", (0.07, 0.68, 0.06), (M[0] - 1.05, M[1], H + 0.0), DARK, bevel=0.01)
for side in (-1, 1):
    beam(f"Aufhängung{side}", (M[0] - 1.05, M[1] + side * 0.25, H + 0.06), (M[0] - 1.05, M[1] + side * 0.25, H - 0.02), 0.02, DARK)
# Drei-Punkte-Symbol (orange Punkte, weiße Verbindungen) auf beiden Seiten
pts = [(-0.17, -0.38), (0.0, -0.10), (0.17, -0.38)]
for sx in (-1, 1):
    x = M[0] - 1.05 + sx * 0.035
    P = [Vector((x, M[1] + py, H + pz)) for py, pz in pts]
    for i in range(3):
        beam(f"Linie{sx}{i}", P[i], P[(i + 1) % 3], 0.022, WHITE)
    for i, p in enumerate(P):
        cyl(f"Punkt{sx}{i}", 0.05, 0.03, p, ORANGE, rot=(0, math.pi / 2, 0))

# Tafel zur Kamera drehen (Factorio blickt von Süden): Netzsymbol von vorn sichtbar
from mathutils import Matrix
pivot = bpy.data.objects["Tafel"].matrix_world.translation.copy()
turn = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Translation(-pivot)
for o in bpy.data.objects:
    if o.name.startswith(("Tafel", "Aufhängung", "Linie", "Punkt")):
        o.matrix_world = turn @ o.matrix_world

# Signallampe an der Mastspitze und Kasten unten (wie Vanilla)
cyl("Lampengehäuse", 0.09, 0.12, (M[0] + 0.0, M[1] - 0.24, H + 0.35), DARK, rot=(math.pi / 2, 0, 0))
cyl("Lampe", 0.065, 0.03, (M[0] + 0.0, M[1] - 0.31, H + 0.35), LAMP, rot=(math.pi / 2, 0, 0))
box("Schaltkasten", (0.32, 0.22, 0.36), (M[0] + 0.32, M[1] - 0.42, 0.42), DARK, bevel=0.03)
box("Kastentür", (0.26, 0.02, 0.28), (M[0] + 0.32, M[1] - 0.535, 0.42), BLUE, bevel=0.008)

# ---------- Licht und Kamera wie Factorio ----------
sun = bpy.data.lights.new("Sonne", "SUN")
sun.energy = 4.0
sun.angle = math.radians(3)
so = bpy.data.objects.new("Sonne", sun)
so.rotation_euler = (math.radians(45), 0, math.radians(-135))  # Licht von oben links (Nordwest)
scene.collection.objects.link(so)
world = bpy.data.worlds.new("Welt")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Strength"].default_value = 0.35
scene.world = world

cam = bpy.data.cameras.new("Kamera")
cam.type = "ORTHO"
cam.ortho_scale = 5.0  # 5 Felder breit sichtbar
co = bpy.data.objects.new("Kamera", cam)
co.rotation_euler = (math.radians(45), 0, 0)  # Factorio: 45° von Süden auf die Welt
co.location = (0, -12, 12 + 1.3)
scene.collection.objects.link(co)
scene.camera = co

# Boden nur für den Schatten-Pass (in der Gebäude-Ausgabe unsichtbar)
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
ground = bpy.context.object
ground.name = "Boden"
ground.is_shadow_catcher = True

# ---------- Rendern (nur mit --render) ----------
r = scene.render
try:
    r.engine = "CYCLES"
except TypeError:
    pass
scene.cycles.samples = 24 if PREVIEW else 256
scene.cycles.use_denoising = True
r.film_transparent = True
r.resolution_x = 400 if PREVIEW else 640
r.resolution_y = r.resolution_x
r.resolution_percentage = 100

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "utl_train_stop.blend")
bpy.ops.wm.save_as_mainfile(filepath=path)
print("[GRAFIK] Modell gebaut:", len(bpy.data.objects), "Objekte ->", path)

if OUT:
    os.makedirs(OUT, exist_ok=True)
    # vier Richtungen: Modell um die Mitte drehen (Nord, Ost, Süd, West)
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Boden"]
    pivot = bpy.data.objects.new("Drehpunkt", None)
    scene.collection.objects.link(pivot)
    for o in parts:
        o.parent = pivot
    for i, name in enumerate(["nord", "ost", "sued", "west"]):
        pivot.rotation_euler = (0, 0, -math.radians(90 * i))
        r.filepath = os.path.join(OUT, f"utl-train-stop-{name}.png")
        bpy.ops.render.render(write_still=True)
        print("[GRAFIK] gerendert:", r.filepath)
        if PREVIEW:
            break
