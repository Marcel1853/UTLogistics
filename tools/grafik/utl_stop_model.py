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
    # Umgebungsverdeckung: Ecken, Fugen und Kontaktstellen dunkler – das gibt den kräftigen Factorio-Look
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    ao.samples = 16
    ao.inputs["Color"].default_value = base
    nt.links.new(ao.outputs["Color"], bsdf.inputs["Base Color"])
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
        nt.links.new(ramp.outputs["Color"], ao.inputs["Color"])
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
    # neutral grau (keine Eigenfarbe), damit die Stationsfarbe im Spiel sauber tönt – Regel aus Friday Facts #218
    TINT = _mat("Stationsfarbe (Maske)", (0.44, 0.44, 0.44), 0.3, 0.5, rust=0.2)
    ORANGE = _mat("Ocker", (0.2542, 0.1441, 0.0423), 0.2, 0.6, rust=0.35)  # gedeckt statt Signalorange
    LAMP = _mat("Lampe", (0.9, 0.6, 0.1), 0.0, 0.2, emission=(1.0, 0.65, 0.15))  # gelb wie Vanilla
    # Elektrik: farbige Kabelmäntel (rot/grün wie Factorios Signalkabel, gelb für Strom), Meldeleuchten
    WIRE = [_mat("Kabel rot", (0.32, 0.03, 0.02), 0.1, 0.4), _mat("Kabel grün", (0.03, 0.22, 0.04), 0.1, 0.4),
            _mat("Kabel gelb", (0.42, 0.3, 0.02), 0.1, 0.4)]
    LED_G = _mat("Meldeleuchte grün", (0.1, 0.8, 0.15), 0.0, 0.3, emission=(0.2, 1.0, 0.25))
    LED_R = _mat("Meldeleuchte rot", (0.8, 0.1, 0.05), 0.0, 0.3, emission=(1.0, 0.15, 0.05))

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
    box("Sockel", (1.3, 1.3, 0.18), (MX, MY, 0.09), CONCRETE, bevel=0.035)
    box("Fußkonsole", (0.62, 0.62, 0.12), (MX, MY, 0.22), DARK, bevel=0.02)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        # Stütze vom Mast (in 1,1 Höhe) schräg nach außen auf den Sockel
        angle_iron(f"Stütze{i}", (MX + sx * 0.5, MY + sy * 0.5, 0.2), (MX + sx * W, MY + sy * W, 1.15), 0.06, STEEL)
        box(f"Stützenfuß{i}", (0.18, 0.18, 0.05), (MX + sx * 0.5, MY + sy * 0.5, 0.205), DARK, bevel=0.01)
        for bx, by in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            cyl(f"Anker{i}_{bx}{by}", 0.018, 0.05, (MX + sx * 0.5 + bx * 0.055, MY + sy * 0.5 + by * 0.055, 0.24),
                DARK, verts=6)

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
        rot = Matrix.Rotation(tilt, 4, "Y")  # positiv: Spitze (Westen) liegt höher
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
    # Zugstangen vom Querhaupt auf der Mastspitze zu Laschen auf der Auslegeroberseite – beide Enden
    # sitzen sichtbar fest (vorher hingen sie in der Luft)
    def on_arm(offset, side, up):
        """Weltpunkt auf dem Ausleger: offset entlang (Westen positiv), seitlich, Höhe über der Mittellinie."""
        return mid + Matrix.Rotation(tilt, 4, "Y") @ Vector((-offset, side, up))
    bar("Mastspitze", (MX, MY, H + 0.5), (MX, MY, H + 1.0), 0.035, STEEL)
    box("Querhaupt", (0.14, 0.34, 0.09), (MX, MY, H + 0.97), DARK, bevel=0.015)
    oa = length / 2 - 0.45  # Anschlagpunkt der Zugstangen, 0,45 Felder vor der Spitze
    # Ankerplatte quer über die ganze Oberplatte, darauf die Laschen – alles in Auslegerneigung
    arm_part("Ankerplatte", (0.22, 0.3, 0.025), (oa, 0, 0.177), DARK, bevel=0.006)
    for k, side in enumerate((-0.12, 0.12)):
        box(f"Lasche oben{k}", (0.08, 0.035, 0.12), (MX - 0.04, MY + side, H + 0.95), DARK, bevel=0.008)
        arm_part(f"Lasche Ausleger{k}", (0.12, 0.035, 0.11), (oa, side, 0.24), DARK, bevel=0.008)
        a = Vector((MX - 0.06, MY + side, H + 0.94))
        b = on_arm(oa, side, 0.26)
        bar(f"Zugstange{k}", a, b, 0.016, DARK)
        d = b - a
        cyl(f"Spannschloss{k}", 0.026, 0.16, (a + b) / 2, STEEL, rot=(0, math.atan2(d.x, d.z), 0), verts=8)
    # Nietreihen an beiden Seitenwänden
    for side in (-1, 1):
        for k in range(14):
            off = -length / 2 + 0.1 + k * (length - 0.2) / 13
            for z in (0.09, -0.09):
                arm_part(f"Niete{side}_{k}_{z}", (0.03, 0.02, 0.03), (off, side * 0.168, z), DARK, bevel=0.006)

    # ---- Signallampen unter der Auslegerspitze (zwei, wie Vanilla) ----
    lx = xe + 0.05
    lz = on_arm(length / 2 + 0.05, 0, -0.19).z - 0.15  # Träger hängt direkt unter dem Spitzenkasten
    box("Lampenträger", (0.3, 0.14, 0.34), (lx, MY - 0.02, lz), DARK, bevel=0.02)
    for k, dz in enumerate((0.08, -0.08)):
        cyl(f"Lampenschirm{k}", 0.065, 0.06, (lx, MY - 0.11, lz + dz + 0.01), DARK, rot=(math.pi / 2, 0, 0))
        cyl(f"Lampe{k}", 0.05, 0.02, (lx, MY - 0.14, lz + dz), LAMP, rot=(math.pi / 2, 0, 0))

    # ---- Schaltkasten am Mastfuß (steht ganz auf dem Sockel) ----
    box("Schaltkasten", (0.4, 0.3, 0.55), (MX - 0.05, MY - 0.45, 0.455), STEEL, bevel=0.03)
    box("Kastendach", (0.46, 0.36, 0.04), (MX - 0.05, MY - 0.45, 0.75), DARK)
    box("Kastentür", (0.32, 0.02, 0.44), (MX - 0.05, MY - 0.61, 0.455), DARK, bevel=0.008)

    # ---- Kabel vom Kasten unter dem Gleis hindurch nach Westen (wie Vanilla) ----
    for k, dy in enumerate((-0.06, 0.0, 0.06)):
        pts = [Vector((MX - 0.25, MY - 0.45 + dy, 0.3)), Vector((MX - 0.5, MY - 0.55 + dy, 0.06)),
               Vector((MX - 1.0, MY - 0.7 + dy, 0.03)), Vector((-1.6, MY - 0.7 + dy, 0.03)),
               Vector((-2.0, MY - 0.4 + dy, 0.05))]
        for i in range(len(pts) - 1):
            bar(f"Kabel{k}_{i}", pts[i], pts[i + 1], 0.022, WIRE[k])
    # Kabelkanal entlang des Gleises: durchgehende Betonrinne, eingelassen, mit Deckeln obendrauf
    box("Kabelrinne", (0.22, 1.7, 0.05), (MX - 0.85, MY, 0.015), CONCRETE, bevel=0.01)
    for k in range(5):
        box(f"Kanaldeckel{k}", (0.18, 0.31, 0.02), (MX - 0.85, MY + 0.7 - k * 0.35, 0.045), CONCRETE, bevel=0.008)
    # Verteilerkästen auf der anderen Gleisseite: auf einer gemeinsamen Betonplatte, mit Füßen und Dach
    box("Verteilerplatte", (0.75, 0.6, 0.06), (-2.2, MY - 0.5, 0.02), CONCRETE, bevel=0.015)
    for k, x in enumerate((-2.05, -2.35)):
        box(f"Verteilerfuß{k}", (0.24, 0.42, 0.05), (x, MY - 0.5, 0.075), DARK, bevel=0.006)
        box(f"Verteiler{k}", (0.22, 0.4, 0.28), (x, MY - 0.5, 0.24), STEEL, bevel=0.025)
        box(f"Verteilerdach{k}", (0.26, 0.44, 0.03), (x, MY - 0.5, 0.395), DARK, bevel=0.008)
    box("Kleinverteilerplatte", (0.36, 0.36, 0.05), (-2.1, MY + 0.5, 0.015), CONCRETE, bevel=0.012)
    box("Kleinverteiler", (0.25, 0.25, 0.22), (-2.1, MY + 0.5, 0.15), DARK, bevel=0.02)
    for k, x in enumerate((-2.05, -2.35)):
        cyl(f"Verteilerleuchte{k}", 0.02, 0.012, (x + 0.05, MY - 0.705, 0.32), (LED_G, LED_R)[k],
            rot=(math.pi / 2, 0, 0), verts=10)
    bar("Kabel Kleinverteiler", (-2.12, MY - 0.29, 0.06), (-2.1, MY + 0.38, 0.06), 0.016, WIRE[1])

    # ---- Steuerschrank an der Ostseite des Sockels: steuert Halt und Signal, darum mit Meldeleuchten ----
    sx, sy = MX + 0.47, MY + 0.02
    box("Steuerschrank", (0.2, 0.42, 0.62), (sx, sy, 0.49), STEEL, bevel=0.02)
    box("Steuerschrankdach", (0.24, 0.46, 0.03), (sx, sy, 0.815), DARK, bevel=0.006)
    box("Steuerschranktür", (0.015, 0.36, 0.52), (sx + 0.105, sy, 0.48), DARK, bevel=0.004)
    for k in range(4):  # Lüftungsschlitze vorn
        box(f"Lüftung{k}", (0.14, 0.012, 0.018), (sx, sy - 0.215, 0.62 + k * 0.04), DARK, bevel=0.002)
    for k, led in enumerate((LED_G, LED_G, LED_R)):
        cyl(f"Meldeleuchte{k}", 0.02, 0.012, (sx - 0.05 + k * 0.05, sy - 0.216, 0.4), led, rot=(math.pi / 2, 0, 0),
            verts=10)
    for k in range(3):  # Kabelbündel Steuerschrank → Schaltkasten, flach über den Sockel
        dz = 0.2 + k * 0.025
        bar(f"Steuerkabel{k}", (sx - 0.09, sy - 0.12, dz), (MX + 0.16, MY - 0.4 + k * 0.03, dz), 0.012, WIRE[k])

    # ---- Kabel am Mast hoch und unter dem Ausleger zu den Lampen, mit Schellen ----
    cx, cy = MX - W - 0.05, MY - W - 0.05
    route = [Vector((MX - 0.2, MY - 0.42, 0.77)), Vector((cx, cy, 0.95)), Vector((cx, cy, H + 0.1)),
             on_arm(-length / 2 + 0.1, -0.1, -0.2), on_arm(length / 2 - 0.25, -0.1, -0.2),
             Vector((lx + 0.1, MY - 0.06, lz + 0.17))]
    for k, (dx, w) in enumerate(((-0.02, WIRE[0]), (0.02, WIRE[2]))):
        for i in range(len(route) - 1):
            off = Vector((dx, 0, 0))
            bar(f"Lampenkabel{k}_{i}", route[i] + off, route[i + 1] + off, 0.012, w)
    for k in range(6):
        box(f"Schelle{k}", (0.09, 0.05, 0.03), (cx, cy, 1.2 + k * 0.45), DARK, bevel=0.005)
    # Abzweigkasten auf halber Masthöhe, das Lampenkabel läuft hindurch
    box("Abzweigkasten", (0.16, 0.08, 0.2), (cx, cy - 0.03, 1.9), STEEL, bevel=0.012)
    cyl("Abzweigleuchte", 0.016, 0.01, (cx, cy - 0.075, 1.96), LED_G, rot=(math.pi / 2, 0, 0), verts=10)

    return col
