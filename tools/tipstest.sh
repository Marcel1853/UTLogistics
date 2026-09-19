#!/usr/bin/env bash
# Prüft die Tipps-&-Tricks-Szenen headless: je Szene eine Welt, Szenen-Code ausführen, 3 Minuten laufen.
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
for scene in ${SCENES:-basic stop_window combinator roles requests values depots fuel cleanup copy manager}; do
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/mods" "$WORK/data"
  ln -s "$MOD_DIR" "$WORK/mods/$(basename "$MOD_DIR")"
  cp -r "$MOD_DIR/tools/tipstest/utl-tipstest_0.0.1" "$WORK/mods/"
  echo "return \"$scene\"" > "$WORK/mods/utl-tipstest_0.0.1/scene.lua"
  for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$dep" "$WORK/mods/$(basename "$dep")"; done
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$WORK" > "$WORK/config.ini"
  "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --create "$WORK/t.zip" > /dev/null
  "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --benchmark "$WORK/t.zip" --benchmark-ticks ${TICKS:-10900} > /dev/null || true
  { grep -o "\[TIPS\] MANIFEST.*" "$WORK/data/factorio-current.log" || true; grep -o "\[TIPS\] .* erstes .*" "$WORK/data/factorio-current.log" || true; grep -o "\[TIPS\].*tick.*\|Error.*" "$WORK/data/factorio-current.log" | tail -1; }
  grep -A6 "Error while" "$WORK/data/factorio-current.log" | head -8 || true
  rm -rf "$WORK"
done
