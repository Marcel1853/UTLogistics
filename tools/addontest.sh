#!/usr/bin/env bash
# Grafischer Test der Add-on-Schnittstelle (öffnet ein Factorio-Fenster, Steam fragt nach einer Freigabe!).
# Lädt das Szenario utl-addontest/addontest mit dem Test-Add-on tools/addontest/utl-addontest_0.0.1:
# eigene Rollen, Abschnitt im Stationsfenster, Manager-Reiter, Rangierlok per Auftrag, Lieferung aus
# der Ladebucht. Protokoll ([ADDONTEST]-Zeilen) in $WORK/data/factorio-current.log.
#   tools/addontest.sh [de|en]          grafisch
#   tools/addontest.sh --headless [s]   als Server ohne Fenster, s Sekunden (Standard 60), zum Vorab-Prüfen
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-addontest}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
ln -sfn "$MOD_DIR/tools/addontest/utl-addontest_0.0.1" "$WORK/mods/utl-addontest_0.0.1"
for dep in "$MOD_DIR"/../flib_*.zip; do [ -e "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=de\n' "$WORK" > "$WORK/config.ini"
rm -f "$WORK/data/factorio-current.log"
if [ "${1:-}" = "--headless" ]; then
  cat > "$WORK/server.json" <<'JSON'
{ "name": "addontest", "description": "", "tags": [], "max_players": 2, "visibility": { "public": false, "lan": false },
  "username": "", "password": "", "token": "", "game_password": "", "require_user_verification": false,
  "auto_pause": false, "only_admins_can_pause_the_game": true, "autosave_interval": 0, "autosave_slots": 1 }
JSON
  timeout "${2:-60}" "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" \
    --start-server-load-scenario utl-addontest/addontest --server-settings "$WORK/server.json" > "$WORK/run.log" 2>&1 || true
  grep -E "\[ADDONTEST\]|Error|error" "$WORK/data/factorio-current.log" | sed 's/^ *[0-9.]* //' | head -40
  exit 0
fi
sed -i "s/^locale=.*/locale=${1:-de}/" "$WORK/config.ini"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "utl-addontest/addontest" > "$WORK/run.log" 2>&1 || true
