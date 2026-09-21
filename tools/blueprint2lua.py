#!/usr/bin/env python3
"""Blaupause (Textdatei) in eine Lua-Tabelle für das Szenario umwandeln.

Aufruf: tools/blueprint2lua.py <blaupause.txt> <ziel.lua>
(so entstand scenarios/UTL-Beispiele/rundkurs.lua aus docs/blaupausen/rundkurs_scenarios.txt)
Positionen bleiben so, wie sie in der Blaupause stehen (Blockecke = 0/0).
Reihenfolge: erst Stützen und Rampen, dann die Hochgleise, danach alles Übrige –
Hochgleise brauchen ihre Stütze, bevor sie gesetzt werden können.
"""
import base64, json, sys, zlib

CODE = {
    "straight-rail": "S", "curved-rail-a": "A", "curved-rail-b": "B", "half-diagonal-rail": "H",
    "rail-signal": "G", "rail-chain-signal": "K", "big-electric-pole": "P", "radar": "R",
    "rail-support": "U", "rail-ramp": "M", "elevated-straight-rail": "E",
    "elevated-curved-rail-a": "EA", "elevated-curved-rail-b": "EB",
    "elevated-half-diagonal-rail": "EH", "utl-train-stop": "T",
    "train-stop": "V", "utl-station-combinator": "C",
}
ORDER = {"U": 0, "M": 1, "E": 2, "EA": 2, "EB": 2, "EH": 2}


def number(value):
    text = ("%g" % value)
    return "0" if text == "-0" else text


def main(src, dst):
    data = json.loads(zlib.decompress(base64.b64decode(open(src).read().strip()[1:])))
    bp = data["blueprint"]
    rows = []
    for e in bp["entities"]:
        code = CODE.get(e["name"])
        if code is None:
            raise SystemExit("unbekannt: " + e["name"])
        p = e["position"]
        layer = 1 if e.get("rail_layer") == "elevated" else 0
        rows.append((ORDER.get(code, 3), code, p["x"], p["y"], e.get("direction", 0), layer))
    rows.sort(key=lambda r: (r[0], r[3], r[2]))
    out = ['-- %s aus Marcels Blaupause (%s).' % (bp.get("label", "Blaupause"), src),
           '-- Positionen relativ zur Blockecke; Stützen und Rampen zuerst, dann die Hochgleise.',
           '-- { Name, x, y, Richtung, 1 = gehört zum Hochgleis }', 'return {']
    line = []
    for _, code, x, y, d, layer in rows:
        line.append('{"%s",%s,%s,%d%s}' % (code, number(x), number(y), d, ",1" if layer else ""))
        if len(line) == 8:
            out.append("  " + ", ".join(line) + ",")
            line = []
    if line:
        out.append("  " + ", ".join(line) + ",")
    out.append("}")
    open(dst, "w").write("\n".join(out) + "\n")
    print("%d Objekte -> %s" % (len(rows), dst))


main(sys.argv[1], sys.argv[2])
