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

> **Stand der Tests.** UTL läuft durch einen automatischen Selbsttest (122 Prüfungen) und einen
> headless-Lasttest mit 384 Zügen auf 12 × 12 City Blocks; Updates werden geprüft, indem ein
> Spielstand der Vorversion geladen wird. Die wichtigsten Funktionen zeigen die Szenarien. Im
> echten Spiel ist UTL bisher in kleinen Netzen gelaufen. Am neuesten: **Lager** und **Cleanup gibt
> zurück** (0.0.8), **Nachladen** (0.0.7, Standard aus) und die **Team-Trennung** (0.0.6, im echten Mehrspieler noch nicht erprobt). Wenn
> etwas schiefgeht: bitte in der [Diskussion](https://mods.factorio.com/mod/UTLogistics/discussion)
> melden, am besten mit Spielstand und dem, was du gemacht hast. Vor dem Einsatz in einem
> gewachsenen Spielstand vorher sichern.

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
oder aus dem Depot. Er wartet, bis alle Loks voll sind oder sich 30 s nichts mehr tut, und fährt dann weiter.
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
falls die Kiste voll ist). Flüssigkeiten leerst du mit Pumpen am Wagen in einen Lagertank – je Flüssigkeit ein eigenes
Cleanup, denn ein Tank fasst nur eine Sorte; mit „Alle Flüssigkeiten“ fließt jede andere Sorte
nicht ab, und der Zug fährt nach 30 s weiter.

Gibt es für eine Ware kein passendes, freies Cleanup, bleibt der Zug im Depot, es kommt die
Warnung „kein passendes Cleanup für [Ware]“, und UTL versucht es alle 10 s erneut.

**Cleanup gibt zurück.** Was im Cleanup landet, muss dort nicht bleiben: Mit dem Häkchen **„Inhalt
wieder anbieten“** bietet eine Cleanup-Station ihren Kisteninhalt dem Netz an, wie ein Anbieter
(die Kisten müssen an der Haltestelle hängen). Die Stufe wählst du: **nur als Reserve** (normale
Anbieter gehen vor), **wie ein normaler Anbieter** oder **zuerst leeren** (vor jedem normalen
Anbieter). Was bei einem Abnehmer übrig blieb, bringt UTL diesem Abnehmer 5 Minuten lang nicht
zurück – so fährt nichts im Kreis. Die Map-Einstellung **„Cleanup darf Inhalt wieder anbieten“**
schaltet es auf der ganzen Karte ab.

## Lager (für Fortgeschrittene)

*Braucht die Forschung „UTL: Lager“.*

Ein **Lager** ist ein Bahnhof, der annimmt **und** abgibt – ein Puffer nahe bei den Verbrauchern.
Rolle **Lager** wählen und je Ware einen **Mindest-** und einen **Höchstbestand** einstellen (bis zu
acht Waren):

- **unter Mindest** fordert es an – und zwar bis Höchst, damit es sich nicht in vielen kleinen
  Fahrten auffüllt;
- **über Mindest** bietet es an, was über dem Mindest liegt – **wie ein normaler Anbieter**: bei
  gleicher Menge liefert der nähere, bei gleichem Abstand geht ein normaler Anbieter vor.

Zwei Lager schieben sich Ware nie hin und her: angeboten wird nur, was über dem Mindest liegt,
angefordert nur unter dem Mindest. Die allgemeinen Angebots- und Bedarfs-Schwellen gelten hier
nicht – Mindest und Höchst sind die Schwellen. Mit **„Restladung annehmen“** (Standard: an) dürfen
Züge hier auch Reste abladen, wie an einem Cleanup; Waren ohne Grenzen bietet das Lager ganz an,
aber nur als Reserve. Die Map-Einstellung **„Lager-Stationen erlauben“** schaltet Lager auf der
ganzen Karte ab.

### Annehmen und abgeben am selben Bahnhof

Ein Lager (oder ein Cleanup, der zurückgibt) braucht Greifarme in beide Richtungen. Die übliche
Vanilla-Bauweise, alles auf einer Gleisseite: **Entlade-Greifarm** (Wagen → Kiste) → **Umlade-Greifarm**
(Kiste → Kiste) → **Lade-Greifarm** (Kiste → Wagen). Die Auftrags-Ausgabe an Entlade- und
Lade-Greifarme verdrahten und als Bedingung setzen: Lade-Greifarme **[utl-loading] > 0**,
Entlade-Greifarme **[utl-loading] = 0**. Die Auftrags-Ausgabe meldet **„Zug lädt hier“** und **„Zug
entlädt hier“**, solange ein Lieferzug an der Haltestelle steht; Restladung hat keinen Auftrag und
wird mit „= 0“ ebenfalls entladen. Das Szenario „UTL-Lager“ zeigt es.

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
zeigt Details), **Verlauf** (letzte 100 Lieferungen), **Alarme** (letzte 100), **Einstellungen**. Suche
nach Stationsnamen, Klick auf eine Station zeigt sie auf der Karte, Klick auf einen Zug verfolgt ihn.
Mit Space Age wählt eine Auswahl den Planeten.

**Warnungen** kommen als normale Factorio-Warnungen in drei Gruppen – kein passender Zug (nach
5 Minuten), Restladung/Fehlmenge, Zugprobleme – jede je Spieler abschaltbar.

Mehr: [Wiki – UTL-Manager und Warnungen](https://github.com/Marcel1853/UTLogistics/wiki/UTL-Manager-und-Warnungen).

## Map-Einstellungen

Die wichtigsten: **Direkt der nächste Auftrag** (an), **Nur den Auftrag laden** (an, Wagenfilter),
**Auftrags-Ausgabe an der Haltestelle** (an), **UTL-Funktionen brauchen Forschung** (an), **Tanken
unter** (40 %), **Inaktivität beim Laden / Entladen** (je 30 s), mit der Fracht verknüpft per **oder**
(Standard: auch fahren, wenn sich so lange nichts getan hat – mit dem, was drin ist) oder **und**,
**Nachladen, während der Zug lädt** (aus), **Cleanup darf Inhalt wieder anbieten** (an),
**Lager-Stationen erlauben** (an).

Die Lade-Werte lassen sich auch im **UTL-Manager, Reiter „Einstellungen“** ändern – mit Teams hat
jedes Team eigene Werte, verwaltet von Team-Leitern; Admins öffnen mit **`/utl-admin`** jedes Team.
Eine Start-Einstellung gibt Schienen, Haltestellen, Loks, Wagen und Zug-Combinators (auch aus anderen
Mods) eine eigene Registerkarte **„Züge“** im Crafting-Menü.

Alle Einstellungen mit Standardwerten, Teams und Leitern: [Wiki – Einstellungen](https://github.com/Marcel1853/UTLogistics/wiki/Einstellungen).

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

**Neues Spiel → Szenarien** (alles erforscht, Cheat-Modus an, Anzeigefelder mit Erklärungen):

- **UTL-Beispiele (gemischter Anbieter)** – gemischter Anbieter mit Auftrags-Ausgabe, zwei Waren in
  einer Fahrt, Öl und Wasser über geschaltete Pumpen.
- **UTL-Netzverbund** – vier Netze, ein Stern mit einem Partner ohne eigene Züge.
- **UTL-Teams** – vier Teams mit gleichen Stations- und Netznamen; `/utl-team rot` wechselt.
- **UTL-Nachladen (zum Anschauen)** – mit und ohne Nachladen, Runde für Runde, mit Erklärfenster.
- **UTL-Lager (zum Anschauen)** – neu in 0.0.8: ein **Lager** mit Lade- und Entlade-Greifarmen auf
  einem Rundkurs mit zwei Zügen, ein **Cleanup, der zurückgibt**, und vier kleine Beispiel-Strecken
  (zwei Lager, Lager nimmt Restladung, Cleanup-Stufen im Vergleich, Lager mit zwei Waren). Ein Fenster
  erklärt jeden Teil.
- **UTL-Planeten-Test (Space Age)** – dasselbe Netz auf Nauvis, Vulcanus und Gleba.
- **UTL-Lasttest (384 Züge)** – ein 12 × 12-City-Block-Gitter zum Messen; der erste Start baut es per
  Script und dauert bis zu einer Minute.

Einzelheiten und Bilder: [Wiki – Szenarien und Tipps](https://github.com/Marcel1853/UTLogistics/wiki/Szenarien-und-Tipps).

## Tipps & Tricks im Spiel

Im Menü **Tipps & Tricks** gibt es eine eigene Kategorie **Unified Train Logistics** mit siebzehn
Einträgen, jeder mit laufender Beispielszene – von der ersten Lieferung über Netzwerke, Cleanup gibt
zurück und Lager bis zum Manager.

Nach einem Update schreibt UTL einmal eine kurze Zeile mit dem Wichtigsten in den Chat; der Link
darin öffnet die Tipps-&-Tricks-Seite **„Neu in UTL“**. Je Spieler abschaltbar: *Update-Hinweise im
Chat*.

## Häufige Fragen

- **Es fährt nur ein Zug.** Wahrscheinlich reicht einer: Der Zielbestand ist ein Bestand, keine
  Bestellung (siehe oben). Oder es gibt keine weiteren freien Züge – `/utl-status` zeigt
  „Züge im Depot“.
- **Ein Zug im Depot wird nicht benutzt.** Hat die Haltestelle die Rolle Depot? Ist der Zug
  leer und in Automatik? Passt seine Länge zu Anbieter und Abnehmer?
- **Ein Zug fährt nicht tanken.** Gibt es eine Tankstelle im selben Netzwerk, deren Zuglänge
  passt und die erreichbar ist?
- **Der Befehl `/utl-status`** zeigt Stationen, freie Züge und laufende Lieferungen.

Fehlersuche Schritt für Schritt: [Wiki – Häufige Fragen und Fehlersuche](https://github.com/Marcel1853/UTLogistics/wiki/Häufige-Fragen-und-Fehlersuche).

## Teams und Oberflächen

Beides ist enthalten, beides trennt UTL sauber:

- **Teams (Forces):** Jedes Team arbeitet für sich. Züge, Depots, Tankstellen und Cleanups nehmen
  nur Stationen des eigenen Teams, Netzverbindungen gelten je Team, und der Manager zeigt nur das
  eigene Team. Zwei Teams dürfen dieselben Netz- und Stationsnamen benutzen, ohne sich zu stören.
  Ausprobieren: Szenario „UTL-Teams“.
- **Oberflächen (Space Age):** Jede Oberfläche arbeitet für sich. Zusammengebracht wird nur, was
  auf **derselben** Oberfläche steht – Nauvis und Vulcanus brauchen also jeweils eigene Depots und
  eigene Züge. Lieferungen **zwischen** Oberflächen wird es nicht geben: Züge können den Planeten
  nicht wechseln.

## Nachladen (abschaltbar, Standard aus)

Wächst der Bedarf eines Abnehmers, während ein Zug für ihn noch zum Anbieter fährt oder dort lädt,
kommt die Menge auf die **laufende Ladeliste** statt in eine zweite Fahrt. Bedingung: derselbe
Anbieter hat die Ware noch frei, und im Zug ist Platz. Items dürfen dazukommen, bei Flüssigkeiten
nur dieselbe Sorte.

Das spart Züge, hält den Zug aber länger am Anbieter – deshalb ist es abschaltbar und **von Haus
aus aus**. Einschalten in den Karteneinstellungen oder im Manager unter „Einstellungen“:
*Nachladen, während der Zug lädt*. Wer es auslässt, merkt keinen Unterschied zu vorher.
Zum Anschauen: Szenario „UTL-Nachladen“.

## Noch nicht enthalten

Einsammeln bei einem zweiten Anbieter auf dem Weg (eine Fahrt holt bisher bei genau einem
Anbieter ab).

## Für Mod-Autoren

Remote-Schnittstelle `utl` (Stationsdaten, Lieferungen, Warnungen, Stationen und Anforderungen
einstellen, Netzverbindungen, Team- und Kartenwerte, per Script erstellte Blaupausen taggen):
[Wiki – Für Mod-Autoren](https://github.com/Marcel1853/UTLogistics/wiki/Für-Mod-Autoren).
