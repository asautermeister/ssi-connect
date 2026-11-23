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

**Zweiter Durchgang am 23.11.2026**, nach dem Merge von #22, über alles
seither Dazugekommene — Personal API, Schlüssel-Bildschirm, Browser-Kanal,
Konsolen-Log, Tauchgangsnummern. Kein neuer Sicherheitsbefund:

- Der Browser-Kanal (`lib/net/browser.dart`) lässt **nur `https`** durch,
  und beide nativen Seiten prüfen das noch einmal selbst. Kein allgemeiner
  Intent-Starter.
- Die Konsolenzeile im Debug-Build trägt Methode, URL, Status und Fehler –
  **keine Rumpfdaten**. Der bekannte Punkt bleibt, dass der Query-String
  nicht redigiert wird; heute reist dort nichts Geheimes.
- Der Personal API Key steht nur im Sitzungsmodell und im Keystore. Er
  landet in keiner Log-Zeile und in keiner Fehlermeldung.
- **Nachtrag (Review 23.11.):** Das *Token* dagegen schon. Der Tausch
  antwortet mit dem nackten JWT als Text, und die Schwärzung griff nur
  hinter einem Feldnamen. Jetzt wird alles in JWT-Form geschwärzt
  (`_sanitizeString`), mit Test.

Gefunden und behoben: drei l10n-Strings, die mit dem Schlüssel-Bildschirm
angelegt und nie benutzt wurden.

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
`LocalizationsDelegate`, und `debugPrint` ist Flutters eigene Funktion,
die ein Suchmuster für eine Deklaration halten kann.

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

### Personal API: eingeschaltet

Verkabelung, Eingabe und Ablaufbehandlung stehen und sind am Pixel 7
gelaufen. Eine Übertragung des Schlüssels per QR-Code auf ein anderes
Gerät ist verworfen (16.11.2026): Wer das Gerät wechselt, erstellt auf
dem neuen einfach einen neuen Schlüssel.

**Ohne Schalter, seit 23.11.2026.** `Features.personalApi` ist entfernt, beide
Einstiege — der Button beim Anmelden und der Punkt im Kontomenü — sind
immer da. Grund: Es gibt kein offizielles Release. Die App wird selbst
gebaut und auf eigenen Geräten installiert, und damit ist genau der Fall
gegeben, den Garmins Bedingungen meinen. **Vor einem öffentlichen Release
muss die Lizenzfrage unten neu beantwortet werden** – dann lädt die
Funktion Leute ein, ihren Schlüssel in eine App zu stecken, die sie nicht
selbst betreiben.

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
- „Schlüssel entfernen" im Kontomenü, nur bei einem Konto mit Schlüssel
  und unabhängig vom Schalter, weil es der Weg hinaus ist. Das Konto
  bleibt mit Name, Farbe und SSI-Nummer, ist danach abgemeldet
  (`GarminSession.none`) und sagt „Nicht angemeldet". Die gespeicherten
  Tauchgänge mitzulöschen ist ein Häkchen, standardmäßig aus.
- Ein Garmin-Konto ist ein Eintrag: Eine Anmeldung für eine Person, die
  schon da ist, stellt das bestehende Konto um, ob per Passwort oder
  Schlüssel. Erkannt wird die Person an `garmin_guid` im Token. Am Gerät
  geprüft: Passwort- und Schlüssel-Token derselben Person tragen denselben
  Wert. Die Mailadresse ist nur Rückfall, denn das Profil hinter einem
  Schlüssel enthält keine (Felder: `displayName` und Einstellungen). Mit
  der Kennung prüft auch der Schlüssel-Bildschirm, ob ein Schlüssel zu
  einem fremden Konto gehört.

#### Was noch fehlt

1. **Am Gerät geprüft (14. und 16.11.2026, Pixel 7).** Schlüssel
   erstellen, Tausch, Profil, Tauchgangsliste, Detailansicht, QR-Code
   und das Entfernen des Schlüssels laufen. Der Knopf auf dem
   Schlüssel-Bildschirm öffnet die Garmin-Seite im Browser (eigener Kanal
   in `lib/net/browser.dart`, kein `url_launcher`). Ein abgelaufenes
   Token wird still erneuert: erst 401, dann Tausch, dann die Liste.
   Dass dem ein Fehlversuch vorausgeht, ließe sich sparen – das Token
   trägt sein Ablaufdatum (`exp`), die App könnte vorher tauschen.
2. **Die Lizenzfrage – Text liegt vor (Zusatzbedingungen, Stand
   1.10.2026).** Kernsatz: Schlüssel „sind persönlich für dich und dürfen
   nur von dir in Verbindung mit Anwendungen, Services oder Tools
   verwendet werden, die du für deinen eigenen Gebrauch entwickelst oder
   betreibst". Nicht erlaubt: verkaufen, übertragen, unterlizenzieren,
   vertreiben, offenlegen, mit Dritten teilen. Folgen für die App, ohne
   juristische Gewissheit:
   - Der eigene Schlüssel in der selbst gebauten App auf dem eigenen
     Gerät ist der gemeinte Fall.
   - Das Familien-Tablet ist eine Grauzone: Jede Person trägt zwar ihren
     eigenen Schlüssel ein, aber auf einem Gerät, das andere mitbenutzen,
     in einer App, die sie nicht selbst betreibt.
   - Ein öffentliches Release mit eingeschalteter Funktion lädt andere
     ein, ihre Schlüssel in eine App zu stecken, die sie nicht selbst
     entwickeln. Solange es kein Release gibt, stellt sich die Frage
     nicht – **mit dem ersten Release stellt sie sich wieder**, und dann
     vor dem Release, nicht danach.
3. **Keine Tauchgangsnummer – gelöst über einen Anker (16.11.2026).**
   Die Personal API liefert weder in der Liste noch im Detail eine
   Nummer. Selbst durchzählen reicht nicht: Am Konto mit 279 am letzten
   Tauchgang ergab die Zählung 294 (alle), 282 (ohne Apnoe), 275 (nur
   Einzelgas) – ein Logbuch hat Tauchgänge, die nie in Garmin landeten.
   Deshalb setzt man in der Detailansicht (#) die Nummer eines
   Tauchgangs, die übrigen werden von dort in beide Richtungen gezählt,
   Apnoe nicht mitgerechnet. Mehrere Anker für Lücken, jeder Tauchgang
   zählt vom nächstgelegenen. Nur wo Garmin keine Nummer sendet.
4. **Ratenbegrenzungen** sind nicht beziffert. Die Bedingungen behalten
   sich vor, jederzeit zu drosseln oder zu sperren, und ein Verstoß kann
   den Schlüssel kosten. Die 60-Sekunden-Sperre im Refresh und das
   einmalige Laden pro Start halten die Zahl der Aufrufe klein.
5. **Laufzeit.** Garmin bietet 30 Tage (voreingestellt), 90, 180 Tage
   und 1 Jahr. Die Anleitung in der App empfiehlt jetzt 1 Jahr. Denkbar
   wäre, das Ablaufdatum am Konto anzuzeigen, bevor es so weit ist.
   Dafür müsste man wissen, ob es irgendwo abzulesen ist; das Token
   selbst lebt nur einen Tag.

Der Weg zum Schlüssel, am 15.11.2026 durchgegangen:
`https://connect.garmin.com/app/settings/personalApiToken` öffnen, bei
Garmin anmelden (samt 2SV), „Schlüssel erstellen", Zusatzbedingungen
annehmen, Laufzeit wählen, kopieren, Kopieren bestätigen.

Der alte Weg bleibt unverändert daneben bestehen. Kein Account wird
umgestellt, der nicht ausdrücklich einen Schlüssel bekommt.

#### Was die Detail-Antwort sonst noch hergäbe

`diveInfo` trägt genau die Felder, die der QR-Code heute leer lässt, weil
ein Tauchcomputer sie nicht aufzeichnet: `buddy`, `visibility`,
`current`, `entryType`, `surfaceCondition`, `exposureSuit`,
`suitThickness`, `weight`. Beim geprüften Konto alle `null` – wer sie in
Garmin Connect pflegt, könnte sie von dort in den SSI-Export tragen.
Eigene Entscheidung, eigener Eintrag.

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
Gerät einlesen, so wie es die Buddy-Liste schon kann. Zwei Fälle, in
denen das gebraucht wird: ein zweites Familien-Tablet **ohne**
SSI-Anmeldung, das seine Plätze von nirgends herbekommt, und ein von Hand
eingetragener Platz, der nach einem Neuaufsetzen nicht wieder
hereinzuimportieren ist – er stand nie in einem Logbuch.

#### Was im Code steht

```
divesite;303948;name:Blue Hole;lat:36.0166;lon:14.2798;region:Gozo
```

Alle Felder von `DiveSite` reisen mit, jedes aus einem Grund:

- `siteId` – das Einzige, was SSI je interessiert.
- `name` – das Label der Liste.
- `lat`/`lon` – **ohne die ist der geteilte Platz auf dem Zielgerät
  nutzlos.** Der Umkreis-Vorschlag ist der ganze Nutzen eines bekannten
  Platzes; eine Nummer ohne Position wird nie wieder von selbst gefunden.
  Vier Dezimalstellen wie in `coordinatesLabel`, nicht mehr.
- `region` – damit der Platz auf dem zweiten Gerät in derselben Gruppe
  landet wie auf dem ersten.

Rund 70 Bytes pro Platz.

**Der Marker ist `divesite`, nicht `site`.** `buddy`, `center` und `dive`
sind SSIs eigene Marker, und `site:` ist ein *Feld* im
Tauchgangs-Payload. Ein eigener Marker schließt eine Verwechslung auch
dann aus, wenn SSI selbst einmal Plätze als Code ausgibt.

**Das ist das Format dieser App, keins von SSI.** Die SSI-App wird diesen
Code nie lesen – anders als der Buddy-Code, der SSIs eigener ist. Gehört
in den Doc-Kommentar, sonst hält ihn später jemand für einen SSI-Code und
sucht den Fehler bei SSI. Jedes Feld durch `ssiPayloadValue()`: Namen
kommen aus fremden Logbüchern.

#### Wo es andockt – fast nichts davon ist neu

- **Zeigen:** QR-Symbol rechts auf `_SiteCard`, genau wie die Buddy-Karte
  es bekommen hat. Gerendert wird mit `QrScanSurface`.
- **Lesen:** Der FAB „Code scannen" liest heute schon *beide* Arten – es
  braucht einen dritten Fall in `SsiCodeScanScreen.parse` und in
  `_scan()`, keinen neuen Knopf. Ein Scanner, drei Code-Arten, und die
  Frage „was scannst du gerade?" stellt sich weiterhin nicht.
- **Zusammenführen:** `DiveSitesController.addAllNew` existiert und macht
  genau das Richtige – nur Neues anlegen, Region nachtragen, einen
  umbenannten Eintrag nicht überfahren.

**Eine Entscheidung ist offen:** Was passiert bei einem Platz, dessen
Nummer das Gerät schon kennt? `save` würde den lokalen Namen
überschreiben, `addAllNew` behält ihn. Vorschlag: behalten – der lokale
Name ist eine Entscheidung des Nutzers – aber „kennt dieses Gerät schon"
sagen statt still nichts zu tun.

#### Einer oder viele

1. **Ein Platz pro Code.** Der Anfang. Für die drei Plätze einer Reise
   genügt es, und es ist in sich geschlossen und testbar.
2. **Eine Region am Stück** – aber nicht als ein Riesen-Code: Version 40
   ist bei 380 px vom Nachbartablet aus kaum zu scannen. Durchblättern
   wie der Tauchtag, `DiveQrBatchScreen` ist das Muster und steht schon.
3. **Die ganze Liste** (dreistellig) ist kein QR-Fall. Dafür eine Datei:
   `file_picker` liegt für den FIT-Import schon da, `DiveSite.toJson` ist
   fertig, der Export wäre `jsonEncode` über die Liste. Gegen die Datei
   spricht nur, dass sie irgendwie vom Gerät zum Gerät muss – QR
   funktioniert ohne Netz, ohne Kabel und ohne Konto.

**Verworfen:** Bluetooth oder „Nearby" (Plattform-Code und neue
Berechtigungen für etwas, das zwei Kameras auch können) und ein Austausch
über SSI (für ein Konto mit Logbuch kommen die Plätze von dort – die
Lücke ist gerade das Tablet *ohne* Anmeldung).

**Sicherheit:** Die Liste liegt verschlüsselt, weil sie zusammen mit den
Koordinaten sagt, wo diese Person taucht. Ein angezeigter QR-Code ist
eine bewusste Übergabe an die Person daneben und zeigt nur, was ohnehin
auf dem Bildschirm steht. Entscheidend ist, dass **nichts mitreist, was
nicht in der Zeile oben steht** – keine Konto-ID, keine Herkunft, keine
Tauchgangsdaten.

#### Der nächste Schritt, konkret

Variante 1, ein Platz pro Code, in der Reihenfolge, in der sie sich
abarbeiten lässt:

1. **`lib/ssi/dive_site.dart`** – `sharePayload()` und
   `DiveSite.tryParsePayload(String)` an `DiveSite` selbst, nicht als
   eigener Typ. `SsiBuddyCode` und `SsiCenterCode` sind eigene Typen,
   weil sie *SSIs* Drahtformat sind und es neben dem Modell steht; hier
   ist das Modell schon das, was geteilt wird. `toJson` bleibt daneben
   stehen – das eine ist die Ablage, das andere die Übergabe, und beide
   dürfen sich unabhängig ändern.
2. **`lib/ui/ssi_scan_screen.dart`** – dritter Fall in
   `SsiCodeScanScreen.parse`, dazu der Hinweistext („Mitglied,
   Tauchcenter oder Tauchplatz").
3. **`lib/ui/ssi_buddies_screen.dart`** – QR-Symbol rechts auf
   `_SiteCard` (die Buddy-Karte ist die Vorlage) und der dritte `case` in
   `_scan()`. Dort fällt die offene Entscheidung von oben: bei bekannter
   Nummer den lokalen Namen behalten und es sagen.
4. **l10n** – neue Strings in die abstrakte Klasse *und* beide Sprachen,
   sonst kompiliert es nicht.

Tests, die das festnageln: Payload hin und zurück (in
`test/dive_site_test.dart`), der Scanner erkennt die richtige der drei
Arten, die Platz-Karte zeigt das Symbol, und eine schon bekannte Nummer
behält den lokalen Namen. Bei Widget-Tests `pumpAndSettle` nach
`pumpWidget` – die Lokalisierung löst asynchron auf, sonst ist der Baum
leer.

### CI-Workflow für Pull Requests

Heute laufen `flutter analyze` und die Tests nur beim Release. Ein
Workflow, der bei jedem Pull Request läuft, wäre Voraussetzung dafür, im
Ruleset für `master` einen Status-Check zu verlangen.
