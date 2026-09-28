#!/usr/bin/env bash
# Wiki-Bilder MIT Grafik aufnehmen (öffnet ein Factorio-Fenster, Steam fragt nach einer Freigabe!).
# Aufruf: tools/screenshots.sh SZENARIO [de|en] [MOD_ORDNER]
#   SZENARIO z. B. UTL-Beispiele; MOD_ORDNER Standard: dieser Mod (für ältere Versionen einen
#   git worktree angeben, z. B. von main).
# Eigener Datenordner, nichts wird gelöscht außer dem eigenen Log. Die Bilder landen in
# $WORK/data/script-output/utl/. Am Ende wird genau das eigene Factorio (eigene config.ini) beendet.
set -euo pipefail
SCENARIO="$1"; LANG_CODE="${2:-de}"
MOD_DIR="$(cd "${3:-$(dirname "$0")/..}" && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-shots-$LANG_CODE}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
rm -rf "$WORK/mods/utl-shots_0.0.1" && cp -r "$(dirname "$0")/screenshots/utl-shots_0.0.1" "$WORK/mods/"
for dep in "$MOD_DIR"/../flib_*.zip; do [ -e "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=%s\n' "$WORK" "$LANG_CODE" > "$WORK/config.ini"
rm -f "$WORK/data/factorio-current.log"
# Steam beendet diesen Start und startet das Spiel nach der Freigabe selbst neu
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "UTLogistics/$SCENARIO" > "$WORK/run.log" 2>&1 || true
for _ in $(seq 1 90); do
  grep -q "SHOTS\] fertig" "$WORK/data/factorio-current.log" 2>/dev/null && break
  sleep 10
done
grep -E "SHOTS\] (utl-|nauvis|fertig|Fehler)" "$WORK/data/factorio-current.log" || true
PID=$(pgrep -f "x64_/factorio -c $WORK/config.ini" || true)
[ -n "$PID" ] && kill -TERM $PID
echo "Bilder: $WORK/data/script-output/utl/"
