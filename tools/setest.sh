#!/usr/bin/env bash
# Aufzug-Test: UTL-Lieferung über einen Weltraumaufzug, headless mit einer Nachbildung der
# Space-Exploration-Schnittstelle (echtes SE baut ohne Spieler keine Aufzüge). Eigener Datenordner.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/mods" "$WORK/data"
ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
ln -s "$MOD_DIR/tools/setest/utl-setest_0.0.1" "$WORK/mods/utl-setest_0.0.1"
for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$dep" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"

"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/test.zip" > /dev/null
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/test.zip" --benchmark-ticks 80000 \
  | grep -E "avg:|Error" || true

grep -o "\[SETEST\].*" "$WORK/data/factorio-current.log"
grep -A6 "Error while" "$WORK/data/factorio-current.log" | head -8 || true
if grep -q "\[SETEST\] FAIL\|Error" "$WORK/data/factorio-current.log"; then exit 1; fi
if ! grep -q "\[SETEST\] ENDE" "$WORK/data/factorio-current.log"; then echo "Test nicht fertig geworden"; exit 1; fi
