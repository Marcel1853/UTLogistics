#!/usr/bin/env python3
"""Grundbilder der UTL-Signale im Stil der Vanilla-Signale (Factorio 2.x):
flache hellgraue Fläche (#e0e0e0), dicke fast schwarze Kontur, Löcher dunkel ausgespart,
Mipmaps 64 + 32 + 16 + 8 nebeneinander (120 × 64, `mipmap_count = 4` in Lua).

Aufruf: python3 tools/grafik/signals.py [--sheet vorschau.png]
Schreibt graphics/icons/signals/flat/<name>.png (Stil „Flach“, Start-Einstellung utl-signal-style). Alles selbst gezeichnet (Formen, keine Spielgrafik).
Das Zusatzzeichen (≥, Stern, Schloss …) kommt in Lua als Vanilla-Signal per Verweis dazu.
Die Grundbilder lassen unten rechts Platz dafür.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4                 # Überabtastung: gezeichnet wird auf 256 × 256
N = 64 * S
FILL = (224, 224, 224, 255)
LINE = (26, 26, 26, 255)
OUTLINE = 5 * S       # Konturbreite wie Vanilla (≈ 5 px bei 64)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "graphics", "icons", "signals", "flat")


def canvas():
    return Image.new("L", (N, N), 0)


def p(*pts):
    return [(x * S, y * S) for x, y in pts]


def finish(shape, holes=None):
    """Form (weiß auf schwarz) → Vanilla-Stil: Kontur durch Dehnen, Löcher dunkel."""
    grow = shape.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1))
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (N, N), LINE), (0, 0), grow)
    inner = shape if holes is None else ImageChops.subtract(shape, holes)
    img.paste(Image.new("RGBA", (N, N), FILL), (0, 0), inner)
    return img


def mipmaps(img):
    sheet = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    x = 0
    for size in (64, 32, 16, 8):
        sheet.alpha_composite(img.resize((size, size), Image.LANCZOS), (x, 0))
        x += size
    return sheet


# ---------- Grundbilder (Koordinaten im 64er-Raster, Platz unten rechts frei lassen) ----------
def loco():
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.rounded_rectangle(p((6, 22), (52, 40)), radius=3 * S, fill=255)       # Kessel
    d.rounded_rectangle(p((8, 10), (24, 24)), radius=2 * S, fill=255)       # Führerhaus
    d.polygon(p((52, 24), (58, 30), (58, 40), (52, 40)), fill=255)          # Schnauze
    d.rectangle(p((4, 40), (56, 44)), fill=255)                             # Rahmen
    for x in (14, 30, 46):
        d.ellipse(p((x - 6, 40), (x + 6, 52)), fill=255)                    # Räder
        h.ellipse(p((x - 2, 44), (x + 2, 48)), fill=255)
    h.rectangle(p((12, 13), (20, 19)), fill=255)                            # Fenster
    return finish(sh, ho)


def wagon(fluid=False):
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    if fluid:
        d.rounded_rectangle(p((6, 16), (54, 40)), radius=12 * S, fill=255)  # Kessel
        h.line(p((14, 28), (46, 28)), fill=255, width=3 * S)
    else:
        d.rectangle(p((6, 14), (54, 40)), fill=255)                         # Kasten
        for x in (18, 30, 42):
            h.line(p((x, 18), (x, 36)), fill=255, width=2 * S)              # Bretter
    d.rectangle(p((4, 40), (56, 44)), fill=255)
    for x in (16, 44):
        d.ellipse(p((x - 6, 40), (x + 6, 52)), fill=255)
        h.ellipse(p((x - 2, 44), (x + 2, 48)), fill=255)
    return finish(sh, ho)


def chest(kind):
    """Kiste mit Pfeil: „provide“ = Pfeil heraus (oben), „request“ = Pfeil hinein."""
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.rounded_rectangle(p((8, 20), (50, 54)), radius=2 * S, fill=255)
    d.rectangle(p((6, 16), (52, 24)), fill=255)                             # Deckel
    h.rectangle(p((12, 28), (46, 30)), fill=255)                            # Beschlag
    if kind == "provide":
        d.polygon(p((29, 2), (41, 13), (33, 13), (33, 16), (25, 16), (25, 13), (17, 13)), fill=255)
    else:
        d.polygon(p((25, 2), (33, 2), (33, 6), (41, 6), (29, 16), (17, 6), (25, 6)), fill=255)
    h.rectangle(p((26, 36), (32, 44)), fill=255)                            # Schloss
    return finish(sh, ho)


def stop():
    """Haltestelle: Mast mit Ausleger und Lampe."""
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.rectangle(p((34, 10), (42, 54)), fill=255)                            # Mast
    d.rectangle(p((8, 8), (44, 16)), fill=255)                              # Ausleger
    d.polygon(p((34, 16), (34, 26), (24, 16)), fill=255)                    # Strebe
    d.rounded_rectangle(p((6, 16), (18, 30)), radius=2 * S, fill=255)       # Lampe
    h.ellipse(p((9, 20), (15, 26)), fill=255)
    d.rectangle(p((28, 50), (48, 56)), fill=255)                            # Fuß
    return finish(sh, ho)


def network():
    """UTL-Netz: drei verbundene Punkte."""
    sh = canvas()
    d = ImageDraw.Draw(sh)
    pts = [(12, 44), (30, 12), (48, 44)]
    for i in range(3):
        d.line(p(pts[i], pts[(i + 1) % 3]), fill=255, width=5 * S)
    for x, y in pts:
        d.ellipse(p((x - 9, y - 9), (x + 9, y + 9)), fill=255)
    return finish(sh)


def output():
    """Ausgabe: Kasten mit Anschlüssen (Kombinator)."""
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.rounded_rectangle(p((10, 14), (48, 50)), radius=3 * S, fill=255)
    for y in (22, 32, 42):
        d.rectangle(p((4, y - 2), (10, y + 2)), fill=255)
        d.rectangle(p((48, y - 2), (54, y + 2)), fill=255)
    h.rectangle(p((16, 20), (42, 30)), fill=255)                            # Anzeige
    for x in (18, 28, 38):
        h.ellipse(p((x - 2, 38), (x + 2, 42)), fill=255)
    return finish(sh, ho)


def garage():
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.polygon(p((4, 24), (30, 6), (56, 24), (56, 30), (4, 30)), fill=255)   # Dach
    d.rectangle(p((8, 28), (52, 56)), fill=255)
    h.rectangle(p((15, 32), (45, 56)), fill=255)                            # Tor
    for y in (36, 42, 48):
        d.rectangle(p((15, y), (45, y + 2)), fill=255)
    return finish(sh, ho)


def fuel():
    sh, ho = canvas(), canvas()
    d, h = ImageDraw.Draw(sh), ImageDraw.Draw(ho)
    d.rounded_rectangle(p((10, 6), (38, 54)), radius=4 * S, fill=255)       # Säule
    d.rectangle(p((6, 50), (42, 58)), fill=255)                             # Fuß
    h.rectangle(p((15, 12), (33, 24)), fill=255)                            # Anzeige
    d.line(p((38, 16), (48, 22), (48, 42), (52, 44)), fill=255, width=4 * S)  # Schlauch
    return finish(sh, ho)


FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def mini_vehicle(d, loco_only=False):
    """Kleines Fahrzeug im oberen Drittel: Lok (oder Wagenreihe für „W“)."""
    if loco_only:
        for x in (8, 22, 36):
            d.rectangle(p((x, 8), (x + 12, 20)), fill=255)
        d.rectangle(p((6, 20), (52, 22)), fill=255)
        return
    d.rounded_rectangle(p((8, 10), (50, 22)), radius=2 * S, fill=255)
    d.rectangle(p((10, 4), (22, 12)), fill=255)
    d.polygon(p((50, 12), (56, 17), (56, 22), (50, 22)), fill=255)


def labelled(text=None, arrow=False, wagons=False):
    from PIL import ImageFont
    sh = canvas()
    d = ImageDraw.Draw(sh)
    mini_vehicle(d, loco_only=wagons)
    if arrow:
        d.line(p((10, 44), (50, 44)), fill=255, width=5 * S)
        d.polygon(p((4, 44), (16, 34), (16, 54)), fill=255)
        d.polygon(p((56, 44), (44, 34), (44, 54)), fill=255)
    else:
        font = ImageFont.truetype(FONT, 30 * S)
        box = d.textbbox((0, 0), text, font=font)
        x = (N - (box[2] - box[0])) // 2 - box[0]
        y = 60 * S - (box[3] - box[1]) - box[1]
        d.text((x, y), text, font=font, fill=255)
    return finish(sh)


ICONS = {
    "train-id": lambda: labelled("ID"),
    "train-length": lambda: labelled(arrow=True),
    "train-locos": lambda: labelled("L"),
    "train-wagons": lambda: labelled("W", wagons=True),
    "loco": loco,
    "cargo-wagon": lambda: wagon(False),
    "fluid-wagon": lambda: wagon(True),
    "provider-chest": lambda: chest("provide"),
    "requester-chest": lambda: chest("request"),
    "train-stop": stop,
    "network": network,
    "output": output,
    "depot-garage-flat": garage,
    "fuel-pump-flat": fuel,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for name, fn in ICONS.items():
        img = fn()
        mipmaps(img).save(os.path.join(OUT, name + ".png"))
        made[name] = img
    print("geschrieben:", ", ".join(made), "→", os.path.normpath(OUT))
    if "--sheet" in sys.argv:
        target = sys.argv[sys.argv.index("--sheet") + 1]
        sheet = Image.new("RGBA", (len(made) * 140, 140), (49, 48, 49, 255))
        for i, img in enumerate(made.values()):
            sheet.alpha_composite(img.resize((128, 128), Image.LANCZOS), (i * 140 + 6, 6))
        sheet.save(target)


if __name__ == "__main__":
    main()
