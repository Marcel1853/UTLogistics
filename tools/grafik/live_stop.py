# Haltestelle im offenen Blender zeigen – zum Anschauen und Besprechen vor dem Rendern:
#   blender --online-mode --python tools/grafik/live_stop.py
# Gleicher Aufbau wie render_stop.py (Kamera, Licht, Schattenfänger), Ansicht durch die Factorio-Kamera.
# --online-mode: Die MCP-Erweiterung startet ihren Server nur mit Online-Zugriff (für Änderungen über Claude).
# Modell nach Änderungen an utl_stop_model.py neu bauen (Python-Konsole oder MCP):
#   bpy.app.driver_namespace["utl_rebuild"]()
# Alle vier Richtungen nebeneinander: bpy.app.driver_namespace["utl_overview"]()
# Ausgaben daneben: bpy.app.driver_namespace["utl_outputs"]()
# Variante ohne Verteiler: bpy.app.driver_namespace["utl_distributor"] = False, dann neu bauen
import bpy
import importlib
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
import utl_stop_model  # noqa: E402


def rebuild():
    importlib.reload(rig)
    importlib.reload(utl_stop_model)
    col = utl_stop_model.build(distributor=_distributor())
    root = bpy.data.objects.get("Drehpunkt")
    for o in col.objects:
        if o.parent is None:
            o.parent = root
    for i in range(1, 4):  # Kopien der anderen Richtungen (mit eigenem seed) mit neu bauen, falls sichtbar
        name = f"{utl_stop_model.COLLECTION} {rig.DIRECTIONS[i]}"
        if bpy.data.collections.get(name):
            _direction_copy(i, name)
    print("[LIVE] Modell neu gebaut:", len(col.objects), "Teile")
    return col


def _distributor():
    return bpy.app.driver_namespace.get("utl_distributor", True)


def _direction_copy(i, name):
    """Modell mit seed i in eigene Sammlung bauen, die nur als Kopie (Instanz) angezeigt wird."""
    col = utl_stop_model.build(seed=i, name=name, distributor=_distributor())
    for parent in (bpy.context.scene.collection,):
        if col.name in parent.children:
            parent.children.unlink(col)
    return col


def rail_guide():
    """Gleis als Hilfsstreifen (nur in der Ansicht, nicht im Render): Mitte 2 Felder westlich, 2 Felder breit,
    dazu dunkler Schotter bis ±1,2 Felder."""
    col = bpy.data.collections.get("Gleis (Vorschau)") or bpy.data.collections.new("Gleis (Vorschau)")
    if not col.users:
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for name, width, z, color in (("Schotter", 2.4, 0.004, (0.2, 0.18, 0.16, 1)), ("Schiene West", 0.08, 0.02, (0.6, 0.6, 0.62, 1)),
                                  ("Schiene Ost", 0.08, 0.02, (0.6, 0.6, 0.62, 1))):
        x = {"Schiene West": -2.72, "Schiene Ost": -1.28}.get(name, -2.0)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, 0, z))
        o = bpy.context.object
        o.name = name
        o.scale = (width, 9, 1)
        m = bpy.data.materials.new(name)
        m.diffuse_color = color
        m.use_nodes = True
        next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = color
        o.data.materials.append(m)
        for c in o.users_collection:
            c.objects.unlink(o)
        col.objects.link(o)
        o.hide_render = True
    return col


def view():
    """Alle 3D-Ansichten durch die Kamera und mit Materialvorschau."""
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.region_3d.view_perspective = "CAMERA"
                space.shading.type = "MATERIAL"
                space.overlay.show_floor = False
    return None


def overview(step=10.0):
    """Alle vier Richtungen nebeneinander (Nord, Ost, Süd, West) als verknüpfte Kopien – ändern sich beim
    Neubau mit. Eigene Kamera „Übersicht“ nur für die Ansicht; gerendert wird weiter über „Kamera“."""
    import math
    guide = rail_guide()
    for label in ("Richtung", "Gleis"):
        for i in range(1, 4):
            name = f"{label} {rig.DIRECTIONS[i]}"
            col = guide if label == "Gleis" else _direction_copy(i, f"{utl_stop_model.COLLECTION} {rig.DIRECTIONS[i]}")
            o = bpy.data.objects.get(name) or bpy.data.objects.new(name, None)
            if not o.users_collection:
                bpy.context.scene.collection.objects.link(o)
            o.instance_type = "COLLECTION"
            o.instance_collection = col
            o.location = (i * step, 0, 0)
            o.rotation_euler = (0, 0, -i * math.pi / 2)
            o.hide_render = True
    catcher = bpy.data.objects.get("Schattenfänger")
    if catcher:
        catcher.scale = (4, 1, 1)
        catcher.location = (1.5 * step, 0, 0)
    cam = bpy.data.objects.get("Übersicht")
    if not cam:
        data = bpy.data.cameras.new("Übersicht")
        data.type = "ORTHO"
        cam = bpy.data.objects.new("Übersicht", data)
        bpy.context.scene.collection.objects.link(cam)
    main = bpy.context.scene.camera
    cam.data.ortho_scale = 4 * step + 1
    cam.rotation_euler = main.rotation_euler
    cam.location = main.location + Vector((1.5 * step, 0, 0))
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.use_local_camera = True
                space.camera = cam
                space.region_3d.view_perspective = "CAMERA"


def outputs():
    """Auftrags- und Depot-Ausgabe (utl_output_model.py) neben die Haltestelle stellen, in allen vier Richtungen
    nebeneinander (Kopien); neu bauen nach Änderungen: erneut aufrufen."""
    import math
    import utl_output_model
    importlib.reload(utl_output_model)
    for row, kind in enumerate(("station", "depot")):
        col = utl_output_model.build(kind)
        if col.name in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.unlink(col)
        for i, d in enumerate(rig.DIRECTIONS):
            name = f"Ausgabe {kind} {d}"
            o = bpy.data.objects.get(name) or bpy.data.objects.new(name, None)
            if not o.users_collection:
                bpy.context.scene.collection.objects.link(o)
            o.instance_type = "COLLECTION"
            o.instance_collection = col
            o.location = (2.5 + i * 1.6, -2.5 - row * 1.8, 0)
            o.rotation_euler = (0, 0, -i * math.pi / 2)
            o.hide_render = True


rig.reset(live=True)
rig.lights()
rig.camera(13, 12, shift=0.8, shift_x=1.5)
col = utl_stop_model.build()
rig.shadow_catcher()
rig.pivot(list(col.objects))
bpy.app.driver_namespace["utl_rebuild"] = rebuild
bpy.app.driver_namespace["utl_overview"] = overview
bpy.app.driver_namespace["utl_outputs"] = outputs
bpy.app.timers.register(view, first_interval=1.0)
