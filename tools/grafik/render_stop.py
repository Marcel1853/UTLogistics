# UTL-Haltestelle rendern: Modell aus utl_stop_model.py, Aufbau aus rig.py (Blender 5.x, headless):
#   blender -b --factory-startup --python tools/grafik/render_stop.py -- <render_ordner> [--samples N] [--nur north] [--durchgang top] [--ohne-verteiler] [--ohne-render]
# Danach: python3 tools/grafik/sprites.py <render_ordner> <ziel_ordner> utl-train-stop
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
import utl_stop_model  # noqa: E402

a = rig.args()
if not a:
    sys.exit("render_ordner fehlt")
out = a[0]
samples = int(a[a.index("--samples") + 1]) if "--samples" in a else 96
directions = (a[a.index("--nur") + 1],) if "--nur" in a else rig.DIRECTIONS
passes = (a[a.index("--durchgang") + 1],) if "--durchgang" in a else rig.PASSES

rig.reset()
rig.lights()
# Bildausschnitt großzügig: Verteiler ≈ 4,4 Felder neben der Mitte (gedreht auch nach Süden, also unten im Bild),
# Ausleger gedreht bis ≈ 5,6 Felder hoch im Bild; sprites.py schneidet zu
rig.camera(10, 12, shift=0.8)
catcher = rig.shadow_catcher()
# Je Richtung neu bauen, mit eigenem seed: die Kabel liegen dann in jeder Richtung etwas anders
for d in directions:
    old = bpy.data.objects.get("Drehpunkt")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    col = utl_stop_model.build(seed=rig.DIRECTIONS.index(d), distributor="--ohne-verteiler" not in a)
    meshes = [o for o in col.objects if o.type == "MESH"]
    root = rig.pivot(list(col.objects))
    print("[STOP]", d, len(meshes), "Teile")
    if "--ohne-render" not in a:
        rig.render(out, root, meshes, catcher, samples=samples, directions=(d,), passes=passes)
