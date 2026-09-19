#!/usr/bin/env bash
# Startet Factorio headless mit nur UTL + Testmod und zeigt die Ergebnisse.
# Läuft auch, während das Spiel offen ist (eigener Datenordner).
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/mods" "$WORK/data"
ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
ln -s "$MOD_DIR/tools/selftest/utl-selftest_0.0.1" "$WORK/mods/utl-selftest_0.0.1"
# Abhängigkeiten aus dem normalen Mod-Ordner
for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$dep" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"

"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/test.zip" > /dev/null
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/test.zip" --benchmark-ticks 72000 \
  | grep -E "avg:|Error" || true

grep -o "\[SELFTEST\].*" "$WORK/data/factorio-current.log" | sort -u
if grep -q "\[SELFTEST\] FAIL\|Error" "$WORK/data/factorio-current.log"; then exit 1; fi
