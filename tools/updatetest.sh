#!/usr/bin/env bash
# Update-Test: Spielstände der veröffentlichten Version (main) mit dem aktuellen Stand laden.
#   1. main als git worktree (Wegwerf-Kopie), je Szenario ein Server mit der alten Version,
#      nach ~100 s speichern.
#   2. Den Spielstand mit dem aktuellen Stand + Prüf-Mod (tools/updatetest) 3 Minuten laufen lassen:
#      keine Fehler, gleich viele Stationen, Lieferungen laufen weiter.
# Aufruf: tools/updatetest.sh [SZENARIO …]   (Standard: Beispiele, Lager, Netzverbund, Teams, Nachladen)
#   OLD_REF=origin/main tools/updatetest.sh   – alte Version aus einem anderen Stand (Standard: main)
set -uo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
SCENARIOS="${*:-UTL-Beispiele UTL-Lager UTL-Netzverbund UTL-Teams UTL-Nachladen-Demo}"
WORK="$(mktemp -d)"
cleanup() { git -C "$MOD_DIR" worktree remove --force "$WORK/old/UTLogistics" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT
mkdir -p "$WORK/old" "$WORK/new/mods" "$WORK/new/data"
git -C "$MOD_DIR" worktree add -q --detach "$WORK/old/UTLogistics" "${OLD_REF:-main}"
echo "alte Version: $(grep -o '"version": *"[^"]*"' "$WORK/old/UTLogistics/info.json")"
cat > "$WORK/server.json" <<'JSON'
{ "name": "upd", "description": "", "tags": [], "max_players": 2, "visibility": { "public": false, "lan": false },
  "username": "", "password": "", "token": "", "game_password": "", "require_user_verification": false,
  "auto_pause": false }
JSON
ln -s "$MOD_DIR" "$WORK/new/mods/UTLogistics"
cp -r "$MOD_DIR/tools/updatetest/utl-updatetest_0.0.1" "$WORK/new/mods/"
for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$(realpath "$dep")" "$WORK/new/mods/"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/new/data\n' "$WORK" > "$WORK/new/config.ini"
failed=0
for scenario in $SCENARIOS; do
  OLD="$WORK/old-$scenario"
  mkdir -p "$OLD/mods" "$OLD/data/saves"
  ln -s "$WORK/old/UTLogistics" "$OLD/mods/UTLogistics"
  for dep in "$MOD_DIR"/../flib_*.zip; do ln -s "$(realpath "$dep")" "$OLD/mods/"; done
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n' "$OLD" > "$OLD/config.ini"
  # Server mit der alten Version; Befehle über stdin, nach den Befehlen warten (sonst verschluckt)
  { sleep 100; echo "/server-save upd"; sleep 10; echo "/quit"; sleep 5; } | \
    "$FACTORIO" -c "$OLD/config.ini" --mod-directory "$OLD/mods" --start-server-load-scenario "UTLogistics/$scenario" \
    --server-settings "$WORK/server.json" --port 34297 > "$OLD/server.txt" 2>&1
  SAVE="$OLD/data/saves/upd.zip"
  if [ ! -f "$SAVE" ]; then echo "$scenario: FEHLER – kein Spielstand"; failed=1; continue; fi
  rm -f "$WORK/new/data/factorio-current.log"
  "$FACTORIO" -c "$WORK/new/config.ini" --mod-directory "$WORK/new/mods" --benchmark "$SAVE" \
    --benchmark-ticks 11400 > /dev/null 2>&1
  LOG="$WORK/new/data/factorio-current.log"
  lines="$(grep -o "\[UPD\].*" "$LOG" | tr '\n' ' ')"
  if grep -qE "Error while|non-recoverable|Failed to load" "$LOG" || ! grep -q "\[UPD\] PASS" "$LOG"; then
    echo "$scenario: FEHLER – $lines"; grep -A6 "Error while" "$LOG" | head -8; failed=1
  else
    echo "$scenario: ok – $lines"
  fi
done
exit $failed
