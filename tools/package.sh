#!/usr/bin/env bash
# Packt den Mod als <name>_<version>.zip nach dist/ – ohne Entwicklungsdateien.
# Prüft die Größe gegen die Grenze des Mod-Portals (262,1 MB).
set -euo pipefail

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$(jq -r .name "$MOD_DIR/info.json")"
VERSION="$(jq -r .version "$MOD_DIR/info.json")"
PACKAGE="${NAME}_${VERSION}"
DIST="$MOD_DIR/dist"
ZIP="$DIST/$PACKAGE.zip"

WARN_BYTES=200000000   # 200 MB: Auslagerung der Grafiken vorbereiten
LIMIT_BYTES=262100000  # 262,1 MB: Grenze des Mod-Portals

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Im Zip muss der Ordner <name>_<version> heißen.
rsync -a \
  --exclude '.git/' --exclude '.gitignore' --exclude '.vscode/' \
  --exclude 'docs/' --exclude 'tools/' --exclude 'dist/' \
  --exclude 'CLAUDE.md' --exclude 'MySkillsAi-s-main*' \
  "$MOD_DIR/" "$STAGE/$PACKAGE/"

mkdir -p "$DIST"
rm -f "$ZIP"
(cd "$STAGE" && zip -qr9 "$ZIP" "$PACKAGE")

SIZE=$(stat -c %s "$ZIP")
echo "Gepackt: $ZIP ($((SIZE / 1000)) KB)"

if (( SIZE > LIMIT_BYTES )); then
  echo "FEHLER: größer als 262,1 MB – das Mod-Portal nimmt die Datei nicht an." >&2
  rm -f "$ZIP"
  exit 1
elif (( SIZE > WARN_BYTES )); then
  echo "WARNUNG: über 200 MB – Grafiken in einen eigenen Mod auslagern." >&2
fi
