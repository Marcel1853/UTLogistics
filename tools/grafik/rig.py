# Gemeinsamer Render-Aufbau für Factorio-Sprites (Blender 5.x, headless). Eigenbau nach den Ideen aus
# vertexvaar/factorio-bulk-wagons (nur angesehen, kein Code übernommen).
#
# Factorio zeichnet von schräg oben: orthografische Kamera, ca. 50° über dem Boden, Licht von oben links,
# Schatten fallen nach rechts. 1 Blender-Einheit = 1 Feld; im Spiel 64 px je Feld (scale 0.5).
#
# Durchgänge je Richtung (alle mit durchsichtigem Hintergrund):
#   color  – das beleuchtete Bild
#   mask   – weiß, wo im Spiel die Stationsfarbe draufkommt (Material mit „Stationsfarbe“ im Namen oder
#            Eigenschaft utl_tint), sonst leer
#   shadow – nur der Schatten, den das Modell auf den Boden wirft
#   top    – weiß, wo hochliegende Teile (Ausleger, Lampen) vorn sichtbar sind; daraus macht sprites.py die
#            obere Ebene, die das Spiel über Züge zeichnet (wie top_animations der Vanilla-Haltestelle)
# Die Bilder entstehen doppelt so groß und in der Höhe gestaucht; sprites.py rechnet sie auf Spielgröße um.
import bpy
import json
import math
import os
import sys
from mathutils import Vector

TILE_PX = 64
SUPERSAMPLE = 2
ELEVATION = math.radians(50)
DIRECTIONS = ("north", "east", "south", "west")
PASSES = ("color", "mask", "shadow", "top")
TOP_Z = 2.4  # Teile, die ganz über dieser Höhe liegen, gehören zur oberen Ebene (über den Zügen)


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def reset(live=False):
    """Leere Szene mit Cycles, durchsichtigem Hintergrund und neutraler Farbumrechnung.
    live: im offenen Blender nur die Szene leeren – Werkseinstellungen würden auch Add-ons (MCP) abschalten."""
    if live:
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError as error:
        print("[RIG] Cycles fehlt:", error)
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.6, 0.64, 0.72, 1)  # leicht kühles Himmelslicht
    bg.inputs[1].default_value = 0.3
    scene.world = world
    return scene


def lights():
    """Sonne von oben links (Schatten nach rechts, etwas nach unten) und schwaches Gegenlicht ohne Schatten."""
    def sun(name, travel, energy, shadow):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(2)
        data.use_shadow = shadow
        obj = bpy.data.objects.new(name, data)
        # Die Sonne leuchtet entlang ihrer -Z-Achse: so drehen, dass -Z in Laufrichtung des Lichts zeigt
        obj.rotation_euler = Vector(travel).normalized().to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(obj)
    sun("Sonne", (1.0, -0.05, -0.9), 4.0, True)  # flach von links: Schatten lang nach rechts wie Vanilla
    sun("Gegenlicht", (-0.6, 0.8, -0.8), 0.5, False)


def camera(width, height, shift=0.0):
    """Kamera über dem Ursprung (Boden). width/height: Bildgröße in Feldern, wie später im Spiel;
    shift: Bildmitte so viele Felder über dem Ursprung."""
    scene = bpy.context.scene
    data = bpy.data.cameras.new("Kamera")
    data.type = "ORTHO"
    data.ortho_scale = width
    data.sensor_fit = "HORIZONTAL"
    cam = bpy.data.objects.new("Kamera", data)
    look = Vector((0, math.cos(ELEVATION), -math.sin(ELEVATION)))
    up = Vector((0, math.sin(ELEVATION), math.cos(ELEVATION)))
    # Bodentiefe erscheint um sin(50°) gestaucht; sprites.py streckt das wieder, daher shift * sin
    cam.location = -look * 50 + up * (shift * math.sin(ELEVATION))
    cam.rotation_euler = (math.pi / 2 - ELEVATION, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = round(width * TILE_PX * SUPERSAMPLE)
    scene.render.resolution_y = round(height * math.sin(ELEVATION) * TILE_PX * SUPERSAMPLE)
    scene.render.resolution_percentage = 100
    scene["framing"] = (width, height, shift)
    return cam


def shadow_catcher(size=30):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    plane = bpy.context.object
    plane.name = "Schattenfänger"
    plane.is_shadow_catcher = True
    # Nur fürs Anschauen im offenen Blender: Erdboden wie in Factorio (beim Rendern zählt nur der Schatten)
    ground = bpy.data.materials.new("Boden (nur Vorschau)")
    ground.diffuse_color = (0.16, 0.13, 0.08, 1)
    ground.use_nodes = True
    bsdf = next(n for n in ground.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.16, 0.13, 0.08, 1)
    bsdf.inputs["Roughness"].default_value = 0.95
    plane.data.materials.append(ground)
    return plane


def pivot(objects):
    """Leeres Objekt im Ursprung, an dem das ganze Modell für die Richtungen gedreht wird."""
    root = bpy.data.objects.new("Drehpunkt", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objects:
        if o.parent is None:
            o.parent = root
    return root


def _is_tint(material):
    return material is not None and (material.get("utl_tint") or "Stationsfarbe" in material.name)


def _pass_materials():
    white = bpy.data.materials.new("Maske weiß")
    white.use_nodes = True
    nt = white.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 1, 1, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    hold = bpy.data.materials.new("Maske leer")
    hold.use_nodes = True
    nt = hold.node_tree
    nt.nodes.clear()
    ho = nt.nodes.new("ShaderNodeHoldout")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(ho.outputs[0], out.inputs["Surface"])
    return white, hold


def _is_top(obj):
    return min((obj.matrix_world @ Vector(c)).z for c in obj.bound_box) > TOP_Z


def render(out_dir, root, meshes, catcher, samples=96, directions=DIRECTIONS, passes=PASSES):
    """Rendert alle Richtungen und Durchgänge nach out_dir/<pass>_<richtung>.png."""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    w, h, shift = scene["framing"]
    framing = {"width": w, "height": h, "shift": shift, "supersample": SUPERSAMPLE, "elevation": math.degrees(ELEVATION)}
    for d in directions:  # je Richtung, damit man einzelne Richtungen neu rendern kann
        with open(os.path.join(out_dir, f"framing_{d}.json"), "w") as f:
            json.dump(framing, f)
    white, hold = _pass_materials()
    original = {o.name: list(o.data.materials) for o in meshes}
    for d in directions:
        root.rotation_euler = (0, 0, -DIRECTIONS.index(d) * math.pi / 2)  # im Uhrzeigersinn wie Factorio
        for kind in passes:
            catcher.hide_render = kind != "shadow"
            for o in meshes:
                o.visible_camera = kind != "shadow"  # im Schatten-Durchgang wirft das Modell nur Schatten
                mats = original[o.name]
                for i, m in enumerate(mats):
                    if kind == "mask":
                        o.data.materials[i] = white if _is_tint(m) else hold
                    elif kind == "top":
                        o.data.materials[i] = white if _is_top(o) else hold
                    else:
                        o.data.materials[i] = m
            mask = kind in ("mask", "top")
            scene.cycles.samples = 4 if mask else 64 if kind == "shadow" else samples
            scene.cycles.use_denoising = not mask
            scene.render.filepath = os.path.join(out_dir, f"{kind}_{d}.png")
            bpy.ops.render.render(write_still=True)
            print("[RIG] gerendert:", scene.render.filepath)
    for o in meshes:
        for i, m in enumerate(original[o.name]):
            o.data.materials[i] = m
        o.visible_camera = True


def smooth(points, steps=10):
    """Catmull-Rom-Kurve durch die Punkte, `steps` Zwischenpunkte je Abschnitt."""
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return out
