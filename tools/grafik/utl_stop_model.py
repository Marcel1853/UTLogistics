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
        # Anteil Rost ≈ `rust`: Rauschwerte liegen meist zwischen 0,3 und 0,7
        ramp.color_ramp.elements[0].position = 0.28 + 0.4 * rust
        ramp.color_ramp.elements[0].color = (0.16, 0.075, 0.035, 1)
        ramp.color_ramp.elements[1].position = 0.36 + 0.4 * rust
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

    STEEL = _mat("Stahl lackiert", (0.1441, 0.1221, 0.1119), 0.55, 0.6, rust=0.15)  # Vanilla #595351…#989493
    DARK = _mat("Stahl dunkel", (0.0452, 0.0369, 0.0356), 0.55, 0.65, rust=0.1)  # Vanilla #3c3635/#302725
    CONCRETE = _mat("Beton", (0.2159, 0.1981, 0.1912), 0.0, 0.92, rust=0.3)  # Vanilla-Boden #807b79
    TINT = _mat("Stationsfarbe (Maske)", (0.4564, 0.4233, 0.4072), 0.3, 0.5, rust=0.2)  # hell: wird im Spiel mit der Stationsfarbe getönt
    ORANGE = _mat("Ocker", (0.2542, 0.1441, 0.0423), 0.2, 0.6, rust=0.35)  # gedeckt statt Signalorange
    CABLE = _mat("Kabel", (0.03, 0.03, 0.035), 0.1, 0.45)
    LAMP = _mat("Lampe", (0.9, 0.6, 0.1), 0.0, 0.2, emission=(1.0, 0.65, 0.15))  # gelb wie Vanilla

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

    # ---- Maße (gemessen an Vanilla, Felder) ----
    MX, MY = 0.55, 0.5         # Mastmitte (rechts im 2×2-Feld, Gleis links/Westen)
    W = 0.2                    # halbe Mastbreite (schmaler Gitterturm wie Vanilla)
    H = 3.5                    # Masthöhe bis zum Ausleger
    ARM = 2.5                  # Ausleger nach Westen
    RISE = 0.25                # Ausleger steigt zur Spitze leicht an (nicht kerzengerade)

    # ---- Fuß: Betonsockel, Konsole und schräge Stützen ----
    box("Sockel", (0.9, 0.9, 0.16), (MX, MY, 0.08), CONCRETE, bevel=0.03)
    box("Fußkonsole", (0.62, 0.62, 0.12), (MX, MY, 0.22), DARK, bevel=0.02)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        # Stütze vom Mast (in 1,1 Höhe) schräg nach außen auf den Sockel
        angle_iron(f"Stütze{i}", (MX + sx * 0.42, MY + sy * 0.42, 0.18), (MX + sx * W, MY + sy * W, 1.15), 0.06, STEEL)
        box(f"Stützenfuß{i}", (0.14, 0.14, 0.05), (MX + sx * 0.42, MY + sy * 0.42, 0.185), DARK, bevel=0.01)
        cyl(f"Anker{i}", 0.025, 0.05, (MX + sx * 0.42, MY + sy * 0.42, 0.22), DARK, verts=6)

    # ---- Gittermast ----
    corners = [(MX - W, MY - W), (MX + W, MY - W), (MX + W, MY + W), (MX - W, MY + W)]
    twists = [0, math.pi / 2, math.pi, -math.pi / 2]
    for i, (x, y) in enumerate(corners):
        angle_iron(f"Eckstiel{i}", (x, y, 0.28), (x, y, H + 0.1), 0.065, STEEL, twists[i])
    n = 8
    zs = [0.28 + k * (H - 0.28) / n for k in range(n + 1)]
    for k in range(n):
        for i in range(4):
            (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
            bar(f"Riegel{k}_{i}", (x0, y0, zs[k + 1]), (x1, y1, zs[k + 1]), 0.016, STEEL)
            a, b = ((x0, y0, zs[k]), (x1, y1, zs[k + 1])) if k % 2 == 0 else ((x1, y1, zs[k]), (x0, y0, zs[k + 1]))
            bar(f"Diagonale{k}_{i}", a, b, 0.012, DARK)

    # ---- Mastkopf ----
    box("Kopfplatte", (0.56, 0.56, 0.08), (MX, MY, H + 0.14), DARK)
    box("Kopf", (0.48, 0.5, 0.36), (MX + 0.02, MY, H + 0.36), TINT, bevel=0.03)

    # ---- Ausleger: Kastenträger in Stationsfarbe, leicht ansteigend ----
    import mathutils
    xs, xe = MX - W, MX - W - ARM
    z0 = H + 0.3
    mid = Vector(((xs + xe) / 2, MY, z0 + RISE / 2))
    length = math.hypot(ARM, RISE)
    tilt = math.atan2(RISE, ARM)
    def arm_part(name, size, offset, material, bevel=0.015):
        # offset entlang des Auslegers (x nach Westen positiv), seitlich (y), Höhe (z)
        o = box(name, size, (0, 0, 0), material, bevel=bevel)
        local = Vector((-offset[0], offset[1], offset[2]))
        rot = Matrix.Rotation(-tilt, 4, "Y")
        o.matrix_world = Matrix.Translation(mid + rot @ local) @ rot
        return o
    arm_part("Ausleger-Unterplatte", (length, 0.3, 0.05), (0, 0, -0.14), TINT)
    arm_part("Ausleger-Oberplatte", (length * 0.92, 0.3, 0.05), (-length * 0.04, 0, 0.14), TINT)
    for side in (-1, 1):
        # Seitenwand mit Aussparungen (mehrere Felder statt einer durchgehenden Platte)
        seg = 6
        for k in range(seg):
            off = -length / 2 + (k + 0.5) * length / seg
            arm_part(f"Seitenfeld{side}_{k}", (length / seg - 0.06, 0.03, 0.24), (off, side * 0.15, 0), TINT)
        arm_part(f"Randleiste{side}", (length, 0.035, 0.04), (0, side * 0.16, -0.12), DARK)
    arm_part("Spitzenkasten", (0.34, 0.4, 0.38), (length / 2 + 0.05, 0, 0.0), TINT, bevel=0.03)

    # Gebogene Strebe vom Mast zur Unterseite des Auslegers (wie Vanilla)
    p0 = Vector((MX - W, MY, H - 0.9))
    p1 = Vector((MX - W - 0.25, MY, H - 0.45))
    p2 = Vector((MX - W - 0.75, MY, z0 - 0.15 + RISE * 0.75 / ARM))
    for k in range(6):
        t0, t1 = k / 6, (k + 1) / 6
        q = lambda t: (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        bar(f"Strebe{k}", q(t0), q(t1), 0.05, STEEL)
    # Zugstangen vom Mastkopf zur Auslegerspitze
    tip = Vector((xe + 0.2, MY, z0 + RISE + 0.12))
    for side in (-0.12, 0.12):
        bar(f"Zugstange{side}", (MX, MY + side, H + 0.95), (tip.x + 0.5, MY + side, tip.z), 0.014, DARK)
    bar("Mastspitze", (MX, MY, H + 0.5), (MX, MY, H + 1.0), 0.03, STEEL)

    # ---- Signallampen unter der Auslegerspitze (zwei, wie Vanilla) ----
    lx = xe + 0.05
    lz = z0 + RISE - 0.45
    box("Lampenträger", (0.3, 0.14, 0.34), (lx, MY - 0.02, lz), DARK, bevel=0.02)
    for k, dz in enumerate((0.08, -0.08)):
        cyl(f"Lampenschirm{k}", 0.065, 0.06, (lx, MY - 0.11, lz + dz + 0.01), DARK, rot=(math.pi / 2, 0, 0))
        cyl(f"Lampe{k}", 0.05, 0.02, (lx, MY - 0.14, lz + dz), LAMP, rot=(math.pi / 2, 0, 0))

    # ---- Schaltkasten am Mastfuß ----
    box("Schaltkasten", (0.4, 0.3, 0.55), (MX - 0.05, MY - 0.55, 0.42), STEEL, bevel=0.03)
    box("Kastendach", (0.46, 0.36, 0.04), (MX - 0.05, MY - 0.55, 0.715), DARK)
    box("Kastentür", (0.32, 0.02, 0.44), (MX - 0.05, MY - 0.71, 0.42), DARK, bevel=0.008)

    # ---- Kabel vom Kasten unter dem Gleis hindurch nach Westen (wie Vanilla) ----
    for k, dy in enumerate((-0.06, 0.0, 0.06)):
        pts = [Vector((MX - 0.25, MY - 0.55 + dy, 0.25)), Vector((MX - 0.5, MY - 0.55 + dy, 0.06)),
               Vector((MX - 1.0, MY - 0.7 + dy, 0.03)), Vector((-1.6, MY - 0.7 + dy, 0.03)),
               Vector((-2.0, MY - 0.4 + dy, 0.05))]
        for i in range(len(pts) - 1):
            bar(f"Kabel{k}_{i}", pts[i], pts[i + 1], 0.022, CABLE)
    # Kabelkanal-Elemente entlang des Gleises und Verteilerkästen auf der anderen Seite
    for k in range(5):
        box(f"Kabelkanal{k}", (0.16, 0.18, 0.06), (MX - 0.85, MY + 0.7 - k * 0.35, 0.03), CONCRETE, bevel=0.015)
    box("Verteiler1", (0.22, 0.4, 0.3), (-2.05, MY - 0.5, 0.15), STEEL, bevel=0.025)
    box("Verteiler2", (0.22, 0.4, 0.3), (-2.35, MY - 0.5, 0.15), STEEL, bevel=0.025)
    box("Verteiler3", (0.25, 0.25, 0.22), (-2.1, MY + 0.5, 0.11), DARK, bevel=0.02)

    return col
