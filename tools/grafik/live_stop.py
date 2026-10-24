# Haltestelle im offenen Blender zeigen – zum Anschauen und Besprechen vor dem Rendern:
#   blender --online-mode --python tools/grafik/live_stop.py
# Gleicher Aufbau wie render_stop.py (Kamera, Licht, Schattenfänger), Ansicht durch die Factorio-Kamera.
# --online-mode: Die MCP-Erweiterung startet ihren Server nur mit Online-Zugriff (für Änderungen über Claude).
# Modell nach Änderungen an utl_stop_model.py neu bauen (Python-Konsole oder MCP):
#   bpy.app.driver_namespace["utl_rebuild"]()
# Alle vier Richtungen nebeneinander: bpy.app.driver_namespace["utl_overview"]()
import bpy
import importlib
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
import utl_stop_model  # noqa: E402


def rebuild():
    importlib.reload(utl_stop_model)
    col = utl_stop_model.build()
    root = bpy.data.objects.get("Drehpunkt")
    for o in col.objects:
        if o.parent is None:
            o.parent = root
    print("[LIVE] Modell neu gebaut:", len(col.objects), "Teile")
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


def overview(step=7.0):
    """Alle vier Richtungen nebeneinander (Nord, Ost, Süd, West) als verknüpfte Kopien – ändern sich beim
    Neubau mit. Eigene Kamera „Übersicht“ nur für die Ansicht; gerendert wird weiter über „Kamera“."""
    import math
    col = bpy.data.collections[utl_stop_model.COLLECTION]
    for i in range(1, 4):
        name = f"Richtung {rig.DIRECTIONS[i]}"
        o = bpy.data.objects.get(name) or bpy.data.objects.new(name, None)
        if not o.users_collection:
            bpy.context.scene.collection.objects.link(o)
        o.instance_type = "COLLECTION"
        o.instance_collection = col
        o.location = (i * step, 0, 0)
        o.rotation_euler = (0, 0, -i * math.pi / 2)
    catcher = bpy.data.objects.get("Schattenfänger")
    if catcher:
        catcher.scale = (3, 1, 1)
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


rig.reset(live=True)
rig.lights()
rig.camera(8, 8, shift=1.5)
col = utl_stop_model.build()
rig.shadow_catcher()
rig.pivot(list(col.objects))
bpy.app.driver_namespace["utl_rebuild"] = rebuild
bpy.app.driver_namespace["utl_overview"] = overview
bpy.app.timers.register(view, first_interval=1.0)
