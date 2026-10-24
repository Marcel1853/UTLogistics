# Vorschaubild für README/Wiki aus den fertigen Spielbildern (Pillow, ohne Blender):
#   python3 tools/grafik/readme_preview.py <ausgabe.png> [--tint RRGGBB]
# Haltestelle in allen vier Richtungen, davor Auftrags- und Depot-Ausgabe – jede Ebene an ihrem shift aus
# prototypes/sprites/*.lua, so wie das Spiel sie zeichnet (Schatten, Bild, Maske in der Stationsfarbe, obere Ebene).
import os
import re
import sys

from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILE = 64  # Bildpunkte je Feld in den Spielbildern (scale 0.5)
GROUND = (74, 70, 58, 255)
LAYER = re.compile(r'filename = "__UTLogistics__/([^"]+)", width = (\d+), height = (\d+), '
                   r'shift = \{ ([-\d.]+), ([-\d.]+) \}, scale = 0\.5([^}]*)\}')


def layers(name, direction, table="animations"):
    """Ebenen einer Richtung aus prototypes/sprites/<name>.lua: (Datei, shift, Art)."""
    lua = open(os.path.join(ROOT, "prototypes", "sprites", name + ".lua")).read()
    part = lua.split(f"  {table} = {{", 1)
    if len(part) < 2:
        return []
    block = part[1].split(f"    {direction} = {{ layers = {{", 1)[1].split("} },", 1)[0]
    out = []
    for path, _, _, sx, sy, extra in LAYER.findall(block):
        kind = "shadow" if "draw_as_shadow" in extra else "mask" if "apply_runtime_tint" in extra else "color"
        out.append((os.path.join(ROOT, path), (float(sx), float(sy)), kind))
    return out


def draw(canvas, at, name, direction, tint, order):
    """Ebenen einer Art (order) an Position at (Bildpunkte der Entity-Mitte) zeichnen."""
    for table in ("animations", "top_animations"):
        for path, (sx, sy), kind in layers(name, direction, table):
            if kind not in order:
                continue
            im = Image.open(path).convert("RGBA")
            x = round(at[0] + sx * TILE - im.width / 2)
            y = round(at[1] + sy * TILE - im.height / 2)
            if kind == "shadow":
                im.putalpha(im.getchannel("A").point(lambda a: a * 0.55))
                canvas.alpha_composite(im, (x, y))
            elif kind == "mask":
                # wie im Spiel (Friday Facts #218): darunter Bild × (1 − 0,5 × Abdeckung) + Maske × Farbe
                region = canvas.crop((x, y, x + im.width, y + im.height))
                keep = im.getchannel("A").point(lambda a: 255 - a // 2)
                grey = im.getchannel("R")
                channels = [ImageChops.add(ImageChops.multiply(ch, keep), grey.point(lambda v, c=c: v * c // 255))
                            for ch, c in zip(region.convert("RGB").split(), tint)]
                mixed = Image.merge("RGB", channels).convert("RGBA")
                mixed.putalpha(region.getchannel("A"))
                canvas.paste(mixed, (x, y))
            else:
                canvas.alpha_composite(im, (x, y))


def main(out, tint):
    colour = tuple(int(tint[i:i + 2], 16) for i in (0, 2, 4))
    # große Fläche, am Ende auf den Inhalt zuschneiden
    step, width, height = 7 * TILE, 40 * TILE, 20 * TILE
    canvas = Image.new("RGBA", (width, height), GROUND)
    stops = [((6 * TILE + i * step), 10 * TILE) for i in range(4)]
    outputs = [(6 * TILE + 3 * step + 6.5 * TILE, 9 * TILE, "utl-station-output"),  # rechts neben dem Schatten von West
               (6 * TILE + 3 * step + 6.5 * TILE, 10.8 * TILE, "utl-depot-output")]
    # erst alle Schatten, dann die Körper (wie im Spiel), Masken direkt nach ihrem Bild
    for kinds in (("shadow",), ("color", "mask")):
        for (x, y), d in zip(stops, ("north", "east", "south", "west")):
            draw(canvas, (x, y), "utl-train-stop", d, colour, kinds)
        for x, y, name in outputs:
            draw(canvas, (x, y), name, "north", colour, kinds)
    box = ImageChops.difference(canvas.convert("RGB"), Image.new("RGB", canvas.size, GROUND[:3])).point(
        lambda v: 255 if v > 6 else 0).getbbox()
    pad = TILE // 2
    canvas = canvas.crop((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad))
    canvas = canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS)  # kompakt: 32 Bildpunkte je Feld
    canvas.convert("RGB").save(out, optimize=True)


if __name__ == "__main__":
    a = sys.argv[1:]
    tint = a[a.index("--tint") + 1] if "--tint" in a else "4a90d9"
    main(a[0], tint)
