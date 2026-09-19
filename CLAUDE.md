# Unified Train Logistics (UTL) – Projektregeln

Eigenständiger Zug-Dispatcher-Mod für Factorio 2.1 (LTN + Manager + Combinator + Cleanup in
einem Mod). Plan: `docs/PLAN.md`, Ideen: `docs/IDEEN.md`.

## Regel 1 – Erlaubte Quellen (nur das schauen!!)

Nur diese Webseiten benutzen, **keine anderen** und keine Websuche:

- https://lua-api.factorio.com/latest/auxiliary/mod-structure.html
- https://lua-api.factorio.com/latest/ (inkl. Unterseiten der API-Doku)
- https://lua-api.factorio.com/latest/index-runtime.html
- https://lua-api.factorio.com/latest/index-prototype.html
- https://wiki.factorio.com/Tutorial:Mod_settings
- https://mods.factorio.com/
- github.com – nur das eigene Repo, sonst nichts:
  https://github.com/Marcel1853/MySkillsAi-s (wenn erreichbar, benutzen)

Lokal lesen ist erlaubt: installierte Mods in `~/.factorio/mods/`, alte Versuche in
`~/.factorio/Utl_mods_besser/` und `~/.factorio/UTL-Mods/`.

## Regel 2 – Skill

- Skill-Kopie aus GitHub liegt als `docs/factorio-modding-skill` im Mod-Ordner (wird nicht gepusht).
- Aussagen des Skills immer gegen die offizielle API (Regel 1) prüfen. Bekannte Fehler stehen
  in `docs/IDEEN.md` unter „Skill-Korrekturen“.

## Regel 3 – Plan und Ideen

- Der Plan liegt in `docs/PLAN.md`, Ideen in `docs/IDEEN.md`. Beide aktuell halten.
- `docs/` steht in `.gitignore` und wird **nicht** gepusht.
- Meilensteine einzeln umsetzen, nach jedem Schritt auf Ansage warten.

## Regel 4 – Code

- Ein Mod, ein `storage`. Keine Aufteilung der Logik auf mehrere Mods.
- Saubere Ordnerstruktur: Bereiche in Unterordnern, keine Dateihaufen, Dateien klein halten
  (Richtwert < 400 Zeilen).
- Echte Umlaute in Texten, Kommentaren und Locale; Bezeichner bleiben ASCII.
- Immer Locale EN + DE.
- Migrationen nach https://lua-api.factorio.com/latest/auxiliary/migrations.html:
  Prototyp umbenannt → JSON-Migration in `migrations/`; bestehende `storage`-Daten umbauen →
  Lua-Migration in `migrations/` (läuft pro Spielstand einmal, **vor** on_configuration_changed,
  daher immer prüfen, ob die Tabellen existieren). Dateinamen: `<version>-<thema>.lua`.
  `scripts/core/state.lua` ergänzt nur fehlende Tabellen.
- Fenster umgebaut → `GUI_VERSION` in `scripts/gui/station/window.lua` erhöhen (offene Fenster
  aus alten Spielständen werden dann geschlossen statt mit falschem Aufbau aufgefrischt).
- Entity-Typ nie still ändern: das ergibt neue `unit_number`s und ungültige Referenzen.

## Regel 5 – Leistung (UPS und FPS dürfen nicht einbrechen)

- Kein `on_tick`; ein `on_nth_tick`-Heartbeat mit festem Arbeitsbudget pro Tick.
- Ereignisgetrieben statt Polling, Event-Filter nutzen.
- Pfadsuche gedeckelt und gecacht; nur geänderte Stationen neu auswerten.
- GUI nur aktualisieren, wenn offen und nur geänderte Zeilen.
- Details: `docs/PLAN.md`, Abschnitt „UPS/FPS-Regeln“.

## Regel 6 – Mod-Größe

- Mod-Portal erlaubt max. **262,1 MB** pro Mod. Warnschwelle 200 MB.
- Wird es zu groß: nur Grafiken in einen eigenen Mod auslagern, Logik bleibt in einem Mod.

## Vorbilder

Dispatcher: LTN, Project Cybersyn, Precise Train Logistics, Rail Logistics Daemon (RLD),
Cybersyn 2.

LTN-Addons: LTN Manager, LTN Combinator Modernized, LTN Cleanup.
