# Offene Punkte

GitHub-Issues sind für dieses Repository abgeschaltet, deshalb stehen
Fehler und Ideen hier. Erledigtes wird gelöscht – die Historie steht im
Git-Log.

## Fehler

### Der zugeordnete Tauchplatz wird nicht gespeichert

Nichts sieht kaputt aus, aber eine ausdrückliche Entscheidung geht
verloren: der Platz, den man einem Tauchgang zuordnet, lebt nur im State
der Detailansicht (`DiveDetailScreen`, `DiveSite? _site`). Es gibt keine
Ablage pro Tauchgang.

**Zwei Folgen, die zweite wiegt schwerer:**

1. **Bildschirm verlassen, zurückkommen – weg.** In der Praxis kaum zu
   merken, weil der Umkreis-Vorschlag wieder dasteht und ein Tipp genügt.
   Ärgerlich wird es bei einem Platz, den man von Hand eingetragen und
   nicht über den Vorschlag bestätigt hat.
2. **Der Tauchtag am Stück überträgt überhaupt keinen Platz.**
   `DiveQrBatchScreen` ruft den Payload-Builder ohne `site` auf, kann es
   auch gar nicht anders – der Platz steht nirgends, wo dieser Bildschirm
   ihn herbekäme. Ausgerechnet der Weg, der für den Bootstag gebaut wurde,
   liefert also `site:` nie mit.

**Gemeinsame Wurzel, eine Behebung.** Eine Zuordnung `Tauchgangs-ID →
Platznummer` im verschlüsselten Speicher, wie sie für den
Übernahme-Haken schon existiert (`ExportedDivesRepository` ist die
Vorlage). Die Detailansicht liest und schreibt daraus, der Tauchtag-Export
liest nur.

**Beim Bauen aufpassen:** Der Umkreis-Vorschlag bleibt ein Vorschlag. Ein
gespeicherter Platz gewinnt gegen ihn, und ein von Hand entfernter darf
nicht beim nächsten Öffnen wieder auftauchen – dieselbe Vorrang-Regel wie
beim Übernahme-Haken.

**Nebeneffekt, wenn es liegt:** Damit wäre auch ein Filter „ohne
Tauchplatz" auf der Tauchgangs-Liste möglich, der heute nicht geht, weil
niemand weiß, welche Tauchgänge einen haben.

## Ideen

### Das Übertragen mehrerer Tauchgänge neu zugänglich machen

Der Weg dorthin ist ausgebaut – das Auswahl-Symbol in der Tauchgangs-Liste
war umständlich zu bedienen, und an dieser Stelle sitzt jetzt der Filter.
Die Funktion selbst steht noch: `DiveExportSelectionScreen` und
`DiveQrBatchScreen` sind unverändert da, mit Tests, nur ohne Einstieg. Was
neu gedacht werden muss, ist der Zugang, nicht der Export.

**Warum der alte Weg nicht getaugt hat.** Er begann mit einer Frage, die
man an dieser Stelle nicht hat: „welche Tauchgänge?" – auf einem
Bildschirm, der die Liste noch einmal zeigt, diesmal mit Kästchen.
Naheliegender wäre der umgekehrte Weg: aus dem Tauchtag heraus, den man
ohnehin gerade ansieht.

**Denkbare Einstiege:**

* Langes Drücken auf einen Tauchgang schaltet die Liste in einen
  Auswahl-Modus – das gewohnte Muster für „mehrere davon".
* Ein „ganzen Tauchtag übertragen" in der Detailansicht, wo der Tauchtag
  schon feststeht.

**Nicht vergessen:** Der Tauchtag-Export überträgt keinen Tauchplatz
(siehe „Der zugeordnete Tauchplatz wird nicht gespeichert"). Solange das
so ist, liefert ausgerechnet der Weg für den Bootstag weniger als der
einzelne QR-Code – das gehört behoben, bevor der Einstieg wieder
prominent wird.

### Den SSI-Bereich neu ordnen, und den Abgleich aus den Einstellungen holen

Der SSI-Teil ist heute auf drei Orte verteilt, ohne dass einer davon der
offensichtliche wäre:

* die **Anmeldung** beim jeweiligen Account („SSI-Identität"),
* der **Abgleich** samt Zahlen und Zeitstempel unter „Einstellungen →
  SSI-Logbuch",
* die **Buddy-Liste** als eigener Eintrag auf der Startseite.

Der Abgleich in den Einstellungen ist dabei der klarste Fehlgriff: er ist
keine Einstellung, sondern das Abholen von Daten. Er gehört dorthin, wo
ohnehin Daten geholt werden – an den normalen Tauchgangs-Abruf, mit
demselben Zwischenspeicher-Verhalten wie dort: erst zeigen, was da ist,
dann im Hintergrund auffrischen.

**Was dafür schon liegt.** `RecentDivesController` macht das für Garmin
bereits vor (Cache zuerst, dann Aktualisierung, sichtbarer Stand-Hinweis).
Und `SsiSyncController` speichert seit dem Zeitstempel-Eintrag bereits
`lastSyncAt` dauerhaft – das ist genau die Angabe, an der sich entscheiden
lässt, ob ein Abgleich fällig ist.

**Beim Bauen zu klären:**

1. **Wie oft.** Ein Logbuch ändert sich selten; bei jedem App-Start
   abzugleichen wäre Verschwendung und würde die Startseite ausbremsen.
   Naheliegend: höchstens einmal am Tag, plus beim Herunterziehen zum
   Aktualisieren.
2. **Ein Fehlschlag darf die Tauchgangsliste nicht anfassen.** Garmin-Abruf
   und SSI-Abgleich sind unabhängig. Schlägt SSI fehl, muss die Liste
   normal aussehen – der Hinweis gehört an eine ruhige Stelle, so wie es
   der Offline-Hinweis heute vormacht.
3. **Was in den Einstellungen bleibt.** Die Zahlen und der Zeitpunkt des
   letzten Abgleichs sind dort weiterhin richtig aufgehoben; ein
   „Jetzt abgleichen" darf als Notausgang bleiben, nur eben nicht als
   einziger Weg.

**Nebeneffekt, der es lohnender macht als es klingt.** Der automatische
Übernahme-Haken hängt daran, wie aktuell das Logbuch ist. Solange der
Abgleich ein Knopf in den Einstellungen ist, den man vergisst, sind die
grünen Haken älter als die Tauchgänge daneben.

### Tauchgangs-Position auf einer OSM-Karte in der Detailansicht

Die Koordinaten liegen schon vor (`Dive.latitude`/`longitude`, aus Garmins
Oberflächen-Fix) und stehen heute nur als Zahlenpaar im Dialog „Tauchplatz
zuordnen". Eine kleine Karte in der Detailansicht wäre anschaulicher – und
besonders nützlich beim Umkreis-Vorschlag: Tauchgang und vorgeschlagener
Platz nebeneinander auf einer Karte beantworten die Frage „ist das der
richtige Platz?" schneller als eine Entfernung in Metern.

Der übliche Weg in Flutter ist `flutter_map` mit OSM-Kacheln – im
Gegensatz zu Google Maps ohne API-Schlüssel, was für ein sideload-
verteiltes Projekt der passendere Weg ist.

**Drei Punkte, die vorher geklärt sein wollen:**

1. **Es wäre der erste Dritte, der etwas von uns erfährt.** Bisher spricht
   die App ausschließlich mit Garmin und SSI. Eine Kachel anzufordern
   verrät dem Kachel-Server, wo dieser Tauchgang war – das ist derselbe
   Grund, aus dem die Umkreis-Suche über SSIs Website verworfen wurde. Kein
   Ausschlusskriterium, aber eine bewusste Entscheidung und ein Fall für
   die README.
2. **OSMs öffentliche Kachel-Server haben eine Nutzungsrichtlinie**, die
   Apps ohne Absprache ausdrücklich nicht vorsieht. Für eine verteilte App
   gehört also entweder ein Anbieter mit passenden Bedingungen dazu oder
   eine Rückfrage – der Kartenhinweis („© OpenStreetMap-Mitwirkende")
   ohnehin.
3. **Offline.** Die App ist bewusst ohne Netz benutzbar; eine Karte ist es
   nicht. Sie braucht denselben ruhigen Umgang damit wie der Rest – ein
   Platzhalter statt eines Fehlers, und die Koordinaten weiterhin als Text,
   damit ohne Netz nichts fehlt.

Nur für Tauchgänge mit Position sinnvoll – ohne Fix bleibt es beim heutigen
Hinweis.

### Fortschrittsbalken für den Tauchplatz-Abgleich

Der Abgleich zeigt heute einen `LinearProgressIndicator` ohne Wert – er
läuft also nur hin und her und sagt nichts darüber, wie weit er ist. Bei
mehreren verbundenen Konten und einem großen Logbuch dauert das lange
genug, dass man sich fragt, ob noch etwas passiert.

Ein Teil der Verkabelung liegt schon da: `SsiSyncController` hat
`busyAccountId`, gedacht genau dafür, dass eine Zeile ihren eigenen
Fortschritt zeigt. `syncAll` setzt das Feld aber auf `null` und arbeitet
die Konten stumm ab – benutzt wird es bisher nur beim Anmelden.

Naheliegend wäre, `syncAll` das gerade bearbeitete Konto melden zu lassen
und daraus „Konto 2 von 3" plus einen Balken mit Wert zu bauen. Feiner
ginge es auch – ein Logbuch kommt in einem Aufruf, also ließe sich der
Fortschritt innerhalb eines Kontos nur schätzen, nicht messen. Über die
Konten zu zählen ist ehrlich und reicht.

### Tauchplätze zwischen Geräten teilen

Ein Tauchplatz ließe sich als QR-Code anzeigen und von einem zweiten
Gerät einlesen, so wie es die Buddy-Liste schon kann. Nützlich für ein
zweites Familien-Tablet ohne SSI-Anmeldung.

### CI-Workflow für Pull Requests

Heute laufen `flutter analyze` und die Tests nur beim Release. Ein
Workflow, der bei jedem Pull Request läuft, wäre Voraussetzung dafür, im
Ruleset für `master` einen Status-Check zu verlangen.
