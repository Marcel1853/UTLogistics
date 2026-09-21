# Unified Train Logistics (UTL) – Deutsch

*English version: [README.md](https://github.com/Marcel1853/UTLogistics/blob/main/README.md).*

Automatischer Zugverkehr für Factorio 2.1: **Anbieter, Abnehmer, Depots, Tankstellen,
Cleanup und Übersichtsfenster in einem Mod**, gebaut für hohe UPS.

- Benötigt: Factorio 2.1, [flib](https://mods.factorio.com/mod/flib). Space Age ist optional.
- Freischalten: Technologie **„Unified Train Logistics“** (nach „Automatisierter
  Schienenverkehr“ und „Schaltungsnetze“).

> **Junger Mod, bisher klein getestet.** UTL läuft durch einen automatischen Selbsttest
> (74 Prüfungen) und einen headless-Lasttest, und die neuen Ladefunktionen werden im
> Beispiel-Szenario vorgeführt. Im echten Spiel ist er bisher nur in kleinen Netzen gelaufen.
> Wenn etwas schiefgeht: bitte in der
> [Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion) melden, am besten mit
> Spielstand und dem, was du gemacht hast. Vor dem Einsatz in einem gewachsenen Spielstand
> vorher sichern.

---

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
Haltestelle, Combinator ↔ Combinator). **Blaupausen** sowie Strg + C / Strg + V nehmen die
Einstellungen ebenfalls mit.

---

## Zwei Bauarten, gleiche Funktion

| | UTL-Haltestelle | UTL-Stations-Combinator |
|---|---|---|
| Aufbau | ersetzt die normale Haltestelle (lässt sich direkt darüberbauen) | gehört zu einer normalen Haltestelle: **Ausgang per Kabel** (rot oder grün) mit der Haltestelle verbinden |
| Kabel | Kisten an die **Haltestelle** | Kisten an den **Eingang**, Haltestelle an den **Ausgang** des Combinators |
| Fenster | UTL-Panel links neben dem Haltestellenfenster, Reiter „Station“ und „Werte“ | eigenes Fenster |
| Strom | nein | nein |

Gut für bestehende Bahnhöfe: Combinator danebenstellen, Ausgang mit der Haltestelle verkabeln, Kisten an den Eingang – fertig.

## Rollen

| Rolle | Bedeutung |
|---|---|
| **Anbieter** | Waren mit **positivem** Wert im Schaltungsnetz werden abgeholt. |
| **Abnehmer** | Waren mit **negativem** Wert im Schaltungsnetz oder aus den Anforderungs-Slots werden geliefert. |
| Anbieter + Abnehmer | Puffer: beides gleichzeitig. |
| **Depot** | Hier warten freie Züge. |
| **Tankstelle** | Hier tanken Züge (Greifarme füllen die Loks). |
| **Cleanup** | Hier werden Züge mit Restladung geleert. |

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

Jede Station hat **einen Netzwerknamen** (Feld „Netzwerk“ in ihrem Fenster). Leer bedeutet
`default`. Zwei Stationen arbeiten nur zusammen, wenn der Name **genau gleich** ist. Es gibt
keine Nummern und keine Bitmaske wie bei LTN.

Das gilt für **alle Rollen**:

| Rolle | Wirkung des Netzwerks |
|---|---|
| Anbieter | wird nur Abnehmern mit demselben Namen angeboten |
| Abnehmer | wird nur von Anbietern mit demselben Namen beliefert |
| Depot | gibt seine Züge nur an dieses Netzwerk |
| Tankstelle | ein Zug tankt nur in seinem eigenen Netzwerk |
| Cleanup | ein Zug wird nur in seinem eigenen Netzwerk geleert |

Beispiel: zwei getrennte Systeme auf einer Karte.

| Station | Netzwerk |
|---|---|
| Erzabbau, Erzverhüttung, Depot „Erz-Depot“ | `Erze` |
| Plattenlager, Plattenverbraucher, Depot „Platten-Depot“ | `Platten` |

Erz-Züge nehmen dann nie einen Platten-Auftrag an. Jedes System braucht **eigenes Depot, eigene
Tankstelle und eigenes Cleanup**. Wer nur ein großes Netz will, lässt das Feld überall leer.

### Zusatznetze

Neben ihrem Heimatnetz kann eine Station in **weiteren Netzwerken** mitarbeiten. Im Stationsfenster
wählst du das Heimatnetz aus einer Liste aller Netze der Karte (mit ✎ benennst du es um oder trägst
ein neues ein); darunter fügt „Netz hinzufügen …“ ein weiteres hinzu. Jedes Zusatznetz steht als
kleiner Knopf darunter – ein Klick nimmt es wieder heraus.

Zwei Stationen arbeiten zusammen, sobald sich ihre Netze **überschneiden**. Ein Reserve-Depot
bedient damit mehrere Netze, ohne dass die Netze zusammenwachsen:

| Station | Heimatnetz | zusätzlich |
|---|---|---|
| Anbieter/Abnehmer Erz | `Erze` | – |
| Anbieter/Abnehmer Platten | `Platten` | – |
| Reserve-Depot (10 Züge) | `Reserve` | `Erze`, `Platten` |

Die Züge dieses Depots nehmen dann Erz- und Platten-Aufträge an, während Erz- und Platten-Stationen
einander weiterhin nicht kennen.

Im UTL-Manager steht das Netzwerk in eckigen Klammern hinter dem Stationsnamen, sobald es nicht
`default` ist, Zusatznetze als `[Reserve +Erze +Platten]`. Der Reiter **Netzwerke** zeigt alle Netze
der Karte mit freien Zügen, laufenden Lieferungen und ihren Stationen – und ob eine Station dort mit
ihrem Heimatnetz steht oder nur als Zusatznetz mitarbeitet.

**Typische Fehler**

- Depot im falschen Netzwerk → Warnung „kein freier Zug im Netzwerk …“, obwohl Züge dastehen.
- Tankstelle im falschen Netzwerk → knappe Züge fahren nicht los (siehe *Tanken*).
- Ein Tippfehler oder ein großer Buchstabe ist ein anderes Netzwerk: `Erze` und `erze` gehören
  nicht zusammen.

## Wie die Züge fahren

- UTL **überschreibt deinen Fahrplan nicht.** Anbieter und Abnehmer werden als
  **temporäre Halte** eingefügt und verschwinden nach der Abfahrt von selbst.
  **Zuggruppen und Interrupts** bleiben erhalten.
- Vor jede Haltestelle setzt UTL einen Schienen-Wegpunkt. So fährt der Zug genau die richtige
  Haltestelle an, auch wenn mehrere gleich heißen.
- Beim Anbieter wartet der Zug, bis die bestellte Menge geladen ist, beim Abnehmer, bis er leer
  ist.
- UTL wählt: den Anbieter mit höchster Priorität und passender Menge, dann einen freien Zug,
  der möglichst viel auf einmal mitnimmt (wenige Fahrten) und nah ist. Die Erreichbarkeit
  wird per Pfadsuche geprüft.
- Reservierungen verhindern, dass mehrere Züge für denselben Bedarf losfahren.
- **Mehrere Waren in einem Zug:** Hat der Anbieter weitere Waren, die derselbe Abnehmer braucht,
  werden sie mitgeladen, solange Platz ist.
- **Flüssigkeiten:** Züge mit Flüssigkeitswagen liefern Flüssigkeiten (je Lieferung eine Sorte).
- **Direkt der nächste Auftrag:** Nach dem Entladen (und nach Tank-/Cleanup-Stationen) übernimmt
  ein Zug sofort eine passende Lieferung in seiner Nähe, statt leer ins Depot zu fahren.
  Abschaltbar in den Map-Einstellungen.
- Das **Zuglimit** der Haltestelle (Vanilla) wird beachtet – zusätzlich zu „max. Züge“.

## Tanken

Liegt **eine** Lok eines Zugs unter **40 %** (Map-Einstellung „Tanken unter (%)“), fährt der
Zug zur nächsten passenden **Tankstelle** – vor dem nächsten Auftrag, direkt nach dem Entladen
oder aus dem Depot. Er wartet, bis alle Loks voll sind (höchstens 30 s), und fährt dann weiter.
Ist gerade keine Tankstelle frei, bekommt ein knapper Zug keinen Auftrag, sondern wartet im
Depot; UTL versucht es alle 10 Sekunden erneut. Gibt es im Netzwerk **gar keine** UTL-Tankstelle
(z. B. weil du selbst per Interrupt oder von Hand tankst), fahren knappe Züge ganz normal.

Kleine und große Züge trennen: bei der Tankstelle für kleine Züge z. B. **max. Zuglänge 2**,
bei der für große **min. Zuglänge 3**. Die Tankstellen dürfen gleich heißen.

## Cleanup (Restladung)

Ein Zug mit Restladung fährt zur nächsten passenden **Cleanup-Station** und danach weiter
(nächster Auftrag oder zurück ins Depot). Das passiert, wenn

- ein Zug mit Ladung ins Depot kommt,
- eine Lieferung abgebrochen wurde (z. B. Station abgerissen),
- ein Zug beim Abnehmer nicht ganz leer wurde.

**Was eine Cleanup-Station annimmt**, stellst du im Fenster ein (Reiter „Werte“, Abschnitt
„Cleanup“), nicht über den Namen der Haltestelle:

- Schalter **Alle Items** und **Alle Flüssigkeiten** (Standard: beide an),
- oder einzelne Items und Flüssigkeiten in den Slots.

UTL plant daraus eine Route: Einzeln eingetragene Waren kommen vor „Alle …“; reicht eine
Station nicht (z. B. Kohle und Wasser im Zug), fährt der Zug mehrere Cleanups nacheinander an.
An jeder Station wartet er, bis die Waren dieser Station weg sind (höchstens 30 s ohne Bewegung,
falls die Kiste voll ist). Flüssigkeiten leerst du mit Pumpen am Wagen; „Alle Flüssigkeiten“
nur mit Abfluss, sonst mischen sie sich im Rohr.

Gibt es für eine Ware kein passendes, freies Cleanup, bleibt der Zug im Depot, es kommt die
Warnung „kein passendes Cleanup für [Ware]“, und UTL versucht es alle 10 s erneut.

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

Öffnen mit dem **Lok-Knopf in der Shortcut-Leiste** oder **Strg + Umschalt + U**.

- **Depots:** alle Depots mit freien/gesamten Zügen; pro Zug Zusammensetzung (z. B. `<LCCL>`),
  Zustand („Lädt bei …“, „Fährt tanken“ …) und Ladung.
- **Stationen:** Rolle, Angebot (grün) / Bedarf (rot), Unterwegs (blau = kommt, gelb = wird
  abgeholt), Anzahl Züge.
- **Netzwerke:** alle Netzwerke der Karte mit Stationszahl, freien Zügen und laufenden
  Lieferungen; rechts die Stationen des gewählten Netzes mit Rolle und der Angabe, ob sie dort
  ihr Heimatnetz haben oder nur als Zusatznetz mitarbeiten.
- **Inventar:** alles, was im Netz angeboten, angefordert und unterwegs ist. Klick auf eine
  Ware zeigt Stationen und Züge.
- **Verlauf:** die letzten 100 Lieferungen mit Laufzeit; abgebrochene stehen rot mit Grund.
- **Alarme:** die letzten 100 Warnungen zum Nachlesen (gleiche zusammengefasst, „×3“);
  „Zeigen“ springt zur Stelle. Enthält auch Warnungen, die du als Factorio-Alarm ausgeschaltet hast.
- Lupe = Suche nach Stationsnamen. Klick auf einen Stationsnamen zeigt die Station auf der
  Karte, Klick auf einen Zug verfolgt ihn.

Auch im Stationsfenster siehst du unter „Aktuell“ und „Unterwegs“, was gerade passiert.

## Warnungen

UTL meldet Probleme als normale Factorio-Warnungen (rechts unten; anklicken zeigt die Stelle):

| Gruppe | Wann |
|---|---|
| Kein passender Zug | Anfragen warten seit **5 Minuten** (Map-Einstellung) auf einen Zug. Fehlen freie Züge, gibt es **eine Sammelwarnung je Netzwerk** („37 Anfragen warten …“); passt kein freier Zug (Länge/Laderaum), warnt die einzelne Station. Solange ein Zug mit der Ware unterwegs ist, gilt die Anfrage als bedient. |
| Restladung und Fehlmenge | Zug mit Restladung im Depot, beim Abnehmer nicht leer geworden, beim Anbieter weniger geladen als bestellt. |
| Zugprobleme | Lieferzug findet keinen Weg, kein freies Depot gefunden, Tanken fehlgeschlagen, Lieferung abgebrochen. |

Jede Gruppe lässt sich pro Spieler abschalten: **Einstellungen → Mod-Einstellungen → Spieler**.
Dieselbe Warnung kommt höchstens alle 10 Sekunden.

## Registerkarte „Züge“

Schienen, Hochbahn, Signale, Haltestellen, Loks, Wagen und Zug-Combinators – auch aus anderen
Mods – bekommen eine eigene Registerkarte im Crafting-Menü. Abschaltbar in den
Start-Einstellungen.

## Map-Einstellungen

| Einstellung | Standard | Wirkung |
|---|---|---|
| Takt (Ticks) | 10 | Alle wie viele Ticks UTL arbeitet. Höher = weniger CPU. |
| Stationen pro Takt | 20 | So viele Stationen werden pro Takt gelesen, alle kommen reihum dran. |
| Neue Lieferungen pro Durchlauf | 2 | Höchstens so viele Züge pro Dispatcher-Durchlauf (alle 3 Takte, also bis zu 4 pro Sekunde). |
| Nur den Auftrag laden | an | Wagenfilter während einer Lieferung. Je Station abschaltbar. |
| Auftrags-Ausgabe an der Haltestelle | an | Der kleine Ausgang neben jeder Haltestelle. Aus: Er verschwindet. |
| Tanken unter (%) | 40 | Tankgrenze, 0 = aus. |
| Warnung „kein Zug“ nach (Minuten) | 5 | So lange darf eine Anfrage unbedient sein, bevor gewarnt wird. 0 = sofort. |
| Standard-Angebots-/Bedarfs-Schwelle | 1000 | Startwerte für neue Stationen. |
| Debug-Protokoll | aus | Zusätzliche Meldungen in `factorio-current.log`. |

## Leistung

Gemessen mit dem Lasttest-Szenario, headless (ohne Grafik, also ohne FPS):

| Netz | Messung | UTL pro Tick (Schnitt) | ganzes Spiel pro Tick (Schnitt) | Ticks unter 60 UPS |
|---|---|---|---|---|
| 9 × 9, 180 Züge, 340 Bahnhöfe | 40 min, ~1300 Lieferungen | 0,045 ms | – | 0 |
| 12 × 12, 384 Züge (davon 24 Flüssigkeit), 496 Bahnhöfe | 10 min | 0,067 ms | 3,6 ms | 36 von 36 000 |

UTL selbst hat Spitzen bis etwa 15 ms, wenn es Züge losschickt (das Losschicken löst die
Pfadsuche des Spiels aus). Den größten Teil der Zeit brauchen die Züge des Spiels selbst
(Bewegung und Pfadsuche).

**Wichtig:** Die Karte ist sonst **fast leer** – keine Fabrik, keine Bergbau-Bohrer, keine
Fließbänder, keine Beißer, nur Gleise, Bahnhöfe, Greifarme an Unendlich-Kisten, Masten und
Radare. In einem echten Spielstand kostet die Fabrik zusätzlich UPS und FPS; die Zahlen zeigen
also, was UTL und die Züge selbst brauchen, nicht die UPS einer ganzen Megabase.

## Szenarien zum Ausprobieren

**Neues Spiel → Szenarien → UTL-Beispiele (gemischter Anbieter)**: ein kleines Übungsnetz auf
Marcels Rundkurs mit Ausbuchtungen. Ein Anbieter hat Eisenplatten, Kupferplatten und Zahnräder in
drei Kisten mit drei Greifarmen, von denen die Auftrags-Ausgabe immer nur den freigibt, dessen
Ware gerade bestellt ist. Eine Werkstatt braucht Eisen **und** Kupfer und bekommt beides in
**einer** Fahrt. Beim Flüssigkeits-Anbieter stehen zwei Tanks, Öl und Wasser haben eigene Abnehmer, und die
Pumpen schaltet die **Auftrags-Ausgabe**. Dazu zwei Depots hintereinander, Tankstelle und Cleanup.
Zwei Züge, keine Messung – zum Anschauen.

## Lasttest-Szenario

**Neues Spiel → Szenarien → UTL-Lasttest (384 Züge)**: ein fertiges City-Block-Gitter (12 × 12,
4 Gleise je Korridor, Kreuzungen mit Kettensignalen). 5 Depots mit je 72 Zügen in reinen
Depot-Blöcken, dazu „Depot Flüssig“ mit 24 Flüssigkeitszügen; 496 Bahnhöfe mit Platz für je
3 Züge, Anbieter und Abnehmer gemischt, Rohöl und Petroleumgas mit Pumpen und Tanks,
16 Tankstellen und 6 Cleanups gleichmäßig verteilt; jede vierte Station ist eine normale
Haltestelle mit **UTL-Stations-Combinator**.

**Beim ersten Start dauert es einen Moment:** Das Szenario baut gut 48 000 Gleisstücke, 3 840
Signale, 880 Haltestellen und 384 Züge per Script. Je nach Rechner stockt das Spiel einige
Sekunden bis etwa eine Minute – das ist normal und passiert nur einmal. **Keine weiteren Mods
nötig**: Unendlich-Kisten, Unendlich-Rohre und Strom-Quellen gehören zum Grundspiel.

**Tipps für das eigene Netz:** Bahnhöfe auf Nebengleise legen, Warteplätze davor und „max. Züge“
passend setzen, vor jedem Abzweig ein Kettensignal, hinter jeder Einmündung Platz für einen
ganzen Zug, Depots gebündelt in einem Abstellbahnhof.

## Tipps & Tricks im Spiel

Im Menü **Tipps & Tricks** gibt es eine eigene Kategorie **Unified Train Logistics**: zwölf Einträge,
die die Bedienung erklären, jeder mit einer laufenden Beispielszene (teils mit geöffnetem
UTL-Fenster, Manager und Umschalt-Klick zum Kopieren). Darunter: eine UTL-Haltestelle mit Anbieter, Abnehmer und Depot;
dieselbe Strecke mit normalen Haltestellen und UTL-Stations-Combinatoren (Kabel sichtbar); und
ein Zug, der zuerst zur Tankstelle fährt und dann liefert; ein Zug mit Restladung, der erst an
der Cleanup-Station geleert wird; **zwei getrennte Netzwerke übereinander** mit Kamerafahrt. Dazu Erklärungen zu Rollen, Anforderungen, Werten und Netzwerk,
Depots, Einstellungen kopieren/Blaupausen und Manager.

## Häufige Fragen

- **Es fährt nur ein Zug.** Wahrscheinlich reicht einer: Der Zielbestand ist ein Bestand, keine
  Bestellung (siehe oben). Oder es gibt keine weiteren freien Züge – `/utl-status` zeigt
  „Züge im Depot“.
- **Ein Zug im Depot wird nicht benutzt.** Hat die Haltestelle die Rolle Depot? Ist der Zug
  leer und in Automatik? Passt seine Länge zu Anbieter und Abnehmer?
- **Ein Zug fährt nicht tanken.** Gibt es eine Tankstelle im selben Netzwerk, deren Zuglänge
  passt und die erreichbar ist?
- **Der Befehl `/utl-status`** zeigt Stationen, freie Züge und laufende Lieferungen.

## Noch nicht enthalten

Zeitlimits beim Laden/Entladen. Nachladen, während der Zug schon am Anbieter steht (die Ladeliste
steht beim Losschicken fest), und Einsammeln bei einem zweiten Anbieter auf dem Weg.

**Oberflächen (Space Age):** Jede Oberfläche arbeitet für sich. UTL bringt nur Stationen, Depots,
Tankstellen und Cleanups **derselben Oberfläche** zusammen. Auf Nauvis und auf Vulcanus brauchst
du also jeweils eigene Depots und eigene Züge. Lieferungen **zwischen** Oberflächen sind nicht
geplant – Züge können den Planeten nicht wechseln.

## Für Mod-Autoren

Remote-Schnittstelle `utl`: `station_count`, `get_station(unit)`,
`configure_station(unit, changes)`, `set_request(unit, slot, signal, count)`,
`copy_settings(from, to)`, `tag_blueprint(stack, mapping, surface)`, `idle_train_count`, `delivery_count`, `get_deliveries`, `get_alerts`.
