# Macht aus den Renders von rig.py fertige Factorio-Bilder (normales Python mit Pillow, ohne Blender):
#   python3 tools/grafik/sprites.py <render_ordner> <ziel_ordner> <name> [--tint RRGGBB]
# Je Richtung: <name>-<richtung>.png, -mask.png, -shadow.png (untere Ebene, gemeinsam zugeschnitten) und – falls
# der Durchgang „top“ gerendert ist – -top.png, -top-mask.png (obere Ebene: nur Ausleger und Lampen, das Spiel
# zeichnet sie über Züge). Dazu <name>.lua mit animations / top_animations (Animation4Way wie bei der
# Vanilla-Haltestelle) und vorschau.png (alle Richtungen auf Boden, Maske mit --tint eingefärbt).
#
# Farbmaske nach der Vanilla-Regel (Friday Facts #218): Was die Stationsfarbe bekommt, ist im Bild neutral grau.
# Die Maske enthält dort die halbe Helligkeit dieses Graus; das Spiel legt die Farbe mit halber Deckkraft darüber
# (Bild × 0,5 + Maske × Farbe). Bei weißer Farbe bleibt das Grau also unverändert, jede andere Farbe tönt es –
# die Stationsfarbe bleibt im Spiel wie gewohnt frei wählbar (apply_runtime_tint).
import json
import os
import sys

from PIL import Image, ImageChops, ImageFilter

DIRECTIONS = ("north", "east", "south", "west")
TILE_PX = 64
SHADOW_FLOOR = 14  # schwächere Schatten-Deckkraft (von 255) gilt als Rauschen


def load(render_dir, kind, direction, framing, source=None):
    """Render laden, Höhe entzerren (Boden wieder quadratisch) und auf 64 px je Feld verkleinern.
    source: anderer Durchgang als Datei, der wie kind behandelt wird (z. B. „top“ als Abdeckung wie „mask“)."""
    im = Image.open(os.path.join(render_dir, f"{source or kind}_{direction}.png")).convert("RGBA")
    size = (round(framing["width"] * TILE_PX), round(framing["height"] * TILE_PX))
    im = im.resize(size, Image.LANCZOS)  # Pillow rechnet RGBA mit vormultipliziertem Alpha
    if kind == "color":
        # Factorio-Grafiken sind knackig scharf: Kanten nach dem Verkleinern leicht nachschärfen
        im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
    if kind == "shadow":
        # Factorio färbt Schatten selbst: nur die Deckkraft zählt; Grundrauschen des Himmelslichts weg
        black = Image.new("RGBA", im.size, (0, 0, 0, 0))
        black.putalpha(im.getchannel("A").point(lambda a: 0 if a < SHADOW_FLOOR else a))
        im = black
    elif kind == "mask":
        # Render-Maske zeigt nur, wo die Farbe hinkommt (Abdeckung); Helligkeit setzt tint_mask()
        cover = ImageChops.multiply(im.convert("L"), im.getchannel("A"))
        im = Image.merge("RGBA", (cover, cover, cover, cover))
    return im


def tint_mask(color, cover):
    """Maske nach Friday Facts #218: halbe Helligkeit des grauen Bilds, nur wo die Farbe hinkommt."""
    cover = cover.getchannel("A")
    half = color.convert("L").point(lambda v: v // 2)
    grey = ImageChops.multiply(half, cover)
    return Image.merge("RGBA", (grey, grey, grey, cover))


def bbox(images):
    boxes = [im.getchannel("A").point(lambda a: 255 if a > 2 else 0).getbbox() for im in images]
    boxes = [b for b in boxes if b]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def lua_layer(path, im, shift, extra):
    fields = [f'filename = "{path}"', f"width = {im.width}", f"height = {im.height}",
              f"shift = {{ {shift[0]:.4f}, {shift[1]:.4f} }}", "scale = 0.5"] + extra
    return "        { " + ", ".join(fields) + " },"


def masked(im, cover):
    """Bild nur dort, wo cover deckt (Deckkraft multipliziert)."""
    out = im.copy()
    out.putalpha(ImageChops.multiply(im.getchannel("A"), cover.getchannel("A")))
    return out


def write_layers(out_dir, name, d, layers, origin, lua):
    """Ebenen gemeinsam zuschneiden, speichern und als Lua-Zeilen anhängen."""
    box = bbox([im for _, im, _ in layers])
    for suffix, im, extra in layers:
        im = im.crop(box)
        file = f"{name}-{d}{suffix}.png"
        im.save(os.path.join(out_dir, file), optimize=True)
        # shift in Feldern: Bildmitte relativ zum Ursprung (bei scale 0.5 sind 64 px ein Feld)
        shift = (((box[0] + box[2]) / 2 - origin[0]) / TILE_PX, ((box[1] + box[3]) / 2 - origin[1]) / TILE_PX)
        lua.append(lua_layer(f"__UTLogistics__/graphics/entity/{name}/{file}", im, shift, extra))


def main(render_dir, out_dir, name, tint):
    os.makedirs(out_dir, exist_ok=True)
    bottom, top = [], []
    previews = []
    for d in DIRECTIONS:
        if not os.path.exists(os.path.join(render_dir, f"color_{d}.png")):
            continue
        with open(os.path.join(render_dir, f"framing_{d}.json")) as f:
            framing = json.load(f)
        # Ursprung (Boden-Mitte des Modells) im verkleinerten Bild
        origin = (framing["width"] * TILE_PX / 2, (framing["height"] / 2 + framing["shift"]) * TILE_PX)
        ims = {k: load(render_dir, k, d, framing) for k in ("color", "mask", "shadow")}
        ims["mask"] = tint_mask(ims["color"], ims["mask"])
        bottom.append(f"    {d} = {{ layers = {{")
        write_layers(out_dir, name, d, [("", ims["color"], []), ("-mask", ims["mask"], ["apply_runtime_tint = true"]),
                                        ("-shadow", ims["shadow"], ["draw_as_shadow = true"])], origin, bottom)
        bottom.append("    } },")
        if os.path.exists(os.path.join(render_dir, f"top_{d}.png")):
            cover = load(render_dir, "mask", d, framing, source="top")
            top.append(f"    {d} = {{ layers = {{")
            write_layers(out_dir, name, d, [("-top", masked(ims["color"], cover), []),
                                            ("-top-mask", masked(ims["mask"], cover), ["apply_runtime_tint = true"])],
                         origin, top)
            top.append("    } },")
        previews.append((d, ims))
    lua = ["-- Erzeugt von tools/grafik/sprites.py – nicht von Hand ändern.", "return {",
           "  animations = {"] + bottom + ["  },"]
    if top:
        lua += ["  top_animations = {"] + top + ["  },"]
    lua.append("}")
    with open(os.path.join(out_dir, f"{name}.lua"), "w") as f:
        f.write("\n".join(lua) + "\n")
    preview(previews, os.path.join(out_dir, "vorschau.png"), tint)


def preview(previews, path, tint):
    """Alle Richtungen nebeneinander auf Vanilla-ähnlichem Boden, so wie Factorio die Ebenen mischt."""
    if not previews:
        return
    w = max(ims["color"].width for _, ims in previews) + 32
    h = max(ims["color"].height for _, ims in previews) + 32
    sheet = Image.new("RGBA", (w * len(previews), h), (92, 84, 64, 255))
    colour = tuple(int(tint[i:i + 2], 16) for i in (0, 2, 4))
    for n, (_, ims) in enumerate(previews):
        tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        at = (16, 16)
        shadow = ims["shadow"].copy()
        shadow.putalpha(shadow.getchannel("A").point(lambda a: a * 0.6))
        tile.alpha_composite(shadow, at)
        tile.alpha_composite(ims["color"], at)
        # wie im Spiel: unter der Maske Bild × (1 − 0,5 × Abdeckung) + Maske × Farbe
        mask = ims["mask"]
        region = tile.crop((at[0], at[1], at[0] + mask.width, at[1] + mask.height))
        keep = mask.getchannel("A").point(lambda a: 255 - a // 2)
        grey = mask.getchannel("R")
        channels = [ImageChops.add(ImageChops.multiply(ch, keep), grey.point(lambda v, c=c: v * c // 255))
                    for ch, c in zip(region.convert("RGB").split(), colour)]
        mixed = Image.merge("RGB", channels).convert("RGBA")
        mixed.putalpha(region.getchannel("A"))
        tile.paste(mixed, at)
        sheet.alpha_composite(tile, (n * w, 0))
    sheet.save(path)


if __name__ == "__main__":
    a = sys.argv[1:]
    tint = a[a.index("--tint") + 1] if "--tint" in a else "4a90d9"
    a = [x for i, x in enumerate(a) if x != "--tint" and (i == 0 or a[i - 1] != "--tint")]
    if len(a) != 3:
        sys.exit(__doc__ or "python3 sprites.py <render_ordner> <ziel_ordner> <name> [--tint RRGGBB]")
    main(*a, tint)
