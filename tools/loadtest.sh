#!/usr/bin/env bash
# Lasttest: baut ein großes Netz (5 Depots × 40 Züge, 80 Stationen …) und misst headless die
# Zeit pro Tick (gesamt, Script = UTL, Züge, Zug-Pfadsuche). Eigener Datenordner.
# Aufruf: tools/loadtest.sh [ticks]   (Standard 36000 = 10 Minuten Spielzeit)
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
TICKS="${1:-36000}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/mods" "$WORK/data"
ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
ln -s "$MOD_DIR/tools/loadtest/utl-loadtest_0.0.1" "$WORK/mods/utl-loadtest_0.0.1"
for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$dep" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"

echo "Baue Netz …"
if ! "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/load.zip" > "$WORK/create.txt" 2>&1; then
  grep -A8 "Error" "$WORK/create.txt" | head -20
  exit 1
fi
grep -o "\[LOAD\].*" "$WORK/data/factorio-current.log" || true
echo "Messe $TICKS Ticks …"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/load.zip" \
  --benchmark-ticks "$TICKS" --benchmark-verbose all \
  > "$WORK/timings.txt"
cp "$WORK/timings.txt" /tmp/claude-1000/last-timings.txt 2>/dev/null || true
grep -o "\[LOAD\].*" "$WORK/data/factorio-current.log" || true
if grep -qE "Error" "$WORK/data/factorio-current.log"; then grep -E -A5 "Error" "$WORK/data/factorio-current.log" | head -20; exit 1; fi

python3 - "$WORK/timings.txt" <<'PY'
import sys, statistics
rows = []
header = None
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith("tick,"):
        header = line.split(",")
    elif header and line.startswith("t") and "," in line:
        parts = line.split(",")
        rows.append({h: parts[i] for i, h in enumerate(header) if i < len(parts)})
def col(name):
    return [int(r[name]) / 1e6 for r in rows if r.get(name, "").isdigit()]  # ns → ms
warm = 600
print(f"\nTicks gemessen: {len(rows)} (erste {warm} ausgelassen)")
print(f"{'Bereich':<18}{'Schnitt':>10}{'Median':>10}{'99 %':>10}{'Max':>10}   (ms pro Tick)")
for name, label in (("wholeUpdate", "Gesamt"), ("scriptUpdate", "Script (UTL)"), ("trains", "Züge"), ("trainPathFinder", "Zug-Pfadsuche")):
    v = col(name)[warm:]
    if not v: continue
    s = sorted(v)
    print(f"{label:<18}{statistics.mean(v):>10.3f}{statistics.median(v):>10.3f}{s[int(len(s)*0.99)]:>10.3f}{s[-1]:>10.3f}")
v = col("wholeUpdate")[warm:]
print(f"\nTicks über 16,67 ms (unter 60 UPS): {sum(1 for x in v if x > 16.67)}")
s = col("scriptUpdate")
top = sorted(range(len(s)), key=lambda i: -s[i])[:5]
print("Größte Script-Spitzen (Tick: ms):", ", ".join(f"{rows[i]['tick']}: {s[i]:.2f}" for i in top))
PY
