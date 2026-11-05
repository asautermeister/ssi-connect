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

## Aufräumen und Härten

Aus einem Durchgang durch den ganzen Code am 23.10.2026, einmal auf
Sicherheit (an OWASP entlang) und einmal auf Überflüssiges. **Nichts
davon ist kritisch**, und vieles ist ausdrücklich in Ordnung: keine
TLS-Overrides, kein Cleartext-Traffic, keine ATS-Ausnahme, der
Cookie-Jar nur im Speicher, `Authorization`-Header nie im Log, nur die
Kamera-Berechtigung, und alle sieben Ablagen ohne Ausnahme über
`FlutterSecureStorage`.

Erledigt und deshalb hier nicht mehr aufgeführt: das fehlende Escaping
der QR-Payloads, die Personendaten Dritter im API-Log, `allowBackup` und
vier nicht mehr aufgerufene Member. Steht im Git-Log.

### Built-in Kotlin ist umgestellt

Erledigt: Flutter 3.47.8, `android.builtInKotlin=true` und
`mobile_scanner` ^7.4.2. Kein Plugin wendet das Kotlin-Gradle-Plugin
mehr an, AGP 9 übersetzt alles Kotlin selbst, die Warnung beim Start ist
weg.

**Die KGP-Deklaration in `android/settings.gradle.kts` muss trotzdem
bleiben.** Sie wurde einmal entfernt, weil sie niemand mehr anwendet –
und der Build brach sofort: die Zeile legt zugleich die Kotlin-Version
des Projekts fest, und der Flutter-Gradle-Plugin prüft die. Ohne sie
greift die Version, die AGP 9.0.1 mitbringt (2.2.10), und die liegt
unter Flutters Minimum von 2.2.20. `apply false` heißt eben nicht
„wirkungslos".

Drei Dinge, die beim nächsten Gradle-Ärger Zeit sparen:

- Flutters Warnung über Plugins, die KGP anwenden, ist ein **rein
  textueller Scan** über die Build-Skripte der Plugins
  (`FlutterPluginUtils.kt`, dort ausdrücklich begründet). Sie wertet
  keine Bedingung aus: `mobile_scanner` 7.4.0 trug ein
  `apply plugin: 'kotlin-android'` in einem `if`, das nicht mehr zutraf,
  und wurde trotzdem gemeldet. Eine Warnung beweist also nicht, dass KGP
  wirklich angewendet wird – und ihr Ausbleiben nicht das Gegenteil.
- Scheitert der Build, hängt Flutter eine Box über `android.newDsl` an.
  Die erschien auch beim Kotlin-Versionsfehler, mit dem sie nichts zu
  tun hatte. Erst die Zeile unter „What went wrong" lesen.
- Der Gradle-Wrapper steht auf **9.7.1**, Flutter kennt als höchste
  unterstützte Version **9.3.1** – in 3.44 wie in 3.47. Läuft
  offensichtlich, ist aber ungeprüftes Gebiet und wäre bei merkwürdigem
  Verhalten der erste Verdacht.

### Kleinigkeiten an der Plattform-Konfiguration

- **Secure Storage: der Paket-Default ist richtig, nicht zu „härten".**
  Hier stand vorher die Empfehlung, `encryptedSharedPreferences: true`
  explizit zu setzen – **das wäre falsch gewesen.** In der eingesetzten
  Version 10.3.1 verschlüsselt der Default auf Android bereits mit
  AES-GCM und einem RSA-OAEP-gewickelten Schlüssel aus dem
  Android-Keystore, und `encryptedSharedPreferences` ist ausdrücklich
  deprecated und fliegt in v11 raus. Auf iOS ist der Default
  `KeychainAccessibility.unlocked` mit `synchronizable: false`, also
  lesbar nur bei entsperrtem Gerät und nicht in der iCloud.
  Die einzige verbleibende Schraube wäre `unlocked_this_device`, womit
  ein verschlüsseltes iTunes-Backup die Einträge nicht auf ein anderes
  Gerät tragen könnte. Kleine Verbesserung, aber **ungetestet auf iOS**
  nichts, was man an der Zugangsdaten-Ablage dreht.
- **Der Query-String wird im Log nicht redigiert.** `_fullUrl` schreibt
  Query-Werte wörtlich. Heute harmlos: dort stehen nur `clientId`,
  `locale`, `service`, `activityType`, `limit`, `start` – Passwort und
  Token reisen im Body. Es ist Vorsorge für den Tag, an dem ein Endpunkt
  doch ein Token in die URL legt.

### Nicht mehr aufgerufener Code

Die vier eindeutigen Fälle sind entfernt. Was bleibt, ist das, wo
Löschen die falsche Antwort wäre:

Nur aus Tests heraus erreichbar, in `lib` tot: `AppInfo.versionName`,
`SsiBuddyCode.isProfessional`, `RecentDivesController.hasLoaded`,
`SsiSyncController.lastBuddyCount`. **Nicht blind löschen** – wo der Test
eine Eigenschaft absichert, ist er der Grund für die Existenz. Bei
`versionName` sieht es nach einem Rest aus.

`SsiSyncController.busyAccountId` wird nie gelesen, gehört aber nicht
hierher: es ist die halbe Verkabelung für den Fortschrittsbalken weiter
unten und sollte dort verwendet statt hier entfernt werden.

Fehlalarme, damit der nächste Durchgang sie nicht erneut herleitet:
`AccountColor`-Werte sind über `AccountColor.values` im Farbwähler
erreichbar, `isSupported`/`shouldReload` sind Framework-Overrides von
`LocalizationsDelegate`.

### Drei fast identische Repositories

`ssi_buddy_repository`, `ssi_center_repository` und `dive_site_repository`
sind je 37–43 Zeilen und unterscheiden sich nach Umbenennen in vier:
Schlüssel, Typ, Doc-Kommentar. Eine generische Basis über
`toJson`/`fromJson` ließe je sechs Zeilen Unterklasse übrig, die ihren
eigenen Kommentar behält – rund 60 Zeilen weniger.

**Die drei Controller dagegen nicht zusammenlegen.** `save`,
`addAllNew`, `remove` und `_sorted` sehen zwar gleich aus, aber
`DiveSitesController` hat eigene Logik bekommen (Umkreis-Suche,
Region-Nachtrag beim Import). Eine gemeinsame Basis würde die
Unterschiede verstecken statt sie zu zeigen.

## Ideen

### Personal API: gebaut, aber noch nie an einem Gerät gelaufen

Verkabelung, Eingabe und Ablaufbehandlung stehen; die Übertragung
zwischen Geräten per QR-Code fehlt noch, und **nichts davon ist je auf
einem Gerät ausgeführt worden** – nur Analyzer und Tests.

Was da ist:

- `GarminPersonalApiClient` – tauscht den Schlüssel gegen ein Token
  (`Accept: */*`, die Antwort ist rohes JWT; `application/json` gibt 406)
  und liest über `/userprofile-service/userprofile/settings`, wem der
  Schlüssel gehört.
- `GarminSession` trägt beide Arten: SSO mit Refresh-Token, Personal mit
  Schlüssel und Ablaufzeit. `GarminApi` sagt, welcher Host gilt – die
  Pfade dahinter sind dieselben.
- `AccountsController.ensureFreshSession` verzweigt. Ein Token mit mehr
  als einer Stunde Restlaufzeit wird wiederverwendet; sonst wird ein
  neues geholt. Die Stunde ist das Fenster aus Garmins eigenem Client.
- `GarminKeyScreen` – einfügen, prüfen, speichern. Der Schlüssel wird nie
  auf Treu und Glauben gespeichert: erst getauscht, dann das Profil
  gelesen. Daher kommt der Name des Accounts, und ein Schlüssel aus einem
  fremden Konto fliegt auf, bevor er fremde Tauchgänge lädt.
- Ein abgelaufener Schlüssel sagt „Schlüssel abgelaufen" statt „Sitzung
  abgelaufen" und führt zum Schlüssel-Bildschirm statt zur Anmeldung.

#### Was noch fehlt

1. **Am Gerät prüfen.** Vor allem: Kommt man überhaupt zum Schlüssel?
   Erzeugt wird er in Garmin Connect **im Browser** – die App zeigt nur
   die Adresse an, sie öffnet sie nicht. Das würde `url_launcher`
   brauchen, eine weitere Plattform-Abhängigkeit, und davon wurde dieses
   Projekt schon zweimal gebissen. Erst sehen, wie lästig es wirklich
   ist.
2. **Etappe 3: Übertragung zwischen Geräten.** Das Gerät mit dem
   Schlüssel zeigt ihn als QR-Code, das andere scannt ihn.
   `QrScanScreen<T>` ist bereits generisch, `QrDisplayScreen` zeigt
   beliebige Nutzlast – es wäre fast nur Verdrahtung. **Aber:** ein
   QR-Code mit einem gültigen Zugangsschlüssel auf einem Bildschirm ist
   abfotografierbar. Das gehört hinter eine Bestätigung, die sagt, was
   gleich sichtbar wird, nicht in ein Menü neben „Umbenennen".
3. **Die Lizenzfrage.** Die Personal-Stufe ist für Werkzeuge gedacht, die
   man selbst betreibt. Jeder mit eigenem Schlüssel auf eigenem Gerät
   trifft das dem Sinn nach – lesen sollte man es trotzdem, bevor die
   Funktion in ein Release geht.
4. **Keine Tauchgangsnummer.** Belegt: weder Liste noch Detail führen
   eine. Die Überschrift der Detailseite fällt auf den Typ zurück. Kostet
   wenig, weil die App das wegen Apnoe ohnehin kann, ist aber ein
   sichtbarer Verlust gegenüber dem SSO-Weg.
5. **Ratenbegrenzungen** sind unbekannt. Die 60-Sekunden-Sperre im
   Refresh schützt schon.

Der alte Weg bleibt unverändert daneben bestehen. Kein Account wird
umgestellt, der nicht ausdrücklich einen Schlüssel bekommt.

#### Was die Detail-Antwort sonst noch hergäbe

`diveInfo` trägt genau die Felder, die der QR-Code heute leer lässt, weil
ein Tauchcomputer sie nicht aufzeichnet: `buddy`, `visibility`,
`current`, `entryType`, `surfaceCondition`, `exposureSuit`,
`suitThickness`, `weight`. Beim geprüften Konto alle `null` – wer sie in
Garmin Connect pflegt, könnte sie von dort in den SSI-Export tragen.
Eigene Entscheidung, eigener Eintrag.

### Durchschnittstiefe mit übertragen

Garmin liefert sie, die App zeigt sie, der QR-Code lässt sie liegen. Was
fehlt, ist allein der Feldname auf der SSI-Seite.

**Garmin-Seite fertig:** `avgDepth` → `GarminActivity.avgDepthMeters` →
`Dive.avgDepthMeters`, in Zentimetern wie die Maximaltiefe, auf der
Detailseite als „Ø Tiefe" sichtbar und im Cache. Auch über die Personal
API bestätigt (`avgDepth: 127.699...`).

**SSI-Seite unbekannt.** In keinem der aufgezeichneten Exporte – den zwei
ersten, den vier aus dem Deko-Fix – kommt eine Durchschnittstiefe vor,
und in den Code-Tabellen aus der SSI-Konfigurationsdatei auch nicht.

Ein Anhaltspunkt, mehr nicht: SSIs API nennt die Maximaltiefe
`odin_user_log_depth_m`, im QR-Code heißt dasselbe Feld `depth_m` – das
Präfix fällt weg. Nach dem Muster hieße die Durchschnittstiefe plausibel
`avg_depth_m`. **Plausibel reicht hier nicht:** genau diese Art Schluss
ist in diesem Projekt zweimal danebengegangen (Rebreather landeten als
Extended Range, und `deco:0` las SSI als „ja"). Ein erfundenes Feld
landet still falsch im Logbuch, und der Test
`ssi_qr_payload_builder_test.dart` verbietet es ausdrücklich.

**Zwei Wege, es zu klären:**

1. *Verbindlich* – in der SSI-App einen Tauchgang exportieren, **bei dem
   eine Durchschnittstiefe eingetragen ist**, und den Code mit
   „SSI-Code analysieren" scannen. Die Feldliste nennt den Namen.
2. *Hinweis* – ein `logbook_details`-Eintrag aus dem API-Log. Er trägt
   rund 200 Felder; wie SSI die Durchschnittstiefe intern nennt, grenzt
   den QR-Namen ein, beweist ihn aber nicht.

Sobald der Name feststeht: eine Zeile im Builder plus Test.
`Dive.avgDepthMeters` liegt bereit.

Möglich ist auch, dass SSIs Import gar kein Feld dafür hat. Dann gehört
die Durchschnittstiefe in die README-Liste der Werte, die bewusst leer
bleiben – zu Wetter, Strömung und Sicht.

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
