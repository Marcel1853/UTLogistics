#!/usr/bin/env bash
# Grafischer Test der Add-on-Schnittstelle (öffnet ein Factorio-Fenster, Steam fragt nach einer Freigabe!).
# Lädt das Szenario utl-addontest/${SCENARIO:-addontest} mit dem Test-Add-on tools/addontest/utl-addontest_0.0.1:
# eigene Rollen, Abschnitt im Stationsfenster, Manager-Reiter, Rangierlok per Auftrag, Lieferung aus
# der Ladebucht. Protokoll ([ADDONTEST]-Zeilen) in $WORK/data/factorio-current.log.
#   tools/addontest.sh [de|en]          grafisch (mit Creative Mod, Marcels Spiel- und Mod-Einstellungen)
#   tools/addontest.sh --headless [s]   als Server ohne Fenster, s Sekunden (Standard 60), zum Vorab-Prüfen
#   SCENARIO=rangieren tools/addontest.sh …   Marcels Rangier-Bahnhof (Standard: addontest)
#   LOAD=1 tools/addontest.sh …   große Lasttest-Karte (UTLogistics/UTL-Lasttest) mit den drei Test-Add-ons
#                                  aus tools/addons (Statistik, Werkstatt, Reserve & Eilaufträge)
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-addontest}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
ln -sfn "$MOD_DIR/tools/addontest/utl-addontest_0.0.1" "$WORK/mods/utl-addontest_0.0.1"
# Test-Add-ons für die Lasttest-Karte (bei LOAD=1); sonst alte Verknüpfungen entfernen
for addon in "$MOD_DIR"/tools/addons/utl-addon-*; do
  if [ -n "${LOAD:-}" ]; then ln -sfn "$addon" "$WORK/mods/$(basename "$addon")"; else rm -f "$WORK/mods/$(basename "$addon")"; fi
done
TARGET="utl-addontest/${SCENARIO:-addontest}"
[ -n "${LOAD:-}" ] && TARGET="UTLogistics/UTL-Lasttest"
# flib und der Creative Mod (Kreativ-Werkzeuge zum Ausprobieren)
CREATIVE=("$MOD_DIR"/../creative-mod_*.zip); [ -n "${NO_CREATIVE:-}" ] && CREATIVE=()
for dep in "$MOD_DIR"/../flib_*.zip "${CREATIVE[@]}"; do
  [ -e "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"
done
# Marcels eigene Einstellungen übernehmen: Spiel (Grafik, Ton, Tasten …) aus ~/.factorio/config/config.ini
# – nur die Pfade zeigen auf den Testordner – und die Mod-Einstellungen (z. B. Signal-Stil).
USER_CONFIG="$HOME/.factorio/config/config.ini"
if [ -f "$USER_CONFIG" ]; then
  sed -e "s|^read-data=.*|read-data=__PATH__executable__/../../data|" -e "s|^write-data=.*|write-data=$WORK/data|" \
    "$USER_CONFIG" > "$WORK/config.ini"
else
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=de\n' "$WORK" > "$WORK/config.ini"
fi
[ -f "$MOD_DIR/../mod-settings.dat" ] && cp "$MOD_DIR/../mod-settings.dat" "$WORK/mods/mod-settings.dat"
rm -f "$WORK/data/factorio-current.log"
if [ "${1:-}" = "--headless" ]; then
  cat > "$WORK/server.json" <<'JSON'
{ "name": "addontest", "description": "", "tags": [], "max_players": 2, "visibility": { "public": false, "lan": false },
  "username": "", "password": "", "token": "", "game_password": "", "require_user_verification": false,
  "auto_pause": false, "only_admins_can_pause_the_game": true, "autosave_interval": 0, "autosave_slots": 1 }
JSON
  timeout "${2:-60}" "$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" \
    --start-server-load-scenario "$TARGET" --server-settings "$WORK/server.json" > "$WORK/run.log" 2>&1 || true
  grep -E "\[ADDONTEST\]|Error|error" "$WORK/data/factorio-current.log" | sed 's/^ *[0-9.]* //' | head -40
  exit 0
fi
# Sprache nur, wenn angegeben (sonst die aus Marcels Einstellungen)
[ -n "${1:-}" ] && sed -i "s/^locale=.*/locale=$1/" "$WORK/config.ini"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "$TARGET" > "$WORK/run.log" 2>&1 || true
