#!/usr/bin/env bash
# Versuch Blaupausen-Parameter MIT Grafik (öffnet ein Factorio-Fenster, Steam fragt nach einer Freigabe!).
# Lädt das Szenario utl-paramtest/paramtest: UTL-Haltestelle (Abnehmer) mit Anforderung parameter-1 = 500;
# die Blaupause davon liegt im Inventar. Zum Testen die Blaupause platzieren, im Dialog Ware/Menge/Rolle wählen.
# Das Protokoll ([PARAM]-Zeilen) steht in $WORK/data/factorio-current.log. Factorio schließt man selbst.
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-/mnt/6459bc3a-dd91-42e5-8723-71427d99d0ba/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio}"
WORK="${WORK:-$HOME/.cache/utl-paramtest}"
mkdir -p "$WORK/mods" "$WORK/data"
ln -sfn "$MOD_DIR" "$WORK/mods/UTLogistics"
ln -sfn "$MOD_DIR/tools/paramtest/utl-paramtest_0.0.1" "$WORK/mods/utl-paramtest_0.0.1"
# Creative Mod (falls installiert): Geister aus Blaupausen stehen sofort
for dep in "$MOD_DIR"/../creative-mod_*.zip; do [ -e "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
for dep in "$MOD_DIR"/../flib_*.zip; do [ -e "$dep" ] && ln -sfn "$(realpath "$dep")" "$WORK/mods/$(basename "$dep")"; done
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/data\n[general]\nlocale=de\n' "$WORK" > "$WORK/config.ini"
rm -f "$WORK/data/factorio-current.log"
"$FACTORIO" -c "$WORK/config.ini" --mod-directory "$WORK/mods" --load-scenario "utl-paramtest/paramtest" > "$WORK/run.log" 2>&1 || true
