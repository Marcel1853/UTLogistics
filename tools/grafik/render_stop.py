# UTL-Haltestelle rendern: Modell aus utl_stop_model.py, Aufbau aus rig.py (Blender 5.x, headless):
#   blender -b --factory-startup --python tools/grafik/render_stop.py -- <render_ordner> [--samples N] [--nur north] [--durchgang top] [--ohne-verteiler] [--ohne-render] [--blend DATEI]
# Schreibt zusätzlich wires_<richtung>.json (Klemmen auf dem Steuerschrank) für die Anschlusspunkte der Signalkabel.
# Danach: python3 tools/grafik/sprites.py <render_ordner> <ziel_ordner> utl-train-stop
import bpy
import json
import math
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
# Ausleger gedreht bis ≈ 5,6 Felder hoch im Bild, Schatten bis ≈ 7 Felder nach rechts; sprites.py schneidet zu
rig.camera(13, 12, shift=0.8, shift_x=1.5)
catcher = rig.shadow_catcher()
# Je Richtung neu bauen, mit eigenem seed: die Kabel liegen dann in jeder Richtung etwas anders. Ausleger in Ost/West
# verdrehen (wie Vanilla) ginge über ARM_YAW = {"east": 10.0, "west": 10.0} – Marcel wollte ihn gerade (24.10.2026).
ARM_YAW = {}
# Modell so verschieben, dass der Mast mittig im Auswahlrahmen der Haltestelle steht (Marcel, 24.10.2026). Renders
# von davor bekommen dieselbe Verschiebung über sprites.py --versatz -0.55 -0.5.
OFFSET = (-0.55, -0.5)
os.makedirs(out, exist_ok=True)
for d in directions:
    old = bpy.data.objects.get("Drehpunkt")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    col = utl_stop_model.build(seed=rig.DIRECTIONS.index(d), distributor="--ohne-verteiler" not in a,
                               arm_yaw=ARM_YAW.get(d, 0.0))
    for o in col.objects:
        if o.parent is None:
            o.location = (o.location[0] + OFFSET[0], o.location[1] + OFFSET[1], o.location[2])
    meshes = [o for o in col.objects if o.type == "MESH"]
    root = rig.pivot(list(col.objects))
    root.rotation_euler = (0, 0, -rig.DIRECTIONS.index(d) * math.pi / 2)
    bpy.context.view_layer.update()
    with open(os.path.join(out, f"wires_{d}.json"), "w") as f:
        json.dump(rig.terminals(col), f)
    print("[STOP]", d, len(meshes), "Teile")
    if "--ohne-render" not in a:
        rig.render(out, root, meshes, catcher, samples=samples, directions=(d,), passes=passes)
if "--blend" in a:  # Stand der zuletzt gebauten Richtung als Blender-Datei sichern (z. B. für docs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a[a.index("--blend") + 1]), compress=True)
