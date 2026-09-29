#!/usr/bin/env bash
# Schiffstest: UTL mit Cargo Ships headless (eigener Datenordner). Braucht cargo-ships,
# cargo-ships-graphics und Robot256Lib als Zip im normalen Mod-Ordner – sie werden nur verlinkt,
# nie verändert.
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="$(mktemp -d)"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/mods" "$WORK/data"
ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
ln -s "$MOD_DIR/tools/shiptest/utl-shiptest_0.0.1" "$WORK/mods/utl-shiptest_0.0.1"
for pattern in flib_ cargo-ships_ cargo-ships-graphics_ Robot256Lib_; do
  dep="$(ls "$MOD_DIR"/../${pattern}*.zip 2>/dev/null | sort -V | tail -1)"
  if [ -z "$dep" ]; then echo "fehlt im Mod-Ordner: ${pattern}*.zip"; exit 1; fi
  ln -s "$dep" "$WORK/mods/$(basename "$dep")"
done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"

"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/test.zip" > /dev/null
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/test.zip" --benchmark-ticks 36100 \
  | grep -E "avg:|Error" || true

grep -o "\[SHIPTEST\].*" "$WORK/data/factorio-current.log" | sort -u
grep -A6 "Error while" "$WORK/data/factorio-current.log" | head -8 || true
if grep -q "\[SHIPTEST\] FAIL\|Error" "$WORK/data/factorio-current.log"; then exit 1; fi
