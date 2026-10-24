# Modell der UTL-Ausgaben (Auftrags-Ausgabe und Depot-Ausgabe, Blender 5.x): Schaltkasten neben der Haltestelle
# nach dem Vorbild des Vanilla-Kombinators – abgerundetes, verschmutztes Gehäuse in der Kennfarbe, aufgesetzte
# Blechplatten mit Schrauben, Lüftungsgitter, geriffelter Schutzschlauch, Isolatoren auf einer Halteschiene mit
# roten/grünen Kabeln ins Gehäuse. 1 Feld groß, Vorderseite nach Süden (zur Kamera). Die Spitzen der Isolatoren
# „Anschluss rot“/„Anschluss grün“ sind die Anschlusspunkte der Signalkabel im Spiel (render_output.py).
# Benutzt von render_output.py (headless rendern) und live_stop.py (im offenen Blender ansehen).
import bpy
import math

from mathutils import Vector

import rig
from utl_stop_model import _mat

# gebrochene Kennfarbe des Gehäuses je Art (stark ins Grau gezogen): Auftrags-Ausgabe blau, Depot grün
KINDS = {"station": (0.075, 0.09, 0.12), "depot": (0.07, 0.095, 0.07)}
TERMINAL_Z = 0.74  # Höhe der Isolatorspitzen


def build(kind="station", name=None):
    name = name or f"UTL-Ausgabe {kind}"
    col = bpy.data.collections.get(name)
    if col:
        for o in list(col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)

    DARK = _mat("Stahl dunkel", (0.0452, 0.0369, 0.0356), 0.55, 0.65, rust=0.1)
    PLATE = _mat("Blech", (0.17, 0.16, 0.15), 0.7, 0.45, rust=0.35)
    BODY = _mat(f"Gehäuse {kind}", KINDS[kind], 0.35, 0.55, rust=0.15)  # Farbe überwiegt, Rost nur stellenweise
    HOSE = _mat("Schutzschlauch", (0.17, 0.12, 0.06), 0.4, 0.55, rust=0.3)
    CERAMIC = _mat("Isolator", (0.55, 0.55, 0.52), 0.0, 0.3)
    RED = _mat("Klemme rot", (0.14, 0.04, 0.03), 0.1, 0.6)
    GREEN = _mat("Klemme grün", (0.04, 0.09, 0.045), 0.1, 0.6)
    color = KINDS[kind]
    SCREEN = _mat(f"Anzeige {kind}", tuple(c * 0.5 for c in color), 0.0, 0.2,
                  emission=tuple(c * 0.5 for c in color))  # schwach: _mat leuchtet mit Stärke 8
    LED_G = _mat("Meldeleuchte grün", (0.1, 0.8, 0.15), 0.0, 0.3, emission=(0.2, 1.0, 0.25))
    LED_R = _mat("Meldeleuchte rot", (0.8, 0.1, 0.05), 0.0, 0.3, emission=(1.0, 0.15, 0.05))
    GLASS = _mat("Glas", (0.02, 0.05, 0.05), 0.0, 0.08)

    def link(o, material):
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
        o.data.materials.append(material)
        return o

    def box(label, size, loc, material, bevel=0.012, segments=2):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.object
        o.name = label
        o.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            b = o.modifiers.new("Fase", "BEVEL")
            b.width = bevel
            b.segments = segments
            b.limit_method = "ANGLE"
        return link(o, material)

    def cyl(label, r, h, loc, material, rot=(0, 0, 0), verts=16):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts)
        o = bpy.context.object
        o.name = label
        bpy.ops.object.shade_smooth()
        return link(o, material)

    def tube(label, points, r, material):
        return link(rig.tube(label, points, r), material)

    def bolts(label, center, w, h, axis):
        """Vier Schrauben an den Ecken einer Platte; axis: Blickrichtung der Fläche ('y' vorn, 'x' Seite, 'z' oben)."""
        cx, cy, cz = center
        for k, (a, b) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
            if axis == "y":
                loc, rot = (cx + a * w / 2, cy, cz + b * h / 2), (math.pi / 2, 0, 0)
            elif axis == "x":
                loc, rot = (cx, cy + a * w / 2, cz + b * h / 2), (0, math.pi / 2, 0)
            else:
                loc, rot = (cx + a * w / 2, cy + b * h / 2, cz), (0, 0, 0)
            cyl(f"{label} Schraube{k}", 0.014, 0.012, loc, PLATE, rot=rot, verts=6)

    def grille(label, center, w, h, axis, slats=5):
        """Lüftungsgitter: Rahmen und waagerechte Lamellen."""
        cx, cy, cz = center
        if axis == "y":
            box(f"{label} Rahmen", (w, 0.014, h), center, DARK, bevel=0.004)
            for k in range(slats):
                z = cz - h / 2 + (k + 0.5) * h / slats
                box(f"{label} Lamelle{k}", (w * 0.86, 0.02, h / slats * 0.45), (cx, cy - 0.006, z), PLATE, bevel=0.003)
        else:  # oben
            box(f"{label} Rahmen", (w, h, 0.014), center, DARK, bevel=0.004)
            for k in range(slats):
                y = cy - h / 2 + (k + 0.5) * h / slats
                box(f"{label} Lamelle{k}", (w * 0.86, h / slats * 0.45, 0.02), (cx, y, cz + 0.006), PLATE, bevel=0.003)

    # Fuß und abgerundetes Gehäuse
    box("Fuß", (0.84, 0.66, 0.05), (0, 0, 0.025), DARK, bevel=0.012)
    box("Gehäuse", (0.8, 0.62, 0.42), (0, 0, 0.26), BODY, bevel=0.07, segments=4)
    # Vorderseite: aufgesetzte Platte mit Schrauben, Lüftungsgitter, Rundinstrument
    box("Frontplatte", (0.42, 0.016, 0.2), (-0.1, -0.312, 0.3), PLATE, bevel=0.006)
    bolts("Frontplatte", (-0.1, -0.322, 0.3), 0.36, 0.15, "y")
    grille("Frontgitter", (-0.1, -0.324, 0.31), 0.28, 0.1, "y", slats=5)
    # kleiner Bildschirm mit drei Meldeleuchten darunter, darunter das Rundinstrument
    box("Bildschirmrahmen", (0.18, 0.016, 0.08), (0.22, -0.314, 0.385), DARK, bevel=0.004)
    box("Bildschirm", (0.14, 0.01, 0.045), (0.22, -0.322, 0.387), SCREEN, bevel=0.002)
    for k, (x, led) in enumerate(zip((0.17, 0.22, 0.27), (LED_G, LED_G, LED_R))):
        cyl(f"Meldeleuchte{k}", 0.011, 0.01, (x, -0.316, 0.322), led, rot=(math.pi / 2, 0, 0), verts=10)
    cyl("Instrument", 0.05, 0.03, (0.22, -0.315, 0.225), DARK, rot=(math.pi / 2, 0, 0), verts=20)
    cyl("Instrumentglas", 0.037, 0.012, (0.22, -0.332, 0.225), GLASS, rot=(math.pi / 2, 0, 0), verts=20)
    # Oberseite: Wartungsdeckel mit Schrauben und Gitter, Halteschiene mit Isolatoren
    box("Deckel", (0.36, 0.24, 0.016), (0.08, -0.08, 0.475), PLATE, bevel=0.006)
    bolts("Deckel", (0.08, -0.08, 0.485), 0.3, 0.18, "z")
    grille("Deckelgitter", (0.08, -0.08, 0.486), 0.22, 0.14, "z", slats=4)
    box("Halteschiene", (0.5, 0.05, 0.035), (0, 0.17, 0.52), DARK, bevel=0.008)
    for x in (-0.22, 0.22):
        box(f"Schienenstütze{x}", (0.04, 0.05, 0.07), (x, 0.17, 0.48), DARK, bevel=0.006)
    for label, x, material, side in (("Anschluss rot", -0.16, RED, -1), ("Anschluss grün", 0.16, GREEN, 1)):
        for k in range(3):  # Isolator aus drei Scheiben
            cyl(f"{label} Isolator{k}", 0.034 - k * 0.004, 0.035, (x, 0.17, 0.555 + k * 0.045), CERAMIC, verts=14)
        cyl(label, 0.03, 0.04, (x, 0.17, TERMINAL_Z - 0.02), material, verts=12)
        # Kabel von der Klemme im Bogen außen herum ins Gehäuse
        tube(f"{label} Kabel", [(x, 0.2, TERMINAL_Z - 0.04), (x + side * 0.08, 0.27, 0.66),
                               (x + side * 0.16, 0.3, 0.52), (x + side * 0.2, 0.31, 0.38)], 0.018, material)
    # Geriffelter Schutzschlauch über die Westseite: glattes Rohr mit Rippenringen
    hose = [(-0.3, -0.2, 0.47), (-0.43, -0.12, 0.46), (-0.47, 0.02, 0.32), (-0.44, 0.16, 0.14), (-0.3, 0.26, 0.06)]
    tube("Schutzschlauch", hose, 0.04, HOSE)
    pts = rig.smooth(hose, 12)
    for k in range(1, len(pts) - 1, 2):
        d = (pts[k + 1] - pts[k - 1]).normalized()
        bpy.ops.mesh.primitive_torus_add(major_radius=0.042, minor_radius=0.009, location=pts[k],
                                         major_segments=14, minor_segments=6)
        o = bpy.context.object
        o.name = f"Schlauchrippe{k}"
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        link(o, HOSE)
    for k, p in enumerate((hose[0], hose[-1])):  # Schellen an den Enden
        cyl(f"Schlauchschelle{k}", 0.05, 0.03, p, PLATE, verts=12)
    # Seitenplatte Ost mit Schrauben
    box("Seitenplatte", (0.016, 0.34, 0.18), (0.402, 0.02, 0.26), PLATE, bevel=0.006)
    bolts("Seitenplatte", (0.412, 0.02, 0.26), 0.28, 0.13, "x")
    return col


def terminals(col):
    """Weltpunkte der Klemmenspitzen (rot, grün) – nach dem Drehen für die jeweilige Richtung abfragen."""
    out = {}
    for color, label in (("red", "Anschluss rot"), ("green", "Anschluss grün")):
        o = col.objects[label]
        p = o.matrix_world @ Vector((0, 0, 0.02))
        out[color] = (p.x, p.y, p.z)
    return out
