#!/usr/bin/env bash
# Alle Headless-Prüfungen auf einmal: Lint (scripts, prototypes, tools), Selbsttest, Schiffstest,
# Aufzug-Test – die drei Spieltests laufen parallel (je eigener Datenordner). Gezählt wird direkt aus
# der Ausgabe dieses Laufs (keine alten Dateien). Am Ende eine Zeile je Prüfung, Exit 1 bei Fehlern.
# Aufruf: tools/test-all.sh [--tips]   --tips: zusätzlich die Tipps-&-Tricks-Szenen (dauert länger)
set -uo pipefail
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
LINT="$MOD_DIR/docs/factorio-modding-skill/scripts/lint.sh"
failed=0

lint_line() {
  local dir="$1" log="$OUT/lint-$1.txt"
  if [ ! -x "$LINT" ]; then echo "Lint $dir: übersprungen (docs/factorio-modding-skill fehlt)"; return; fi
  (cd "$MOD_DIR" && "$LINT" . "$dir") 2>&1 | tr '\r' '\n' > "$log"
  if grep -q "no problems found" "$log"; then
    echo "Lint $dir: sauber"
  else
    echo "Lint $dir: $(grep -c '\[Warning\]\|\[Error\]' "$log") Befunde"
    grep '\[Warning\]\|\[Error\]' "$log" | head -10 | sed 's/^/    /'
    failed=1
  fi
}

# Spieltests im Hintergrund starten
"$MOD_DIR/tools/selftest.sh" > "$OUT/selftest.txt" 2>&1 & p1=$!
"$MOD_DIR/tools/shiptest.sh" > "$OUT/shiptest.txt" 2>&1 & p2=$!
"$MOD_DIR/tools/setest.sh" > "$OUT/setest.txt" 2>&1 & p3=$!
if [ "${1:-}" = "--tips" ]; then "$MOD_DIR/tools/tipstest.sh" > "$OUT/tipstest.txt" 2>&1 & p4=$!; fi

# währenddessen Lint
for dir in scripts prototypes tools; do lint_line "$dir"; done

game_line() {
  local name="$1" tag="$2" pid="$3" file="$OUT/$1.txt"
  wait "$pid"; local code=$?
  local pass fail
  pass=$(grep -c "\[$tag\] PASS" "$file" || true)
  fail=$(grep -c "\[$tag\] FAIL" "$file" || true)
  if [ "$code" -eq 0 ] && [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
    echo "$name: $pass bestanden"
  else
    echo "$name: $pass bestanden, $fail FEHLER (Exit $code)"
    grep "\[$tag\] FAIL\|Error\|nicht fertig" "$file" | head -10 | sed 's/^/    /'
    failed=1
  fi
}
game_line selftest SELFTEST "$p1"
game_line shiptest SHIPTEST "$p2"
game_line setest SETEST "$p3"
if [ "${1:-}" = "--tips" ]; then
  wait "$p4"
  if grep -q "Error" "$OUT/tipstest.txt"; then
    echo "tipstest: FEHLER"; grep "Error" "$OUT/tipstest.txt" | head -5 | sed 's/^/    /'; failed=1
  else
    echo "tipstest: alle Szenen ohne Fehler"
  fi
fi
exit $failed
