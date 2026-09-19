# Unified Train Logistics (UTL)

Automatischer Zugverkehr für Factorio 2.1: **Anbieter, Abnehmer, Depots, Tankstellen,
Cleanup und Übersichtsfenster in einem Mod** – so wie LTN mit LTN Manager, LTN Combinator
Modernized und LTN Cleanup zusammen, gebaut für hohe UPS.

*English version below.*

- Benötigt: Factorio 2.1, [flib](https://mods.factorio.com/mod/flib). Space Age ist optional.
- Freischalten: Technologie **„Unified Train Logistics“** (nach „Automatisierter
  Schienenverkehr“ und „Schaltungsnetze“).

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

Die Menge im Anforderungs-Slot ist der **Bestand, den du haben willst** (wie bei LTN).
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

**Netzwerk:** Stationen und Depots mit gleichem Netzwerknamen arbeiten zusammen. Leer = Standard.

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
„Cleanup“) – nicht über den Namen wie bei LTN Cleanup:

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

## Szenario zum Ausprobieren

**Neues Spiel → Szenarien → UTL-Lasttest (384 Züge)**: ein fertiges Netz aus einem City-Block-Gitter
(12 × 12 Blöcke, 4 Gleise je Korridor, Kreuzungen mit Kettensignalen, Radare). 5 Depots mit je 72 Zügen
liegen in reinen Depot-Blöcken ohne Bahnhöfe (6 Abstellbahnhöfe mit je 12 Gleisen), dazu
„Depot Flüssig“ mit 24 Flüssigkeitszügen; 496 Bahnhöfe an den Korridoren haben je Platz für 3 Züge
(Bahnsteig + 2 Warteplätze). Anbieter und Abnehmer liegen gemischt, Rohöl und Petroleumgas werden
mit Pumpen und Tanks geliefert, 16 Tankstellen und 6 Cleanup-Stationen sind gleichmäßig über die
Karte verteilt. Jede vierte Station ist eine
normale Haltestelle mit **UTL-Stations-Combinator** – so sieht man beide Bauarten nebeneinander.
Be- und Entladen mit echten Greifarmen an Unendlich-Kisten.

**Keine weiteren Mods nötig** – auch nicht der Kreativmod: Unendlich-Kisten, Unendlich-Rohre und
die Strom-Quellen gehören zum Grundspiel (nur im Baumenü versteckt), das Szenario setzt sie selbst.
Cleanup: 4 Stationen für alle Items, je eine nur für Rohöl bzw. Petroleumgas (mit Pumpen).

**Tipps für das eigene Netz** (daraus gelernt): Bahnhöfe auf Nebengleise legen, damit wartende
Züge die Strecke nicht blockieren; Warteplätze (Signal je Zuglänge) vor dem Bahnsteig und „max.
Züge“ bzw. Zuglimit passend setzen; vor jedem Abzweig ein Kettensignal; an Kreuzungen und
Wendeschleifen Kettensignale; hinter jeder Einmündung Platz für einen ganzen Zug bis zum nächsten
Signal; Depots gebündelt in einem Abstellbahnhof.

## Tipps & Tricks im Spiel

Im Menü **Tipps & Tricks** gibt es eine eigene Kategorie **Unified Train Logistics**: elf Einträge,
die die Bedienung erklären, jeder mit einer laufenden Beispielszene (teils mit geöffnetem
UTL-Fenster, Manager und Umschalt-Klick zum Kopieren). Darunter: eine UTL-Haltestelle mit Anbieter, Abnehmer und Depot;
dieselbe Strecke mit normalen Haltestellen und UTL-Stations-Combinatoren (Kabel sichtbar); und
ein Zug, der zuerst zur Tankstelle fährt und dann liefert; ein Zug mit Restladung, der erst an
der Cleanup-Station geleert wird. Dazu Erklärungen zu Rollen, Anforderungen, Werten und Netzwerk,
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

Zeitlimits beim Laden/Entladen und Lieferungen zwischen Oberflächen (Space Age). Diese Punkte
folgen.

## Für Mod-Autoren

Remote-Schnittstelle `utl`: `station_count`, `get_station(unit)`,
`configure_station(unit, changes)`, `set_request(unit, slot, signal, count)`,
`copy_settings(from, to)`, `tag_blueprint(stack, mapping, surface)`, `idle_train_count`, `delivery_count`, `get_deliveries`, `get_alerts`.

---
---

# Unified Train Logistics (UTL) – English

Automatic train logistics for Factorio 2.1: **providers, requesters, depots, fuel stations,
cleanup and an overview window in one mod** – like LTN with LTN Manager, LTN Combinator
Modernized and LTN Cleanup combined, built for high UPS.

- Requires: Factorio 2.1, [flib](https://mods.factorio.com/mod/flib). Space Age is optional.
- Unlock: technology **“Unified Train Logistics”** (after automated rail transportation and
  circuit network).

## Quick start

1. **Depot:** place a **UTL train stop**, open it, tick **Depot**.
2. **Train:** schedule with **only the depot stop** (any wait condition, e.g. inactivity 5 s),
   automatic mode. The train must be **empty**.
3. **Provider:** UTL train stop, tick **Provider**, wire a chest (red or green) **to the stop**.
   Inserters load the train.
4. **Requester:** UTL train stop, tick **Requester**. Click a **request slot**, pick an item,
   enter an amount (e.g. 8000 iron plates). Inserters unload the train.
5. Done: as soon as the requester is short enough, a free train goes depot → provider →
   requester → depot.

Tip: **Shift + right-click** a configured station and **Shift + left-click** another one to
copy all UTL settings (stop ↔ stop, combinator ↔ combinator). **Blueprints** and
Ctrl + C / Ctrl + V keep the settings as well.

## Two station types, same logic

- **UTL train stop:** replaces the normal stop (can be built over it). Wires go to the stop.
  The UTL panel opens to the left of the train stop window (tabs “Station” and “Values”).
- **UTL station combinator:** belongs to a normal train stop – wire its **output** (red or green) to the stop. Chest wires go to the
  combinator input. Own window. Neither needs power.

## Roles

**Provider** (positive signals are picked up), **Requester** (negative signals or request slots
are delivered), both = buffer, **Depot** (free trains wait here), **Fuel station**,
**Cleanup** (trains with leftover cargo are emptied here). Depot, fuel station and cleanup
exclude each other and provider/requester.

## Requests are a target stock

The amount in a request slot is the **stock you want to have** (like LTN). Only the difference
is delivered: *demand = target − in stock − already in transit*. A train is sent once the
demand reaches the **requester threshold**. Want several trains at once? Set a higher target.

## Values

Min./max. train length (0 = any; also for depots, see below), max. trains, supply threshold /
stack threshold, provider priority, locked slots per wagon, demand threshold / stack threshold,
requester priority. The grey ⟲ button resets a value. **Math works in every number field**:
`4000*2`, `8000/4`, `(1+2)*3`, `2^3`, `1e3`. Stations with the same **network** name work
together (empty = default).

## How trains run

- UTL **does not overwrite your schedule**: provider and requester are inserted as
  **temporary stops** that vanish after departure. **Train groups and interrupts** are kept.
- A rail waypoint in front of each stop makes the train use exactly that stop, even if several
  stops share the name.
- The train waits at the provider until the ordered amount is loaded, at the requester until
  it is empty.
- Selection: highest provider priority and amount, then a free train that carries as much as
  possible in one trip and is close; reachability is checked with the pathfinder.
- Reservations prevent several trains from being sent for the same demand.
- **Several items per train**, **fluids** (fluid wagons, one fluid per delivery) and **next job
  right away** after unloading or cleanup/fuel stations (map setting).

## Refueling

If **any** locomotive is below **40 %** (map setting “Refuel below (%)”), the train visits the
nearest matching **fuel station** – before its next job, right after unloading or from the
depot – and waits until all locomotives are full (max. 30 s). If no fuel station is free, a low
train gets no job and waits in the depot; UTL retries every 10 seconds. If the network has **no** UTL fuel station at all (you refuel via
interrupts or by hand), low trains run normally. Use min./max. train length on fuel stations to
separate small and large trains; the stations may share a name.

## Cleanup

Trains with leftover cargo (arriving at the depot with cargo, after a canceled delivery, or not
fully unloaded at the requester) go to the nearest matching **cleanup station**. What a cleanup
station accepts is set in its window ("Values" tab, "Cleanup" section – not via the name as in
LTN Cleanup): **All items** and **All fluids** switches (both on by default) or single items and
fluids. Goods entered one by one come before "All …"; if one station is not enough, the train
visits several in a row and waits at each until its goods are gone (max. 30 s without change).
Empty fluids with pumps; use "All fluids" only with a drain, fluids mix in pipes. Without a
fitting free cleanup, the train waits in the depot with the alert "no fitting cleanup for
[good]" and UTL retries every 10 s.

## Depots and train length

Free trains wait **empty** at stops with the **Depot** role – **every** depot stop needs the
role, the name alone is not enough; a train that ends up at a stop with a depot's name but
without the role (also vanilla stops) moves on to a free real depot of that name. If a train
arrives at a depot whose min./max. length does
not fit, it moves to a **free matching depot with the same name**; if there is none, it stays
and remains available.

## UTL Manager

Open with the **locomotive button in the shortcut bar** or **Ctrl + Shift + U**. Tabs:
**Depots** (trains with composition, status, cargo), **Stations** (role, provided/requested,
in transit, trains), **Inventory** (network totals; click an item for details), **History**
(last 100 deliveries, canceled ones in red), **Alerts** (last 100 alerts, repeats merged). Search by station name; click a station to view it
on the map, click a train to follow it.

## Alerts

UTL reports problems as regular Factorio alerts (bottom right; click to see the spot) in three
groups: **no suitable train** (only after a request has been unserved for 5 minutes – map
setting – and no train with the item is on its way), **leftover/missing cargo**, **train problems** (no path, no free
depot, refueling failed, delivery canceled). Each group can be turned off per player in
**Settings → Mod settings → Per player**. The same alert repeats at most every 10 seconds.

## Trains tab

Rails, elevated rails, signals, stops, locomotives, wagons and train combinators – also from
other mods – get their own crafting tab (startup setting).

## Map settings

Heartbeat (10 ticks), stations per heartbeat (20), new deliveries per cycle (2), refuel below
(40 %), “no train” alert after (5 minutes), default supply/demand threshold (1000), debug log (off).

## Performance

Measured headless (no graphics, so no FPS) with the load test scenario:

| Network | Run | UTL per tick (avg.) | whole game per tick (avg.) | ticks below 60 UPS |
|---|---|---|---|---|
| 9 × 9, 180 trains, 340 stations | 40 min, ~1300 deliveries | 0.045 ms | – | 0 |
| 12 × 12, 384 trains (24 fluid), 496 stations | 10 min | 0.067 ms | 3.6 ms | 36 of 36,000 |

UTL itself peaks at about 15 ms when it sends trains (sending triggers the game's pathfinding).
Most of the time is spent by the game's own trains (movement and pathfinding).

**Important:** the map is otherwise **almost empty** – no factory, no mining drills, no belts, no
biters, just rails, stations, inserters at infinity chests, poles and radars. In a real save the
factory costs extra UPS and FPS; the numbers show what UTL and the trains themselves need, not the
UPS of a whole megabase.

## Scenario

**New game → Scenarios → UTL load test (384 trains)**: a ready-made city-block grid (12 × 12, 4
tracks per corridor, chain-signalled crossings, radars); 5 depots with 72 trains each in depot-only
blocks (6 yards with 12 tracks) plus "Depot Flüssig" with 24 fluid trains; 496 stations with room
for 3 trains each (platform + 2 waiting spots), providers and requesters mixed, crude oil and
petroleum gas with pumps and tanks, 16 fuel and 6 cleanup stations spread evenly;
every fourth station is a normal stop with a **UTL station combinator**; real inserters at
infinity chests. Cleanup: 4 stations for all items, one each only for crude oil / petroleum gas
(with pumps). **No other mods needed** – not even Creative Mod: infinity chests, infinity pipes and
the power sources are part of the base game (only hidden in the build menu); the scenario places
them itself.

## Tips & tricks

The in-game **Tips & tricks** menu has a **Unified Train Logistics** category: eleven entries
explaining how to use the mod, each with a running example scene (some with an open UTL window,
the manager and shift-click copying), among them: a UTL stop with provider, requester and depot; the same
line with normal stops and UTL station combinators (wires visible); a train that refuels
first and then delivers; a train with leftover cargo that is emptied at a cleanup station first.
Plus explanations of roles, requests, values and network, depots, copying settings/blueprints and
the manager.

## FAQ

- **Only one train runs:** one is probably enough (target stock, see above), or there are no
  more free trains – `/utl-status` shows “trains in depot”.
- **A depot train is not used:** does the stop have the Depot role? Is the train empty and in
  automatic mode? Does its length fit provider and requester?
- **A train does not refuel:** is there a reachable fuel station in the same network whose
  train length fits?

## Not yet included

Loading/unloading timeouts, deliveries between surfaces (Space Age).

## For mod authors

Remote interface `utl`: `station_count`, `get_station(unit)`, `configure_station(unit, changes)`,
`set_request(unit, slot, signal, count)`, `copy_settings(from, to)`, `tag_blueprint(stack, mapping, surface)`, `idle_train_count`,
`delivery_count`, `get_deliveries`, `get_alerts`.
