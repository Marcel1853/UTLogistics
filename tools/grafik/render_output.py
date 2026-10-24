# UTL-Ausgabe rendern: Modell aus utl_output_model.py, Aufbau aus rig.py (Blender 5.x, headless):
#   blender -b --factory-startup --python tools/grafik/render_output.py -- <render_ordner> station|depot
#       [--samples N] [--nur north] [--ohne-render]
# Schreibt zusätzlich wires_<richtung>.json (Klemmenspitzen) – sprites.py macht daraus die Anschlusspunkte.
# Danach: python3 tools/grafik/sprites.py <render_ordner> <ziel_ordner> utl-station-output
import bpy
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
import utl_output_model  # noqa: E402

a = rig.args()
if len(a) < 2 or a[1] not in utl_output_model.KINDS:
    sys.exit("render_ordner und Art (station|depot) fehlen")
out, kind = a[0], a[1]
samples = int(a[a.index("--samples") + 1]) if "--samples" in a else 96
directions = (a[a.index("--nur") + 1],) if "--nur" in a else rig.DIRECTIONS

rig.reset()
rig.lights()
rig.camera(3, 3, shift=0.4)  # 1 Feld groß, Schatten reicht ≈ 1 Feld nach rechts; sprites.py schneidet zu
col = utl_output_model.build(kind)
catcher = rig.shadow_catcher()
meshes = [o for o in col.objects if o.type == "MESH"]
root = rig.pivot(list(col.objects))
print("[AUSGABE]", kind, len(meshes), "Teile")
os.makedirs(out, exist_ok=True)
for d in directions:
    root.rotation_euler = (0, 0, -rig.DIRECTIONS.index(d) * math.pi / 2)
    bpy.context.view_layer.update()
    with open(os.path.join(out, f"wires_{d}.json"), "w") as f:
        json.dump(rig.terminals(col), f)
    if "--ohne-render" not in a:
        rig.render(out, root, meshes, catcher, samples=samples, directions=(d,), passes=("color", "mask", "shadow"))
