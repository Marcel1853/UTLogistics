# Unified Train Logistics (UTL) – Deutsch

[![Factorio](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FMarcel1853%2FUTLogistics%2Fmain%2Finfo.json&query=%24.factorio_version&label=Factorio&color=green)](https://factorio.com)
[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FMarcel1853%2FUTLogistics%2Fmain%2Finfo.json&query=%24.version&label=version&color=orange)](https://mods.factorio.com/mod/UTLogistics)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/Marcel1853/UTLogistics/blob/main/LICENSE)

Ein Zug-Dispatcher für Factorio 2.1. Du sagst deinen Stationen, was sie haben und was sie brauchen,
und UTL schickt leere Züge aus dem Depot los, die es abholen und hinbringen. Tankstellen, das Leeren
von Restladung und ein Übersichtsfenster sind schon dabei – du brauchst nur diesen einen Mod.

*English: [README.md](https://github.com/Marcel1853/UTLogistics/blob/main/README.md)*

**Im [Wiki](https://github.com/Marcel1853/UTLogistics/wiki) ist alles mit Bildern erklärt.** Diese Seite ist die Kurzfassung.

- Braucht Factorio 2.1 und [flib](https://mods.factorio.com/mod/flib). Space Age ist optional.
- Sprachen: Deutsch und Englisch. Russisch, Chinesisch, Französisch, Spanisch, Polnisch und
  brasilianisches Portugiesisch sind KI-Übersetzungen – Verbesserungen gern auf GitHub.
- Zum Start die Forschung **„Unified Train Logistics“**. Extras kommen mit späteren Forschungen. Wer
  nichts erforschen will, schaltet die Map-Einstellung „UTL-Funktionen brauchen Forschung“ aus.

## Schnellstart

1. Eine **UTL-Haltestelle** bauen und **Depot** ankreuzen. Hier warten die leeren Züge.
2. Einem Zug einen Fahrplan nur mit diesem Depot geben und auf automatisch stellen. Der Zug muss leer sein.
3. Eine zweite UTL-Haltestelle bauen, **Anbieter** ankreuzen und eine Kiste mit rotem oder grünem
   Kabel an die Haltestelle hängen. Greifarme beladen den Zug.
4. Eine dritte bauen, **Abnehmer** ankreuzen, auf einen Anforderungs-Platz klicken und eintragen, was
   du willst, z. B. 8000 Eisenplatten. Greifarme entladen den Zug.

Fertig. Wenn dem Abnehmer etwas fehlt, fährt ein Zug Depot → Anbieter → Abnehmer → Depot.

Mit Umschalt + Rechtsklick auf eine Station und Umschalt + Linksklick auf eine andere kopierst du die
Einstellungen. Blaupausen und Strg + C / Strg + V behalten sie auch.

## Stationen

Du nimmst entweder eine **UTL-Haltestelle** (ersetzt die normale, lässt sich drüberbauen) oder stellst
einen **UTL-Stations-Kombinator** neben eine normale Haltestelle und verbindest seinen Ausgang mit
ihr. Beides funktioniert gleich und braucht keinen Strom.

Jede Station bekommt eine Rolle:

- **Anbieter** – bietet an, was in seinen Kisten liegt (positive Signale).
- **Abnehmer** – fordert Waren an. Die Menge ist der Bestand, den du haben willst, nicht die Menge je
  Zug: UTL bringt nur, was fehlt, abzüglich dem, was schon unterwegs ist.
- **Anbieter und Abnehmer** zugleich – ein Puffer.
- **Aktiver Anbieter** – wird geleert, auch wenn keiner fragt: zuerst zu Abnehmern, dann ins Lager,
  der Rest zum Cleanup.
- **Depot** – hier warten leere Züge.
- **Tankstelle** – Züge fahren hin, wenn eine Lok unter 40 % fällt.
- **Cleanup** – Züge mit Restladung werden hier geleert.
- **Lager** – hält einen Bestand zwischen Minimum und Maximum: darunter fordert es an, darüber bietet
  es an.

Je Station lassen sich Zuglänge, max. Züge, Schwellen und Prioritäten einstellen. In Zahlenfeldern
geht auch Rechnen wie `4000*2`.

## Netzwerke

Jede Station hat einen Netzwerk-Namen. Stationen arbeiten nur mit anderen gleichen Namens zusammen,
so kannst du auf einer Karte getrennte Systeme betreiben, jedes mit eigenen Depots. Feld leer lassen,
dann ist alles ein Netz.

Mit Forschung lassen sich Netze verbinden, dann teilen sie Züge, Depots, Tank- und Cleanup-Stationen.
[Wiki – Netzwerke](https://github.com/Marcel1853/UTLogistics/wiki/Netzwerke)

## Wie die Züge fahren

- UTL ersetzt deinen Fahrplan nicht. Anbieter und Abnehmer kommen als vorübergehende Halte dazu und
  verschwinden nach der Abfahrt. Zuggruppen und Unterbrechungen funktionieren weiter.
- Der Zug wartet beim Anbieter, bis der Auftrag geladen ist, und beim Abnehmer, bis er leer ist.
- Ein Zug kann mehrere Waren mitnehmen. Flüssigkeiten gehen auch (eine je Fahrt).
- UTL nimmt einen freien Zug, der möglichst viel auf einmal schafft und in der Nähe ist, und prüft,
  ob er beide Stationen erreicht.
- Anforderungen mit gleicher Priorität kommen der Reihe nach dran, die älteste zuerst.
- Das Zuglimit der Haltestelle (Vanilla) gilt weiter.

Züge mit wenig Brennstoff fahren erst zur nächsten Tankstelle. Gibt es keine, fahren sie bis 10 %
weiter und bleiben dann mit einer Warnung im Depot. Züge mit Restladung fahren zum Cleanup. Ein Cleanup
kann seinen Inhalt wieder anbieten, wie ein Anbieter.
[Wiki – Tanken, Cleanup und Depots](https://github.com/Marcel1853/UTLogistics/wiki/Tanken-Cleanup-und-Depots)

## Gemischte Kisten

Ein Anbieter darf mehrere Waren in einer Kiste haben. Während einer Lieferung setzt UTL die Wagenfilter
auf die bestellten Waren, so lädt ein einfacher Greifarm nur diese. Neben jeder Haltestelle sitzt eine
kleine **Auftrags-Ausgabe** mit dem aktuellen Auftrag als Signale – für Filter-Greifarme, Pumpen oder
Lampen.
[Wiki – Gemischte Anbieter und Auftrags-Ausgabe](https://github.com/Marcel1853/UTLogistics/wiki/Gemischte-Anbieter-und-Auftrags-Ausgabe)

## UTL-Manager

Öffnen mit dem Lok-Knopf in der Shortcut-Leiste oder Strg + Umschalt + U. Er zeigt Depots, Stationen,
Netze, was auf Lager ist, die letzten 100 Lieferungen, Statistik und Warnungen. Klick auf eine Station
zeigt sie auf der Karte, Klick auf einen Zug verfolgt ihn.

Der kleine Knopf neben der Lupe filtert alles nach einem Gegenstand oder einer Flüssigkeit.
Rechtsklick leert ihn.

![UTL-Manager gefiltert nach Kupferplatte: Nur die zwei Stationen mit Kupferplatten stehen in der Liste](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-manager-ware-filter.png)

UTL nutzt außerdem normale Factorio-Warnungen: kein Zug frei, Restladung, Zug steckt fest und so
weiter. Jede lässt sich abschalten.
[Wiki – UTL-Manager und Warnungen](https://github.com/Marcel1853/UTLogistics/wiki/UTL-Manager-und-Warnungen)

## Zustandsanzeige

Häng ein normales Anzeigefeld per Kabel an eine UTL-Station, und es zeigt, was los ist: blau = Zug
unterwegs, grün = Zug an der Haltestelle, türkis = Zug wartet im Depot, gelb = nichts zu tun, rot =
Haltestelle aus. Darüber stehen Zugnummer und Ladung.

![Anzeigefelder an UTL-Stationen in den fünf Farben](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-status-display.png)

## Aussehen der Haltestelle

UTL-Haltestellen sehen normal wie Vanilla-Haltestellen aus. In den Start-Einstellungen kannst du auf
das UTL-Aussehen umstellen: ein Gittermast mit Schaltschrank und Kabeln. Zurück geht jederzeit.

![Das UTL-Aussehen der Haltestelle in allen vier Richtungen](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-stop-look.png)

## Weitere Funktionen

- **Blaupausen mit Parametern** – Waren, Mengen und Rolle lassen sich beim Platzieren abfragen. Der
  UTL-Parameter-Planer in der Shortcut-Leiste macht das einfach.
- **Netz-Kombinator** – gibt den Zustand eines Netzes als Signale aus: Bestand, Bedarf, Mangel, Züge.
- **Teams und Planeten** bleiben getrennt. Jeder Planet braucht eigene Depots und Züge.
- **Nachladen** (Standard aus) – braucht der Abnehmer mehr, während der Zug noch lädt, kommt es mit
  auf dieselbe Fahrt.
- **Zweiter Anbieter** (Standard aus) – hat ein Anbieter nicht genug, holt der Zug den Rest bei einem
  zweiten auf dem Weg.
- **Gleich der nächste Auftrag** – nach dem Entladen darf ein Zug den nächsten Auftrag nehmen, ohne
  erst ins Depot zu fahren.

Alle Einstellungen: [Wiki – Einstellungen](https://github.com/Marcel1853/UTLogistics/wiki/Einstellungen)

## Andere Mods

- **[Cargo Ships](https://mods.factorio.com/mod/cargo-ships):** Häfen werden UTL-Stationen, Schiffe
  liefern wie Züge. Ein Knopf in der Shortcut-Leiste macht aus einer Schienen-Blaupause eine für
  Wasserwege.
- **[Space Exploration](https://mods.factorio.com/mod/space-exploration):** Züge können durch den
  Weltraumaufzug zwischen Planet und Orbit liefern.
  [Wiki – Weltraumaufzug](https://github.com/Marcel1853/UTLogistics/wiki/Weltraumaufzug)
- **Mod-Autoren:** Es gibt eine Remote-Schnittstelle, Ereignisse und eine Add-on-API.
  [Wiki – Für Mod-Autoren](https://github.com/Marcel1853/UTLogistics/wiki/Für-Mod-Autoren)

## Leistung

UTL arbeitet in kleinen Schritten und schaut nur Stationen an, die sich geändert haben. Im Lasttest
(384 Züge, 880 Stationen, sonst keine Fabrik) braucht UTL im Schnitt etwa 0,24 ms je Tick. Die meiste
Zeit geht für die Züge selbst drauf, also Fahren und Wegsuche des Spiels.

## Im Spiel lernen

- **Szenarien** (Neues Spiel → Szenarien): kleine Beispiele zum Zuschauen und der Lasttest.
  [Wiki – Szenarien und Tipps](https://github.com/Marcel1853/UTLogistics/wiki/Szenarien-und-Tipps)
- **Tipps & Tricks** hat eine UTL-Kategorie mit siebzehn kurzen Szenen.
- Nach einem Update steht im Chat eine Zeile, was neu ist.
- Fragen: [Wiki – Häufige Fragen](https://github.com/Marcel1853/UTLogistics/wiki/Häufige-Fragen-und-Fehlersuche)
  oder die [Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion).

## Wie UTL entsteht

Ich bin Marcel. UTL schreibe ich mit KI (Claude von Anthropic) – den Code und die meisten Texte. Ich
lege fest, was der Mod können soll, und teste jede Version selbst in meinen Spielständen, bevor sie
online geht. Dazu gibt es automatische Tests in
[`tools/`](https://github.com/Marcel1853/UTLogistics/tree/main/tools). Ich spiele und teste auf einem
Ryzen 7 5700G ohne Grafikkarte.

Fehlerberichte und Ideen helfen sehr – am besten in der
[Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion).

## Lizenz

[Apache License 2.0](https://github.com/Marcel1853/UTLogistics/blob/main/LICENSE). Du darfst UTL
benutzen und ändern, auch in eigenen Mods, solange `LICENSE` und `NOTICE` dabei bleiben und du auf
[github.com/Marcel1853/UTLogistics](https://github.com/Marcel1853/UTLogistics) verlinkst.
