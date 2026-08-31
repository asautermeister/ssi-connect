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

### Herkunft eines Buddy-Eintrags

*Später nochmal ansehen.*

Bei 41 importierten Mittauchern beantwortet heute nichts die Frage „wer
ist das, und warum steht der hier?". Die Antwort wäre oft: weil er im
Logbuch einer anderen Person auf diesem Gerät stand.

**Nicht an `SsiBuddyCode` anbauen.** Der Typ ist das Drahtformat — er wird
aus QR-Codes geparst, in QR-Codes gerendert und dient als Identität eines
Accounts. Herkunftsdaten dort hinein hieße, dass ein angezeigter QR-Code
Felder mit sich trägt, die niemanden außerhalb dieses Geräts angehen.
Stattdessen ein Speicher-Typ darum herum:

```dart
enum BuddySource { logbook, scanned, byHand, unknown }

class StoredBuddy {
  final SsiBuddyCode code;
  final BuddySource source;
  final String? fromAccountId;   // nur bei logbook: wessen Logbuch
  final DateTime? addedAt;
}
```

Auf der Karte eine leise Zeile, nur wo bekannt: „Aus dem Logbuch von
Andreas" · „Abgescannt" · „Von Hand". **Bestehende Einträge bekommen
`unknown` und zeigen gar nichts** — lieber schweigen als eine Herkunft
erfinden. Das ist zugleich die Migration.

**Was damit möglich würde, aber eigene Entscheidungen sind:** beim
Entfernen eines Garmin-Accounts anbieten, die Mittaucher mitzunehmen, die
nur aus dessen Logbuch stammen; und ein Filter „nur meine".

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
