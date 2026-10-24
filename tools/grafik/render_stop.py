# UTL-Haltestelle rendern: Modell aus utl_stop_model.py, Aufbau aus rig.py (Blender 5.x, headless):
#   blender -b --factory-startup --python tools/grafik/render_stop.py -- <render_ordner> [--samples N] [--nur north] [--durchgang top] [--ohne-render]
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
# Bildausschnitt großzügig (Modell reicht ≈ 2,5 Felder nach Westen und ≈ 4 Felder hoch); sprites.py schneidet zu
rig.camera(8, 8, shift=1.5)
col = utl_stop_model.build()  # räumt lose Meshes weg – den Schattenfänger daher erst danach anlegen
catcher = rig.shadow_catcher()
meshes = [o for o in col.objects if o.type == "MESH"]
root = rig.pivot(list(col.objects))
print("[STOP]", len(meshes), "Teile, Richtungen:", ", ".join(directions))
if "--ohne-render" in a:
    sys.exit(0)
rig.render(out, root, meshes, catcher, samples=samples, directions=directions, passes=passes)
