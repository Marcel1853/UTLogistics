# Modell der UTL-Haltestelle (Blender 5.x). Maße in Factorio-Feldern, an der Vanilla-Haltestelle
# gemessen: Höhe ≈ 4 Felder, Mast ≈ 0,6 Felder breit, Ausleger ≈ 2 Felder übers Gleis (Westen).
# Wird von utl_train_stop.py (headless) benutzt und lässt sich in einem offenen Blender neu bauen:
#   exec(open(".../utl_stop_model.py").read()); build()
import bpy
import math
from mathutils import Vector, Matrix

COLLECTION = "UTL-Haltestelle"


def _mat(name, color, metallic=0.85, rough=0.5, rust=0.0, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    base = (*color, 1)
    if rust > 0:
        # Rost und Schmutz: großes Rauschen für Flecken, feines für Körnung
        coord = nt.nodes.new("ShaderNodeTexCoord")
        big = nt.nodes.new("ShaderNodeTexNoise")
        big.inputs["Scale"].default_value = 6.0
        big.inputs["Detail"].default_value = 10.0
        big.inputs["Roughness"].default_value = 0.65
        nt.links.new(coord.outputs["Object"], big.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.5 - rust * 0.25
        ramp.color_ramp.elements[0].color = (0.16, 0.075, 0.035, 1)
        ramp.color_ramp.elements[1].position = 0.62
        ramp.color_ramp.elements[1].color = base
        nt.links.new(big.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        rr = nt.nodes.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = rough + 0.25
        rr.inputs["To Max"].default_value = rough
        nt.links.new(big.outputs["Fac"], rr.inputs["Value"])
        nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.15
        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 80.0
        nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
        nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Base Color"].default_value = base
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 8.0
    return m


def build():
    # alte Fassung entfernen
    old = bpy.data.collections.get(COLLECTION)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        old = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(old)
    for o in list(bpy.data.objects):  # Reste der ersten Fassung (ohne Sammlung)
        if o.type == "MESH" and o.users_collection and o.users_collection[0] == bpy.context.scene.collection \
                and not o.name.startswith(("Boden", "Vanilla")):
            bpy.data.objects.remove(o, do_unlink=True)
    col = old

    STEEL = _mat("Stahl lackiert", (0.30, 0.30, 0.29), 0.75, 0.55, rust=0.55)
    DARK = _mat("Stahl dunkel", (0.11, 0.11, 0.11), 0.8, 0.6, rust=0.35)
    CONCRETE = _mat("Beton", (0.33, 0.32, 0.29), 0.0, 0.92, rust=0.3)
    BLUE = _mat("UTL-Blau", (0.05, 0.17, 0.38), 0.35, 0.45, rust=0.25)
    ORANGE = _mat("UTL-Orange", (0.78, 0.36, 0.04), 0.2, 0.5, rust=0.3)
    WHITE = _mat("Weiß", (0.78, 0.80, 0.82), 0.1, 0.45)
    LAMP = _mat("Lampe grün", (0.15, 0.8, 0.2), 0.0, 0.2, emission=(0.25, 1.0, 0.3))

    def link(o, material):
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
        o.data.materials.append(material)
        return o

    def box(name, size, loc, material, bevel=0.012):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.object
        o.name = name
        o.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            b = o.modifiers.new("Fase", "BEVEL")
            b.width = bevel
            b.segments = 2
            b.limit_method = "ANGLE"
        return link(o, material)

    def angle_iron(name, a, b, leg, material, twist=0.0):
        """L-Profil (Winkelstahl) von a nach b, Schenkellänge `leg`."""
        a, b = Vector(a), Vector(b)
        d = b - a
        t = leg * 0.22
        parts = []
        for off, size in (((leg / 2 - t / 2, 0), (leg, t)), ((0, leg / 2 - t / 2), (t, leg))):
            bpy.ops.mesh.primitive_cube_add(size=1)
            o = bpy.context.object
            o.scale = (size[0], size[1], d.length)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            for v in o.data.vertices:
                v.co.x += off[0] - leg / 2 + t
                v.co.y += off[1] - leg / 2 + t
            parts.append(o)
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        o = bpy.context.object
        o.name = name
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized()) @ \
            Matrix.Rotation(twist, 4, "Z").to_quaternion()
        o.location = (a + b) / 2
        bv = o.modifiers.new("Fase", "BEVEL")
        bv.width = t * 0.3
        bv.segments = 1
        return link(o, material)

    def bar(name, a, b, r, material):
        a, b = Vector(a), Vector(b)
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + b) / 2, vertices=10)
        o = bpy.context.object
        o.name = name
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        bpy.ops.object.shade_smooth()
        return link(o, material)

    def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=24):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts)
        o = bpy.context.object
        o.name = name
        bpy.ops.object.shade_smooth()
        return link(o, material)

    # ---- Maße ----
    MX, MY = 0.45, 0.45        # Mastmitte im 2×2-Feld (rechts hinten, Gleis links)
    W = 0.30                   # halbe Mastbreite (Mast 0,6 Felder)
    H = 3.7                    # Masthöhe
    ARM = 2.3                  # Ausleger nach Westen
    TOP = H + 0.1

    # ---- Fundament ----
    box("Fundament", (1.15, 1.15, 0.22), (MX, MY, 0.11), CONCRETE, bevel=0.04)
    box("Fußplatte", (0.82, 0.82, 0.05), (MX, MY, 0.245), DARK)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        cyl(f"Anker{i}", 0.03, 0.06, (MX + sx * 0.34, MY + sy * 0.34, 0.29), DARK, verts=6)

    # ---- Gittermast aus Winkelstahl ----
    corners = [(MX - W, MY - W), (MX + W, MY - W), (MX + W, MY + W), (MX - W, MY + W)]
    twists = [0, math.pi / 2, math.pi, -math.pi / 2]
    for i, (x, y) in enumerate(corners):
        angle_iron(f"Eckstiel{i}", (x, y, 0.27), (x, y, H), 0.075, STEEL, twists[i])
    n = 7
    zs = [0.27 + k * (H - 0.27) / n for k in range(n + 1)]
    for k in range(n):
        for i in range(4):
            (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
            bar(f"Riegel{k}_{i}", (x0, y0, zs[k + 1]), (x1, y1, zs[k + 1]), 0.02, STEEL)
            if k % 2 == 0:
                bar(f"Diagonale{k}_{i}", (x0, y0, zs[k]), (x1, y1, zs[k + 1]), 0.014, DARK)
            else:
                bar(f"Diagonale{k}_{i}", (x1, y1, zs[k]), (x0, y0, zs[k + 1]), 0.014, DARK)
            # Knotenblech
            box(f"Knoten{k}_{i}", (0.07, 0.07, 0.07), (x0, y0, zs[k + 1]), DARK, bevel=0.008)
    # Leiter an der Südseite (zur Kamera)
    ly = MY - W - 0.06
    for sx in (-0.09, 0.09):
        bar(f"Leiterholm{sx}", (MX + sx, ly, 0.3), (MX + sx, ly, H - 0.2), 0.012, DARK)
    for k in range(int((H - 0.5) / 0.16)):
        z = 0.38 + k * 0.16
        bar(f"Sprosse{k}", (MX - 0.09, ly, z), (MX + 0.09, ly, z), 0.008, DARK)

    # Orange Warnmarkierung am Mastfuß (Schrägstreifen-Optik)
    for k in range(4):
        box(f"Warnband{k}", (0.66, 0.66, 0.06), (MX, MY, 0.42 + k * 0.1), ORANGE if k % 2 == 0 else DARK, bevel=0.006)

    # ---- Kopf ----
    box("Kopfplatte", (0.78, 0.78, 0.08), (MX, MY, H + 0.04), DARK)
    box("Kopfkasten", (0.6, 0.6, 0.32), (MX + 0.02, MY + 0.02, H + 0.24), STEEL, bevel=0.03)
    box("Kopfdeckel", (0.68, 0.68, 0.05), (MX + 0.02, MY + 0.02, H + 0.425), DARK)

    # ---- Ausleger als Gitterträger ----
    y0, y1 = MY - 0.13, MY + 0.13
    zl, zu = TOP + 0.12, TOP + 0.42
    xs, xe = MX - W, MX - W - ARM
    for y in (y0, y1):
        angle_iron(f"Untergurt{y:.2f}", (xs, y, zl), (xe, y, zl), 0.06, STEEL, math.pi / 2)
        angle_iron(f"Obergurt{y:.2f}", (xs, y, zu), (xe + 0.35, y, zu - 0.08), 0.055, STEEL, math.pi / 2)
        seg = 6
        for k in range(seg):
            xa = xs + (xe - xs) * k / seg
            xb = xs + (xe - xs) * (k + 1) / seg
            za = zu - 0.08 * k / seg
            bar(f"Pfosten{y:.2f}_{k}", (xa, y, zl), (xa, y, za), 0.012, DARK)
            bar(f"Strebe{y:.2f}_{k}", (xa, y, za), (xb, y, zl), 0.011, DARK)
    for k in range(7):
        x = xs + (xe - xs) * k / 6
        bar(f"Quer{k}", (x, y0, zl), (x, y1, zl), 0.011, DARK)
    box("Auslegerende", (0.3, 0.38, 0.34), (xe + 0.08, MY, zl + 0.08), STEEL, bevel=0.025)
    # Zugstangen vom Mastkopf zum Ausleger
    for y in (y0, y1):
        bar(f"Zugstange{y:.2f}", (MX, y, H + 0.85), (xe + 0.4, y, zu - 0.05), 0.012, DARK)
    bar("Spitze", (MX, MY, H + 0.45), (MX, MY, H + 0.9), 0.035, STEEL)

    # ---- UTL-Netztafel unter dem Ausleger, zur Kamera (Süden) ----
    tx, tz = MX - W - ARM * 0.55, zl - 0.55
    box("Tafel", (0.85, 0.05, 0.62), (tx, MY - 0.02, tz), BLUE, bevel=0.02)
    box("Tafelrahmen", (0.92, 0.07, 0.69), (tx, MY + 0.01, tz), DARK, bevel=0.015)
    for sx in (-0.32, 0.32):
        bar(f"Aufhängung{sx}", (tx + sx, MY, zl - 0.02), (tx + sx, MY, tz + 0.33), 0.012, DARK)
    pts = [(-0.24, -0.18), (0.0, 0.17), (0.24, -0.18)]
    P = [Vector((tx + px, MY - 0.055, tz + pz)) for px, pz in pts]
    for i in range(3):
        bar(f"Netzlinie{i}", P[i], P[(i + 1) % 3], 0.022, WHITE)
    for i, p in enumerate(P):
        cyl(f"Netzpunkt{i}", 0.075, 0.03, p, ORANGE, rot=(math.pi / 2, 0, 0))

    # ---- Signallampe und Schaltkasten (wie Vanilla) ----
    cyl("Lampengehäuse", 0.13, 0.16, (MX + 0.05, MY - 0.38, H + 0.2), DARK, rot=(math.pi / 2, 0, 0))
    cyl("Lampenschirm", 0.15, 0.05, (MX + 0.05, MY - 0.45, H + 0.27), DARK, rot=(math.pi / 2.6, 0, 0))
    cyl("Lampe", 0.095, 0.03, (MX + 0.05, MY - 0.465, H + 0.2), LAMP, rot=(math.pi / 2, 0, 0))
    box("Schaltschrank", (0.5, 0.34, 0.72), (MX + 0.62, MY - 0.55, 0.36 + 0.22), STEEL, bevel=0.03)
    box("Schranktür", (0.42, 0.02, 0.6), (MX + 0.62, MY - 0.725, 0.58), BLUE, bevel=0.01)
    box("Schrankdach", (0.56, 0.4, 0.04), (MX + 0.62, MY - 0.55, 0.96), DARK)
    for k in range(3):
        box(f"Lüftung{k}", (0.3, 0.012, 0.025), (MX + 0.62, MY - 0.738, 0.78 - k * 0.05), DARK, bevel=0)
    # Kabel vom Schrank in den Mast
    bar("Kabel", (MX + 0.45, MY - 0.4, 0.92), (MX + W, MY - W + 0.05, 1.3), 0.02, DARK)

    return col
