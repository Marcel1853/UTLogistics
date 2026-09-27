#!/usr/bin/env bash
# Baut das Gleisnetz des Szenarios „UTL-Lasttest“ headless und legt es als Karte
# (scenarios/UTL-Lasttest/blueprint.zip) ins Szenario. Nötig, wenn sich Gitter, Depot-Blöcke oder
# Bahnhofsplätze in lasttest.lua/builder.lua/places.lua ändern – Stationen und Züge setzt das
# Szenario beim Start selbst. Eigener Datenordner, der Mod-Ordner bleibt unberührt.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/mods" "$WORK/data/saves"
ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
ln -s "$MOD_DIR/tools/lasttest-map/utl-lasttest-map_0.0.1" "$WORK/mods/utl-lasttest-map_0.0.1"
for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$dep" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"

echo "Baue Gleisnetz …"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/data/saves/lasttest-map.zip" > "$WORK/create.txt" 2>&1 \
  || { grep -A8 "Error" "$WORK/create.txt" | head -20; exit 1; }
grep -o "\[MAP\].*" "$WORK/data/factorio-current.log"
echo "Wandle in Szenario um …"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --map2scenario lasttest-map > "$WORK/convert.txt" 2>&1 \
  || { tail -20 "$WORK/convert.txt"; exit 1; }
cp "$WORK/data/scenarios/lasttest-map/blueprint.zip" "$MOD_DIR/scenarios/UTL-Lasttest/blueprint.zip"
ls -la "$MOD_DIR/scenarios/UTL-Lasttest/blueprint.zip"
