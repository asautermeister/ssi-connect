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

### Tauchplätze zwischen Geräten teilen

Ein Tauchplatz ließe sich als QR-Code anzeigen und von einem zweiten
Gerät einlesen, so wie es die Buddy-Liste schon kann. Nützlich für ein
zweites Familien-Tablet ohne SSI-Anmeldung.

### CI-Workflow für Pull Requests

Heute laufen `flutter analyze` und die Tests nur beim Release. Ein
Workflow, der bei jedem Pull Request läuft, wäre Voraussetzung dafür, im
Ruleset für `master` einen Status-Check zu verlangen.
