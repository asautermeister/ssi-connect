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

### Auf Garmins offizielle Personal API umstellen

Garmin hat sein Connect Developer Program am 21.10.2026 umgebaut und
dabei erstmals eine **Personal**-Stufe geöffnet: kostenlos, lesend, nur
die eigenen Daten, Pull statt Push. Damit entfällt der Grund, aus dem die
App heute die interne App-Schnittstelle nachbaut – es gibt jetzt eine für
Privatpersonen.

Die rekonstruierte Spec liegt unter
`docs/garmin-connect-personal-api.openapi.json` (27 Pfade). Sie ist aus
zwei Quellen gebaut: der gespeicherten Swagger-Seite und Garmins eigenem
Python-Client (`github.com/garmin/connect-personal-api-python`,
Apache-2.0). **Request- und Response-Schemas fehlen bewusst** – die Seite
wurde mit zugeklappten Modellen gespeichert, die Properties standen nie
darin, und erfundene Felder wären schlimmer als keine.

**Der Befund, der den Umbau klein macht: es sind dieselben Pfade.**

```
/activitylist-service/activities/search/activities   ← nutzen wir schon
/activity-service/activity/{activityId}              ← nutzen wir schon
```

Das Programm ist kein Neubau, sondern dieselbe Connect-API auf einem
dokumentierten Host (`personal.connectapi.garmin.com`) mit offizieller
Anmeldung. `GarminActivityClient` bliebe in der Sache, wie er ist.

In der Schema-Liste stehen außerdem `DiveInfoDTO`, `DiveSettingsDTO`,
`DiveGasDTO`, `SummarizedDiveInfoDTO` und `SummarizedDiveGasDTO` – die
Tauchdaten sind also Teil des offiziellen Modells und nicht etwas, das
der offizielle Weg wegschneidet. **Welche Felder genau, ist offen** und
muss an einem echten Tauchgang geprüft werden, bevor irgendetwas
umgebaut wird.

#### Was sich ändert

| | heute | mit Personal API |
|---|---|---|
| Anmeldung | E-Mail + Passwort über `sso.garmin.com`, MFA, Cookie-Jar | Schlüssel aus Connect, einmal eingefügt |
| Token | `accessToken` + `refreshToken`, Laufzeit unbekannt | Bearer bis 24 h, **kein** Refresh-Token |
| Erneuern | `GarminAuthClient.refresh(session)` | neues Token gegen denselben Schlüssel |
| Bricht bei | Cloudflare/WAF, geänderten Interna | Ablauf des Schlüssels (max. 1 Jahr) |

#### Wo der Code aufgeht

Die Nähte liegen günstig, weil es jeweils genau eine Stelle ist:

- **`GarminActivityClient._get`** setzt als einzige Stelle den
  `Authorization`-Header und die Basis-URL. Beides sind Felder, keine
  Logik.
- **`AccountsController.ensureFreshSession`** ist der einzige Ort, an dem
  eine Sitzung erneuert wird. Daraus würde „habe ich ein Token, das noch
  mindestens eine Stunde gilt? sonst hol ein neues" – nach demselben
  Muster, das `PersonalApiAuthenticator` in Garmins Client verwendet.
- **`GarminSession`** verliert `refreshToken` und `diClientId` und
  bekommt stattdessen den Schlüssel und das Ablaufdatum des Tokens (das
  im `exp`-Claim des JWT steht, also ablesbar ist statt geraten).
- **`GarminAuthClient` entfällt fast vollständig** – SSO-Formular,
  MFA-Fluss, Service-Ticket, die Liste der internen Client-IDs. Übrig
  bleibt ein `POST` mit `Authorization: ApiKey <key>`, dessen Antwort das
  rohe JWT als Text ist, nicht als JSON.

Der Name des Accounts kommt heute aus der Anmeldung. Ohne Login liefert
ihn `/userprofile-service/userprofile/settings` – derselbe Aufruf könnte
prüfen, ob ein eingefügter Schlüssel überhaupt gültig ist, bevor er
gespeichert wird.

#### Was dabei besser wird

**Keine fremden Passwörter mehr.** Heute tippt jeder Mittaucher sein
Garmin-Passwort in ein Tablet, das ihm nicht gehört. Ein Personal Key
wird von jeder Person im eigenen Account erzeugt, ist lesend, zeitlich
begrenzt und jederzeit widerrufbar. Für eine App, die ausdrücklich
mehrere Konten auf einem geteilten Gerät führt, ist das die ehrlichere
Bauform – und der Mehr-Account-Gedanke bleibt unverändert, nur die
Zugangsart pro Konto ändert sich.

**Der Login-Bruch verschwindet.** `garmin_auth_client.dart` warnt heute
selbst, dass die Anmeldung an einer WAF scheitern kann und das kein
Fehler ist, den man wegretryen soll. Diese Fehlerklasse fällt weg.

**Die FIT-Datei kommt offiziell.**
`GET /download-service/files/activity/{activityId}` liefert laut Garmins
Client ein ZIP. `FitDiveImporter` liest FIT-Tauchgänge bereits – das wäre
ein zweiter, belastbarer Weg an die Werte, falls das JSON-Summary weniger
mitbringt als die interne Antwort heute.

#### Was offen ist, bevor man anfängt

1. **Liefert das JSON dieselben Tauchfelder?** Maximaltiefe, Grundzeit,
   Deko-Flag, Wasserart und vor allem der Sub-Typ (Apnoe, CCR, Single /
   Multi Gas) treiben Abzeichen, Filter und QR-Payload. Ein echter
   Tauchgang über beide Wege abgeholt und verglichen beantwortet das in
   zehn Minuten – dieselbe Methode, die die SSI-Felder geklärt hat.
2. **Nimmt `activityType=diving` dort dieselben Werte an?** Der Parameter
   heißt gleich; ob die Sub-Typ-Regel gleich ist, sagt die Spec nicht.
3. **Deckt die Lizenz eine verteilte App?** Die Personal-Stufe ist für
   Werkzeuge gedacht, die man selbst betreibt. Jeder Nutzer mit eigenem
   Schlüssel auf dem eigenen Gerät trifft das dem Sinn nach – es ist aber
   die Art Klausel, die man liest, bevor man umbaut. Die Startup-Stufe
   wäre die formale Alternative, arbeitet aber push-basiert mit
   Callback-URL und setzt damit einen Server voraus, den diese App nicht
   hat und nicht haben will.
4. **Ablauf des Schlüssels.** Spätestens nach einem Jahr muss jede Person
   einen neuen erzeugen. Die App müsste das vorher sichtbar machen,
   statt eines Tages still keine Tauchgänge mehr zu laden.

#### Reihenfolge, wenn es losgeht

Der alte Weg bleibt bestehen, solange das nicht geklärt ist – ein
zweiter Anmeldeweg neben dem bestehenden, nicht als Ersatz. Erst wenn an
einem echten Konto belegt ist, dass die Tauchfelder vollständig
ankommen, lohnt die Frage, ob der SSO-Fluss ganz verschwindet.

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
