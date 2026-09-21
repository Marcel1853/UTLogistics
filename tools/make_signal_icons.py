#!/usr/bin/env python3
"""Zeichnet die eigenen Signal-Symbole von UTL (64 × 64, durchsichtiger Hintergrund).

Aufruf: python3 tools/make_signal_icons.py
Erzeugt graphics/icons/signals/*.png. Alles selbst gezeichnet – keine Grafik aus dem Spiel.
Aufbau: oben das Fahrzeug (Lok in UTL-Blau, Wagen grau), unten eine große Beschriftung.
"""
from PIL import Image, ImageDraw, ImageFont

SIZE = 64
BLUE = (110, 180, 245, 255)   # Lok
GREY = (175, 182, 194, 255)   # Wagen
DARK = (16, 20, 28, 255)
WHITE = (246, 249, 253, 255)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def vehicle(draw, color, cab):
    """Fahrzeug von der Seite im oberen Drittel."""
    draw.rounded_rectangle([8, 12, 56, 30], radius=5, fill=color, outline=DARK, width=3)
    if cab:
        draw.rounded_rectangle([11, 4, 28, 14], radius=3, fill=color, outline=DARK, width=3)
        draw.rectangle([46, 17, 53, 25], fill=DARK)          # Front
    else:
        for x in (20, 32, 44):
            draw.line([x, 15, x, 27], fill=DARK, width=2)    # Bretter
    for x in (18, 32, 46):
        draw.ellipse([x - 4, 28, x + 4, 36], fill=DARK)


def text_label(draw, text, size):
    font = ImageFont.truetype(FONT, size)
    box = draw.textbbox((0, 0), text, font=font)
    x = (SIZE - (box[2] - box[0])) // 2 - box[0]
    y = 62 - (box[3] - box[1]) - box[1]
    for dx in (-2, 0, 2):
        for dy in (-2, 0, 2):
            if dx or dy:
                draw.text((x + dx, y + dy), text, font=font, fill=DARK)
    draw.text((x, y), text, font=font, fill=WHITE)


def arrow_label(draw):
    """Doppelpfeil als Zeichen für die Länge – ein Schriftzeichen wird zu klein."""
    y = 52
    draw.line([10, y, 54, y], fill=DARK, width=9)
    draw.polygon([(4, y), (18, y - 11), (18, y + 11)], fill=DARK)
    draw.polygon([(60, y), (46, y - 11), (46, y + 11)], fill=DARK)
    draw.line([12, y, 52, y], fill=WHITE, width=4)
    draw.polygon([(7, y), (18, y - 8), (18, y + 8)], fill=WHITE)
    draw.polygon([(57, y), (46, y - 8), (46, y + 8)], fill=WHITE)


def icon(name, color, cab, text=None, size=30):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    vehicle(draw, color, cab)
    if text:
        text_label(draw, text, size)
    else:
        arrow_label(draw)
    image.save("graphics/icons/signals/%s.png" % name)
    print("graphics/icons/signals/%s.png" % name)


icon("train-id", BLUE, True, "ID", 30)
icon("train-length", BLUE, True, None)
icon("train-locos", BLUE, True, "L", 32)
icon("train-wagons", GREY, False, "W", 32)
