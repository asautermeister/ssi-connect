# Offene Punkte

GitHub-Issues sind für dieses Repository abgeschaltet, deshalb stehen
Fehler und Ideen hier. Erledigtes wird gelöscht – die Historie steht im
Git-Log.

## Fehler

### Jeder übertragene Tauchgang landet in SSI als Dekompressionstauchgang

*Gefunden mit v1.1.0 im Urlaub, betrifft offenbar alle Tauchgänge.*

**Symptom.** Beim Scannen eines von SSI Connect erzeugten QR-Codes trägt
die SSI-App den Tauchgang als Dekompressionstauchgang ein, auch wenn es
keiner war.

**Wahrscheinliche Ursache.** `SsiQrPayloadBuilder.build` hängt bei jedem
Tauchgang, für den Garmin `decoDive` meldet, ein `deco`-Feld an:

```dart
final isDecoDive = dive.isDecoDive;
if (isDecoDive != null) {
  fields.add('deco:${isDecoDive ? 1 : 0}');
}
```

Drei Belege dafür, dass das falsch ist:

1. **SSIs eigene Exporte enthalten kein `deco`.** Die beiden echten
   QR-Codes, gegen die das Format abgeglichen wurde (im Klassenkommentar
   von `lib/ssi/ssi_qr_payload_builder.dart` festgehalten), tragen weder
   `deco:0` noch `deco:1`.
2. **Die Bedeutung war nie beobachtet, nur abgelesen.** `deco` = `0` nein
   / `1` ja stammt aus einer SSI-Konfigurationsdatei, also aus einer
   Code-Tabelle. Der Klassenkommentar hält den Vorbehalt selbst fest:
   *„knowing a code is not the same as knowing the value"*. Genau dieser
   Fall ist eingetreten.
3. **Im SSI-Logbuch ist das Feld bei einem normalen Tauchgang leer, nicht
   `0`.** Aus einem echten `logbook_details`-Eintrag:
   `"odin_user_log_deco_dive": null`. SSIs App schreibt es also gar nicht
   erst.

Hypothese: Der Importer wertet schon die Anwesenheit des Schlüssels als
„Dekompressionstauchgang", unabhängig vom Wert.

**Vorgeschlagene Behebung.** `deco` nur senden, wenn es zutrifft – sonst
weglassen, wie SSIs eigener Export es tut. Das entspricht auch der Regel,
die im Payload-Builder ohnehin gilt („Empty fields are left out rather
than emitted blank"):

```dart
if (dive.isDecoDive == true) fields.add('deco:1');
```

**Erst verifizieren, dann beheben.** Der entscheidende Schritt ersetzt die
Hypothese durch eine Beobachtung:

1. In der SSI-App einen **echten** Deko-Tauchgang und einen normalen als
   QR-Code exportieren.
2. Beide mit dem eingebauten Diagnose-Werkzeug einlesen (Info → Version
   dreimal antippen → „SSI-Code prüfen"). Damit steht fest, ob SSI bei
   einem Deko-Tauchgang `deco:1` schreibt und bei einem normalen den
   Schlüssel weglässt.
3. Danach einen Tauchgang ohne `deco`-Feld übertragen und prüfen, ob er
   als normaler Tauchgang ankommt.

Schreibt SSI auch bei einem echten Deko-Tauchgang kein `deco`, ist das
Feld über den QR-Import gar nicht setzbar und gehört ganz heraus – dann
liegt die Ursache woanders, und die nächsten Verdächtigen wären
`dive_type` (wir senden `0`, echter Export ebenfalls `0`) und
`var_divetype_id` (wir senden `24`, Fun Dive).

**Mit zu ändern.** `test/ssi_qr_payload_builder_test.dart` erwartet heute
`deco:0`; dieser Test dreht sich mit. Bestätigt sich, dass `deco` nicht
setzbar ist, gehört es in der README zu den Feldern, die bewusst leer
bleiben – neben Wetter, Einstieg, Strömung und Sicht.

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

## Zu prüfen

### Garmins Tauchgangsnummern

*Merkposten – das genaue Symptom steht noch aus.*

Es gibt zwei Nummern, und sie kommen aus völlig verschiedenen Quellen:

**`Dive.diveNumber`** – die laufende Tauchgangsnummer des Tauchers, auf
dem Abzeichen als `# 42` zu sehen. Sie kommt von Garmin, und die Stelle,
die sie liest, hält den Vorbehalt selbst fest
(`lib/garmin/models/garmin_activity.dart`):

> „whether the activity-list endpoint passes it through – and under which
> name – is unconfirmed"

Gelesen werden vier Kandidaten: `diveNumber`, `diveNum`,
`summaryDTO.diveNumber`, `summaryDTO.diveNum`. Trifft keiner, bleibt das
Feld leer und die Anzeige blendet es aus. Genau das ist der wahrscheinliche
Fall, den es zu prüfen gilt: erscheint das `#` überhaupt, und wenn ja,
stimmt die Zahl mit der Uhr überein?

**`Dive.diveNumberOfDay`** – die Nummer innerhalb des Tauchtags („2. TG"),
von der App selbst berechnet (`assignDiveNumbersOfDay`), nicht von Garmin.
Wenn diese falsch ist, liegt es an der Gruppierung nach Kalendertag – etwa
bei einem Nachttauchgang über Mitternacht.

**Prüfweg.** Im Diagnose-Werkzeug (Info → Version dreimal antippen →
„API-Protokoll") steht eine `PROBE`-Zeile, die die tatsächlichen
Feldnamen einer Garmin-Antwort auflistet. Damit lässt sich in einem Schritt
klären, ob Garmin überhaupt eine Nummer mitschickt und unter welchem Namen.

**Neue Vergleichsquelle.** Seit dem Logbuch-Abgleich liegt auch SSIs eigene
Zählung vor: `odin_user_log_nr` in `logbook_details` (im Beispiel `1` und
`2`). Damit ließe sich die Anzeige gegen etwas Echtes halten – und, falls
Garmin gar keine Nummer liefert, wäre das eine mögliche Ersatzquelle für
Tauchgänge, die schon in SSI stehen.

## Ideen

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
