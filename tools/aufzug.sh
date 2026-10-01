#!/usr/bin/env bash
# Szenario „UTL-Aufzug“ spielen: Space Exploration mit Weltraumaufzug, grafisch (Steam fragt nach
# einer Freigabe). Eigener Mod- und Datenordner – die normale Mod-Liste (mit Space Age) bleibt, wie
# sie ist. SE und seine Abhängigkeiten werden aus ~/.factorio/mods nur verlinkt, nie verändert.
# Aufruf: tools/aufzug.sh [de|en] [test|shots]
#   shots: Wiki-Bilder aufnehmen (script-output/utl-aufzug), danach Factorio beenden.
#   test: nach 10 Spielminuten (oder 20 min Wartezeit) Factorio beenden und die [AUF]-Zeilen zeigen.
set -euo pipefail
LANG_CODE="${1:-de}"; MODE="${2:-}"
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-aufzug}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
rm -rf "$WORK/mods/utl-testtools_0.0.1" && cp -r "$(dirname "$0")/testtools/utl-testtools_0.0.1" "$WORK/mods/"
DEPS="flib space-exploration space-exploration-graphics space-exploration-graphics-2 space-exploration-graphics-3
  space-exploration-graphics-4 space-exploration-graphics-5 space-exploration-menu-simulations
  space-exploration-postprocess aai-containers aai-industry aai-signal-transmission alien-biomes
  alien-biomes-graphics informatron jetpack robot_attrition shield-projector"
for name in $DEPS; do
  dep="$(ls "$MOD_DIR"/../${name}_[0-9]*.zip 2>/dev/null | sort -V | tail -1)"
  if [ -z "$dep" ]; then echo "fehlt im Mod-Ordner: ${name}_*.zip"; exit 1; fi
  ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"
done
{
  printf '{"mods":[{"name":"base","enabled":true},{"name":"UTLogistics","enabled":true},{"name":"utl-testtools","enabled":true}'
  for name in $DEPS; do printf ',{"name":"%s","enabled":true}' "$name"; done
  for name in space-age quality elevated-rails recycler; do printf ',{"name":"%s","enabled":false}' "$name"; done
  printf ']}\n'
} > "$WORK/mods/mod-list.json"
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=%s\n' "$WORK" "$LANG_CODE" > "$WORK/config.ini"
# Bildermodus: Szenario nimmt Wiki-Bilder auf (script-output/utl-aufzug), danach „[AUF] Bilder fertig“
[ "$MODE" = "shots" ] && echo "return true" > "$WORK/mods/utl-testtools_0.0.1/scenarios/UTL-Aufzug/shots.lua"
rm -f "$WORK/data/factorio-current.log"
# Im Hintergrund starten: je nach Steam läuft das Spiel direkt oder Steam startet es nach der Freigabe neu
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "utl-testtools/UTL-Aufzug" > "$WORK/run.log" 2>&1 &
if [ "$MODE" != "test" ] && [ "$MODE" != "shots" ]; then
  echo "Factorio startet (Steam fragt evtl. nach einer Freigabe). Log: $WORK/data/factorio-current.log"
  exit 0
fi
for _ in $(seq 1 240); do # bis 40 min: der Neustart über Steam kann dauern
  if [ "$MODE" = "shots" ]; then
    grep -q "AUF\] Bilder fertig\|AUF\] FEHLER\|Error while" "$WORK/data/factorio-current.log" 2>/dev/null && break
  else
    grep -q "AUF\] Stand nach 6[0-9][0-9] s\|AUF\] FEHLER\|Error while" "$WORK/data/factorio-current.log" 2>/dev/null && break
  fi
  sleep 10
done
grep -oE "\[AUF\] .*" "$WORK/data/factorio-current.log" || true
grep -A6 "Error while" "$WORK/data/factorio-current.log" | head -8 || true
PID=$(pgrep -f "x64_/factorio -c $WORK/config.ini" || pgrep -f "factorio -c $WORK/config.ini" || true)
[ -n "$PID" ] && kill -TERM $PID
if [ "$MODE" = "shots" ]; then
  KEEP_DIR="$MOD_DIR/docs/screenshots/aufzug/$(date +%Y-%m-%d_%H%M)-$LANG_CODE"
  mkdir -p "$KEEP_DIR" && cp -n "$WORK/data/script-output/utl-aufzug/"*.png "$KEEP_DIR/" 2>/dev/null || true
  echo "Bilder: $KEEP_DIR"
fi
exit 0
