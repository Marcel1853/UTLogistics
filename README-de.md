# Unified Train Logistics (UTL) – Deutsch

*English version: [README.md](https://github.com/Marcel1853/UTLogistics/blob/main/README.md).*

> **📖 Wiki mit Bildern:** [github.com/Marcel1853/UTLogistics/wiki](https://github.com/Marcel1853/UTLogistics/wiki) – jede Funktion Schritt für Schritt erklärt,
> auf Deutsch und Englisch, mit Screenshots. Diese Seite ist die Kurzfassung.

Automatischer Zugverkehr für Factorio 2.1: **Anbieter, Abnehmer, Depots, Tankstellen,
Cleanup und Übersichtsfenster in einem Mod**, gebaut für hohe UPS.

- Benötigt: Factorio 2.1, [flib](https://mods.factorio.com/mod/flib). Space Age ist optional.
- Freischalten: Technologie **„Unified Train Logistics“** (nach „Automatisierter
  Schienenverkehr“ und „Schaltungsnetze“). Ausbaustufen: **„UTL: Ladesteuerung“** (Wagenfilter und
  Auftrags-Ausgabe) und **„UTL: Netzverbund I–III“** (ein Netz mit 1, 2 oder 3 Partnernetzen verbinden) und **„UTL: Lager“**
  (Lager-Stationen). Mit der
  Map-Einstellung „UTL-Funktionen brauchen Forschung“ = aus ist alles sofort frei.

> **Stand der Tests.** UTL läuft durch einen automatischen Selbsttest (126 Prüfungen) und einen
> headless-Lasttest mit 384 Zügen auf 12 × 12 City Blocks; Updates werden geprüft, indem ein
> Spielstand der Vorversion geladen wird. Die wichtigsten Funktionen zeigen die Szenarien. Im
> echten Spiel ist UTL bisher in kleinen Netzen gelaufen. Am neuesten: **Lager** und **Cleanup gibt
> zurück** (0.0.8), **Nachladen** (0.0.7, Standard aus) und die **Team-Trennung** (0.0.6, im echten Mehrspieler noch nicht erprobt). Wenn
> etwas schiefgeht: bitte in der [Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion)
> melden, am besten mit Spielstand und dem, was du gemacht hast. Vor dem Einsatz in einem
> gewachsenen Spielstand vorher sichern.

---

## Wie UTL entsteht

Ich hatte schon mehrmals angefangen, einen eigenen Zug-Dispatcher zu bauen – hingekriegt habe ich
es nie. Dann war der YouTuber **fiftyshadesofgames** ein bisschen frustriert von den anderen
Zug-Dispatchern, und ich dachte mir: Ach komm, ich probiere es nochmal 😄. Also habe ich komplett
neu angefangen, diesmal mit Claude Code – und mit vielen Tests hat es endlich
geklappt.

UTL entsteht mit Hilfe von KI (Claude von Anthropic): der Code und die meisten Texte – diese
README, das Wiki und die Hilfe im Spiel. Ich (Marcel) lege fest, was UTL können soll, mache jedes
Szenario und meine eigenen Spielstände auf und teste selbst, bevor etwas veröffentlicht wird –
damit so wenig wie möglich kaputtgehen kann.

- **Automatische Tests** (von der KI headless ausgeführt): Selbsttest mit 126 Prüfungen, alle
  Szenen aus Tipps & Tricks, der Lasttest mit 384 Zügen und ein Update-Test mit einem Spielstand der
  Vorversion.
- **Wie oft bisher** (gezählt aus den Entwicklungsprotokollen, 18. bis 27. September 2026): der
  Selbsttest lief rund 270-mal, der Test der Tipps & Tricks rund 85-mal, der Lasttest rund 90-mal,
  dazu über 300 weitere headless-Läufe von Factorio (Szenarien, Update-Tests, Prüfungen).
- **Eigene Tests** im Spiel: Ich starte die Szenarien und meine Spielstände immer wieder, prüfe die
  Fenster und das, was die Tests der KI sagen – bisher habe ich über 60 Fehler und Befunde
  zurückgemeldet, mit rund 35 Screenshots. Wie oft ich das Spiel selbst gestartet habe, weiß ich
  leider nicht – mitgeschrieben habe ich es nicht. Manches ist weniger getestet als anderes – das steht
  oben beim Stand der Tests.
- **Die Test-Werkzeuge** gehören zum Quelltext: [`tools/`](https://github.com/Marcel1853/UTLogistics/tree/main/tools)
  auf GitHub (Selbsttest, Lasttest, Test der Tipps & Tricks, Screenshots).
- **Mein PC** ist alles andere als ein Spielerechner: AMD Ryzen 3 2200G (4 Kerne), 14 GB nutzbarer
  Arbeitsspeicher, keine Grafikkarte (nur die Grafik im Prozessor), Linux Mint. Was hier flüssig
  läuft, sollte auf den meisten Rechnern laufen.

UTL lebt von den Ideen und Fehlerberichten anderer Spieler – je mehr kommen, desto besser wird es.
Einfach in die [Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion) schreiben.

Nebenbei ist beim Bau von UTL ein **Factorio-Modding-Skill** für Claude entstanden: geprüftes Wissen
und Test-Werkzeuge, mit denen die KI Factorio-Mods besser schreibt. Ich arbeite noch daran
und möchte ihn später veröffentlichen.

## Schnellstart

1. **Depot bauen:** eine **UTL-Haltestelle** setzen, anklicken, Häkchen **Depot**.
2. **Zug vorbereiten:** Fahrplan mit **nur dem Depot-Halt** (Wartebedingung egal, z. B.
   Inaktivität 5 s), Automatik an. Der Zug muss **leer** sein.
3. **Anbieter bauen:** UTL-Haltestelle, Häkchen **Anbieter**, Kiste mit rotem oder grünem
   Kabel **an die Haltestelle** anschließen. Greifarme beladen den Zug.
4. **Abnehmer bauen:** UTL-Haltestelle, Häkchen **Abnehmer**. Im Fenster einen
   **Anforderungs-Slot** anklicken, Ware wählen, Menge eintragen (z. B. 8000 Eisenplatten).
   Greifarme entladen den Zug.
5. Fertig: Sobald beim Abnehmer genug fehlt, fährt ein freier Zug los – vom Depot zum
   Anbieter, lädt, bringt die Ware zum Abnehmer und fährt zurück ins Depot.

Tipp: Mit **Shift + Rechtsklick** auf eine fertige Station und **Shift + Linksklick** auf
eine andere überträgst du alle UTL-Einstellungen (wie bei Vanilla-Maschinen; Haltestelle ↔
Haltestelle, Kombinator ↔ Kombinator). **Blaupausen** sowie Strg + C / Strg + V nehmen die
Einstellungen ebenfalls mit.

---

## Zwei Bauarten, gleiche Funktion

| | UTL-Haltestelle | UTL-Stations-Kombinator |
|---|---|---|
| Aufbau | ersetzt die normale Haltestelle (lässt sich direkt darüberbauen) | gehört zu einer normalen Haltestelle: **Ausgang per Kabel** (rot oder grün) mit der Haltestelle verbinden |
| Kabel | Kisten an die **Haltestelle** | Kisten an den **Eingang**, Haltestelle an den **Ausgang** des Kombinators |
| Fenster | UTL-Panel links neben dem Haltestellenfenster, Reiter „Station“ und „Werte“ | eigenes Fenster |
| Strom | nein | nein |

Gut für bestehende Bahnhöfe: Kombinator danebenstellen, Ausgang mit der Haltestelle verkabeln, Kisten an den Eingang – fertig.

## Rollen

| Rolle | Bedeutung |
|---|---|
| **Anbieter** | Waren mit **positivem** Wert im Schaltungsnetz werden abgeholt. |
| **Abnehmer** | Waren mit **negativem** Wert im Schaltungsnetz oder aus den Anforderungs-Slots werden geliefert. |
| Anbieter + Abnehmer | Puffer: beides gleichzeitig. |
| **Depot** | Hier warten freie Züge. |
| **Tankstelle** | Hier tanken Züge (Greifarme füllen die Loks). |
| **Cleanup** | Hier werden Züge mit Restladung geleert. |
| **Lager** | Nimmt an und gibt ab, zwischen Mindest- und Höchstbestand je Ware (siehe unten). |

Depot, Tankstelle und Cleanup schließen sich gegenseitig und Anbieter/Abnehmer aus.

## Anforderungen: Zielbestand, keine Bestellung

Die Menge im Anforderungs-Slot ist der **Bestand, den du haben willst**.
Geliefert wird nur, was fehlt:

> Bedarf = Zielbestand − vorhanden − schon unterwegs

Beispiel: Ziel 8000, im Lager 1536 → es fehlen 6464. Fasst ein Zug 8000, fährt **ein** Zug
und bringt alles. Willst du mehrere Züge gleichzeitig, stell einen höheren Zielbestand ein
(z. B. 32000). Geliefert wird erst, wenn der Bedarf die **Abnehmer-Schwelle** erreicht.

## Werte (Reiter „Werte“)

| Wert | Wirkung |
|---|---|
| Min./max. Zuglänge | Nur Züge mit so vielen Teilen (Loks mitgezählt). 0 = egal. Gilt für Anbieter, Abnehmer, Tankstelle, Cleanup **und Depot** (siehe unten). |
| Max. Züge | Höchstens so viele Züge gleichzeitig zu dieser Station. 0 = egal. |
| Anbieter-Schwelle / Stack-Schwelle | Erst ab dieser Menge wird angeboten. Die Stack-Schwelle gilt, wenn sie höher ist. |
| Anbieter-Priorität | Höher = wird zuerst genommen. |
| Gesperrte Slots pro Wagen | Diese Slots pro Wagen bleiben leer (z. B. für Filter). |
| Abnehmer-Schwelle / Stack-Schwelle | Erst ab diesem Bedarf fährt ein Zug. |
| Abnehmer-Priorität | Höher = wird zuerst beliefert. |
| Depot-Priorität | für spätere Versionen vorgesehen |

Mit dem grauen ⟲-Knopf setzt du einen Wert auf den Standard zurück.

**Rechnen in Feldern:** In allen Zahlenfeldern kannst du rechnen, z. B. `4000*2`, `8000/4`,
`(1+2)*3`, `2^3` oder `1e3`. Enter übernimmt das Ergebnis.

**Netzwerk:** Siehe den nächsten Abschnitt.

## Netzwerke

Jede Station hat **einen Netzwerknamen** (Feld „Netzwerk“ im Fenster, leer = `default`). Stationen,
Depots, Tankstellen und Cleanups arbeiten nur mit **genau demselben Namen** zusammen – so trägt eine
Karte mehrere getrennte Systeme, jedes mit eigenem Depot, eigener Tankstelle und eigenem Cleanup. Wer
nur ein großes Netz will, lässt das Feld überall leer. Ein Tippfehler oder ein Großbuchstabe ist ein
anderes Netz.

**Netze verbinden** (Forschung „UTL: Netzverbund I–III“, 1–3 Partner): Verbundene Netze helfen sich
mit Zügen, Depots, Tankstellen und Cleanups. Ein Verbund ist ein **Stern** – ein Zentrum, Partner
helfen dem Zentrum und bekommen Hilfe, aber **nicht untereinander**; ein Netz gehört zu höchstens
einem Stern, Verbindungen gelten je Oberfläche. Einstellen im Stationsfenster („Verbunden mit“) oder
im UTL-Manager, Reiter „Netzwerke“. Beispiel: ein Depot im eigenen Netz `Reserve`, verbunden mit
`Erze` und `Platten`, bedient beide, während Erz- und Platten-Stationen einander weiter nicht kennen.

Mehr, mit Beispielen und allen Meldungen: [Wiki – Netzwerke](https://github.com/Marcel1853/UTLogistics/wiki/Netzwerke).

## Gemischte Anbieter

*Braucht die Forschung „UTL: Ladesteuerung“.*

Ein Anbieter darf mehrere Waren in **einer** Kiste haben:

- **Wagenfilter (ohne Kabel):** Während einer Lieferung stellt UTL die Wagen-Slots auf die Waren des
  Auftrags; ein gewöhnlicher Greifarm an einer gemischten Kiste lädt dann nur das Bestellte. Je Station
  oder für die ganze Karte abschaltbar; Wagen mit eigenen Filtern fasst UTL nicht an.
- **Auftrags-Ausgabe:** ein kleiner Ausgang neben jeder Haltestelle mit den laufenden Aufträgen als
  Signale – hier zu ladende Waren positiv, ankommende negativ; solange ein Lieferzug dasteht auch
  Zug-Nummer, Länge, Loks, Wagen, **„Zug lädt hier“** und **„Zug entlädt hier“**. Für Filter-Greifarme,
  Anzeigen und Pumpen (Flüssigkeiten haben keine Slot-Filter). Nicht an den Eingang der Station kabeln.

Mehr, mit Beispielen: [Wiki – Gemischte Anbieter und Auftrags-Ausgabe](https://github.com/Marcel1853/UTLogistics/wiki/Gemischte-Anbieter-und-Auftrags-Ausgabe).

## Wie die Züge fahren

- UTL **überschreibt deinen Fahrplan nicht**: Anbieter und Abnehmer kommen als **temporäre Halte**
  hinein und verschwinden nach der Abfahrt. **Zuggruppen und Interrupts** bleiben erhalten.
- Ein Schienen-Wegpunkt vor jeder Haltestelle sorgt dafür, dass der Zug genau diese anfährt, auch
  wenn mehrere gleich heißen.
- Beim Anbieter wartet der Zug, bis die bestellte Menge geladen ist, beim Abnehmer, bis er leer ist.
- Anfragen gleicher Priorität kommen **der Reihe nach** dran – die älteste zuerst, so wartet kein
  Abnehmer ewig.
- Auswahl: Anbieter mit höchster Priorität und Menge, dann ein freier, naher Zug, der möglichst viel
  auf einmal mitnimmt; die Erreichbarkeit prüft die Pfadsuche. Reservierungen verhindern doppelte
  Fahrten.
- **Mehrere Waren je Zug**, **Flüssigkeiten** (je Lieferung eine Sorte) und **direkt der nächste
  Auftrag** nach dem Entladen oder nach Tank-/Cleanup-Stationen (Map-Einstellung).
- Das **Zuglimit** der Haltestelle (Vanilla) gilt zusätzlich zu „max. Züge“.

## Tanken

Liegt **eine** Lok unter **40 %** (Map-Einstellung „Tanken unter (%)“), fährt der Zug zur nächsten
passenden **Tankstelle** – vor dem nächsten Auftrag, nach dem Entladen oder aus dem Depot – und
wartet, bis alle Loks voll sind oder sich 30 s nichts tut. Ist keine frei, wartet ein knapper Zug im
Depot; ein Netz **ganz ohne** UTL-Tankstelle tankt auf deine Art (Interrupt, von Hand). Min./max.
Zuglänge an Tankstellen trennt kleine und große Züge.

## Cleanup (Restladung)

Züge mit Restladung (mit Ladung zurück im Depot, abgebrochene Lieferung, beim Abnehmer nicht leer
geworden) fahren zur nächsten passenden **Cleanup-Station**. Was sie annimmt, stellst du im Fenster
ein: **Alle Items** / **Alle Flüssigkeiten** (Standard) oder einzelne Waren; reicht eine nicht, fährt
der Zug mehrere an. Flüssigkeiten: mit Pumpen in einen Lagertank, je Flüssigkeit ein Cleanup.

**Cleanup gibt zurück.** Mit **„Inhalt wieder anbieten“** bietet ein Cleanup seinen Kisteninhalt an
wie ein Anbieter – **nur als Reserve**, **wie ein normaler Anbieter** oder **zuerst leeren**. Reste
kommen 5 Minuten lang nicht zum selben Abnehmer zurück. Map-Einstellung: „Cleanup darf Inhalt wieder
anbieten“.

Mehr: [Wiki – Tanken, Cleanup und Depots](https://github.com/Marcel1853/UTLogistics/wiki/Tanken-Cleanup-und-Depots).

## Lager (für Fortgeschrittene)

*Braucht die Forschung „UTL: Lager“.*

Ein **Lager** nimmt an **und** gibt ab – ein Puffer nahe bei den Verbrauchern. Je Ware (bis zu acht)
ein **Mindest-** und ein **Höchstbestand**: unter Mindest fordert es bis Höchst an, über Mindest bietet
es den Rest an **wie ein normaler Anbieter**. Zwei Lager schieben sich Ware nie hin und her. Mit
**„Restladung annehmen“** (an) dürfen Züge hier auch Reste abladen. Map-Einstellung: „Lager-Stationen
erlauben“.

**Greifarme in beide Richtungen** (Vanilla, eine Gleisseite): Entlade-Greifarm → Kiste →
Umlade-Greifarm → Kiste → Lade-Greifarm. Die Auftrags-Ausgabe an Entlade- und Lade-Greifarme
verdrahten: Laden **[utl-loading] > 0**, Entladen **[utl-loading] = 0**. Das Szenario „UTL-Lager“
zeigt es.

## Netz-Kombinator

*Braucht die Forschung „UTL: Netz-Kombinator“. Neu in 0.0.9.*

Gibt den Zustand eines UTL-Netzes als Schaltungssignale aus. Im Fenster wählst du das Netz (auf
Wunsch mit den verbundenen Netzen) und den Modus: **Bestand** (was Anbieter anbieten),
**Lagerbestand** (was in Lagern liegt), **Fehlmenge** (was Abnehmer brauchen und niemand anbietet)
oder **Züge** (gesamt, frei, unterwegs, Lieferungen, knapp an Treibstoff, ohne Weg, Züge aus verbundenen Netzen, die aushelfen, und eigene Züge, die anderswo fahren). Was die Signale
bewirken, verdrahtest du selbst – eine Lampe, eine Anzeige oder in Space Age die Fehlmenge an eine
Frachtlandeplattform („Anforderungen setzen“). UTL steuert Plattformen nie selbst.

## Depots und Zuglänge

Freie Züge warten **leer** an Haltestellen mit der Rolle **Depot**. **Jede** Depot-Haltestelle
braucht die Rolle – der Name allein reicht nicht (Shift-Klick zum Kopieren hilft).

Landet ein Zug an einer Haltestelle, die **so heißt wie ein Depot, aber keine Depot-Rolle hat**
(auch eine normale Vanilla-Haltestelle), zieht er von selbst zu einem freien echten Depot mit
diesem Namen um. Ohne freies Depot bleibt er dort stehen – dann fehlt irgendwo die Rolle.

Min./max. Zuglänge am Depot: Kommt ein Zug an einem Depot an, das nicht zu seiner Länge
passt, fährt er zu einem **freien, passenden Depot mit gleichem Namen**. Gibt es keins, bleibt
er stehen und ist trotzdem verfügbar.

## Übersicht: UTL-Manager

Öffnen mit dem **Lok-Knopf** in der Shortcut-Leiste oder **Strg + Umschalt + U** (oder
**Strg + Alt + U**). Reiter: **Depots**, **Stationen**, **Netzwerke**, **Inventar** (Klick auf eine Ware
zeigt Details), **Verlauf** (letzte 100 Lieferungen), **Statistik** (Durchsatz je Ware über 10 Minuten und die
letzte Stunde, Auslastung je Zug), **Alarme** (letzte 100), **Einstellungen**. Suche
nach Stationsnamen, Klick auf eine Station zeigt sie auf der Karte, Klick auf einen Zug verfolgt ihn.
Mit Space Age wählt eine Auswahl den Planeten.

**Warnungen** kommen als normale Factorio-Warnungen in drei Gruppen – kein passender Zug (nach
5 Minuten), Restladung/Fehlmenge, Zugprobleme – jede je Spieler abschaltbar.

Mehr: [Wiki – UTL-Manager und Warnungen](https://github.com/Marcel1853/UTLogistics/wiki/UTL-Manager-und-Warnungen).

## Map-Einstellungen

Die wichtigsten: **Direkt der nächste Auftrag** (an), **Nur den Auftrag laden** (an),
**Auftrags-Ausgabe** (an), **UTL-Funktionen brauchen Forschung** (an), **Tanken unter** (40 %),
**Inaktivität beim Laden / Entladen** (je 30 s, mit der Fracht per **oder** bzw. **und** verknüpft),
**Nachladen** (aus), **Cleanup darf Inhalt wieder anbieten** (an), **Lager-Stationen erlauben** (an).
Die Lade-Werte gehen auch im **UTL-Manager, Reiter „Einstellungen“** – mit Teams je Team; Admins
nutzen **`/utl-admin`**.

Alle Einstellungen: [Wiki – Einstellungen](https://github.com/Marcel1853/UTLogistics/wiki/Einstellungen).

## Leistung

Gemessen mit dem Lasttest-Szenario, headless (ohne Grafik, also ohne FPS):

| Netz | Messung | UTL pro Tick (Schnitt) | ganzes Spiel pro Tick (Schnitt) | Ticks unter 60 UPS |
|---|---|---|---|---|
| 9 × 9, 180 Züge, 340 Bahnhöfe | 40 min, ~1300 Lieferungen | 0,045 ms | – | 0 |
| 12 × 12, 384 Züge (davon 24 Flüssigkeit), 496 Bahnhöfe mit 8 Lagern, 3 verbundene Netze, Nachladen | 10 min | 0,072 ms | 2,9 ms | 5 von 36 000 |

UTL selbst hat Spitzen bis etwa 13 ms, wenn es Züge losschickt (das Losschicken löst die
Pfadsuche des Spiels aus). Den größten Teil der Zeit brauchen die Züge des Spiels selbst
(Bewegung und Pfadsuche).

**Wichtig:** Die Karte ist sonst **fast leer** (keine Fabrik, keine Bänder, keine Beißer) – die Zahlen
zeigen, was UTL und die Züge brauchen, nicht die UPS einer ganzen Megabase.

## Szenarien zum Ausprobieren

**Neues Spiel → Szenarien** (alles erforscht, Cheat-Modus an, Anzeigefelder mit Erklärungen):

- **UTL-Beispiele (gemischter Anbieter)** – gemischter Anbieter mit Auftrags-Ausgabe, zwei Waren in
  einer Fahrt, Öl und Wasser über geschaltete Pumpen.
- **UTL-Netzverbund** – vier Netze, ein Stern mit einem Partner ohne eigene Züge.
- **UTL-Teams** – vier Teams mit gleichen Stations- und Netznamen; `/utl-team rot` wechselt.
- **UTL-Nachladen (zum Anschauen)** – mit und ohne Nachladen, Runde für Runde, mit Erklärfenster.
- **UTL-Lager (zum Anschauen)** – neu in 0.0.8: Lager, ein Cleanup, der zurückgibt, und vier kleine
  Beispiel-Strecken, mit Erklärfenster.
- **UTL-Planeten-Test (Space Age)** – dasselbe Netz auf Nauvis, Vulcanus und Gleba.
- **UTL-Lasttest (384 Züge)** – 12 × 12 City Blocks zum Messen, mit Lagern, Cleanups, die
  zurückgeben, verbundenen Netzen, Nachladen und festen Zuglängen; startet in wenigen Sekunden.

Einzelheiten und Bilder: [Wiki – Szenarien und Tipps](https://github.com/Marcel1853/UTLogistics/wiki/Szenarien-und-Tipps).

## Tipps & Tricks im Spiel

Im Menü **Tipps & Tricks** gibt es eine eigene Kategorie **Unified Train Logistics** mit siebzehn
Einträgen, jeder mit laufender Beispielszene – von der ersten Lieferung über Netzwerke, Cleanup gibt
zurück und Lager bis zum Manager.

Nach einem Update schreibt UTL einmal eine kurze Zeile mit dem Wichtigsten in den Chat; der Link
darin öffnet die Tipps-&-Tricks-Seite **„Neu in UTL“**. Je Spieler abschaltbar: *Update-Hinweise im
Chat*.

## Häufige Fragen

Fragen und Fehlersuche Schritt für Schritt: [Wiki – Häufige Fragen und Fehlersuche](https://github.com/Marcel1853/UTLogistics/wiki/Häufige-Fragen-und-Fehlersuche).

## Teams und Oberflächen

**Teams (Forces)** und **Oberflächen** trennt UTL sauber: Züge, Depots, Tankstellen und Cleanups
arbeiten nur im eigenen Team und auf der eigenen Oberfläche, Netzverbindungen gelten je Team, der
Manager zeigt nur dein Team. Zwei Teams dürfen dieselben Namen benutzen. Züge können den Planeten
nicht wechseln – jede Oberfläche braucht eigene Depots und Züge. Ausprobieren: Szenario „UTL-Teams“.

## Nachladen (abschaltbar, Standard aus)

Wächst der Bedarf eines Abnehmers, während sein Zug noch zum Anbieter fährt oder dort lädt, kommt
die Menge auf die **laufende Ladeliste** statt in eine zweite Fahrt (derselbe Anbieter, Platz im Zug,
bei Flüssigkeiten nur dieselbe Sorte). Der Zug steht dafür länger am Anbieter, deshalb ist es **von
Haus aus aus** – Map-Einstellung oder Manager „Einstellungen“: *Nachladen, während der Zug lädt*.
Szenario „UTL-Nachladen“ zeigt es.

## Noch nicht enthalten

Einsammeln bei einem zweiten Anbieter auf dem Weg (eine Fahrt holt bisher bei genau einem
Anbieter ab).

## Für Mod-Autoren

Remote-Schnittstelle `utl` (Stationsdaten, Lieferungen, Warnungen, Stationen und Anforderungen
einstellen, Netzverbindungen, Team- und Kartenwerte, per Script erstellte Blaupausen taggen):
[Wiki – Für Mod-Autoren](https://github.com/Marcel1853/UTLogistics/wiki/Für-Mod-Autoren).
