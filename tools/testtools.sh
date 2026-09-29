#!/usr/bin/env bash
# Großer grafischer Test (öffnet ein Factorio-Fenster, Steam fragt nach einer Freigabe!).
# Aufruf: tools/testtools.sh SZENARIO [de|en]   SZENARIO: UTL-Beispiele oder UTL-Schiffe (liegt im
# Werkzeug-Mod, braucht Cargo Ships)
# Eigener Datenordner mit UTL, flib, Cargo Ships (nur verlinkt) und dem Werkzeug-Mod
# tools/testtools/utl-testtools. Ergebnis: [TT]-Zeilen im Log, Bilder in
# $WORK/data/script-output/utl-tt/, kopiert nach docs/screenshots/testtools/<datum>-<szenario>/. Am Ende wird genau das eigene Factorio beendet.
set -euo pipefail
SCENARIO="$1"; LANG_CODE="${2:-de}"
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-testtools}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
rm -rf "$WORK/mods/utl-testtools_0.0.1" && cp -r "$(dirname "$0")/testtools/utl-testtools_0.0.1" "$WORK/mods/"
for pattern in flib_ cargo-ships_ cargo-ships-graphics_ Robot256Lib_; do
  dep="$(ls "$MOD_DIR"/../${pattern}*.zip 2>/dev/null | sort -V | tail -1)"
  [ -n "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"
done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=%s\n' "$WORK" "$LANG_CODE" > "$WORK/config.ini"
rm -f "$WORK/data/factorio-current.log"
# Bilder nie löschen (Marcel: für Mod-Seite und Wiki aufheben): alte Bilder wegschieben statt leeren
if [ -d "$WORK/data/script-output/utl-tt" ]; then mv "$WORK/data/script-output/utl-tt" "$WORK/data/script-output/utl-tt-$(date +%Y%m%d-%H%M%S)"; fi
# Steam beendet diesen Start und startet das Spiel nach der Freigabe selbst neu
# UTL-Schiffe liegt im Werkzeug-Mod (nicht im veröffentlichten UTL), die übrigen im Mod selbst
OWNER=UTLogistics
[ -d "$(dirname "$0")/testtools/utl-testtools_0.0.1/scenarios/$SCENARIO" ] && OWNER=utl-testtools
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "$OWNER/$SCENARIO" > "$WORK/run.log" 2>&1 || true
for _ in $(seq 1 120); do
  grep -q "TT\] fertig" "$WORK/data/factorio-current.log" 2>/dev/null && break
  sleep 10
done
sleep 5
grep -oE "\[TT\] .*" "$WORK/data/factorio-current.log" | grep -v " bild " || true
grep -A6 "Error while" "$WORK/data/factorio-current.log" | head -8 || true
PID=$(pgrep -f "x64_/factorio -c $WORK/config.ini" || pgrep -f "factorio -c $WORK/config.ini" || true)
[ -n "$PID" ] && kill -TERM $PID
# Kopie in den Mod-Ordner (docs/ wird nicht gepusht), je Lauf ein eigener Ordner
KEEP_DIR="$MOD_DIR/docs/screenshots/testtools/$(date +%Y-%m-%d_%H%M)-$SCENARIO"
mkdir -p "$KEEP_DIR" && cp -n "$WORK/data/script-output/utl-tt/"*.png "$KEEP_DIR/" 2>/dev/null || true
echo "Bilder: $KEEP_DIR"
