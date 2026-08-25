# SSI Connect

![SSI Connect Logo](assets/branding/logo-hero.png)

Flutter-App (Android/iOS, für Tablet-Nutzung gedacht), die Tauchgänge einer Garmin-Uhr
in die offizielle [SSI-App](https://play.google.com/store/apps/details?id=com.divessi.ssi)
übernimmt – ganz ohne die Werte von Hand abzutippen.

## Warum

Garmin-Uhren mit Dive-Computer (z.B. die Descent-Serie) zeichnen Tauchgänge automatisch auf.
Garmin und SSI haben aber keine offizielle Schnittstelle mehr zueinander. SSI Connect schließt
diese Lücke: Tauchgänge werden von Garmin geladen (oder per FIT-Datei importiert), übersichtlich
aufgelistet, und lassen sich mit einem Tastendruck als QR-Code anzeigen, den man mit der
Kamera der SSI-App scannt.

## Funktionsumfang

- **Mehrere Garmin-Accounts** (z.B. für die ganze Familie), Login inkl. Zwei-Faktor-Code
- **Startseite mit den jüngsten Tauchgängen** über alle Accounts hinweg – ein Tippen darauf
  öffnet direkt den QR-Code. Über „Alle anzeigen" die vollständige gemeinsame Liste, die sich
  auf Knopfdruck seitenweise weiter in die Vergangenheit lädt
- **Farbe je Account**, als Balken am linken Rand der Tauchgänge – auf einem Familien-Tablet
  ist so auf einen Blick klar, wessen Tauchgang das ist (der Name steht zusätzlich dabei)
- **Tauchgangs-Liste** pro Account: Datum, max. Tiefe, Tauchgangs-Nummer des Tages – mit
  Filter „Alle / Noch offen / Übernommen", der auf die Frage antwortet, die man vor dieser
  Liste tatsächlich hat: was muss noch nach SSI?
- **Detailansicht** mit allen geladenen Werten (Tiefe, Dauer, Wassertemperatur, ...)
- **QR-Code-Export** im Format, das der SSI-QR-Scanner beim Anlegen eines Tauchgangs erwartet –
  inklusive der SSI-Mitgliedsnummer, wenn für den Account eine hinterlegt ist
- **SSI-Anmeldung pro Account**: wer mag, meldet sich bei seinem Garmin-Account zusätzlich bei
  SSI an. Die SSI-Mitgliedsnummer kommt dann direkt von SSI statt aus einem gescannten
  QR-Code – Scannen und Eintippen bleiben für alle, die kein SSI-Konto haben
- **Tauchplätze aus dem SSI-Logbuch**: dieselbe Anmeldung holt jeden Platz, an dem man laut
  SSI schon getaucht ist, mit Nummer, Name und Position auf das Gerät. Danach erkennt die App
  den Platz an der Position des Tauchgangs wieder und schlägt ihn vor; bestätigt landet er als
  `site:` im QR-Code. Liegen mehrere Plätze im Umkreis, werden alle nach Entfernung sortiert
  angeboten – vorgeschlagen wird immer, gesetzt nie von allein. Ein Platz lässt sich weiterhin
  von Hand zuordnen (Nummer eintippen oder die Adresse der Platzseite einfügen).
  Die Plätze gelten geräteweit, die Anmeldungen pro Person – ein Tauchplatz ist ein Ort, und
  den teilt die Familie. Unter „Einstellungen → SSI-Logbuch" stehen die bekannten Plätze,
  die verbundenen Konten und der Zeitpunkt des letzten Abgleichs
- **Tauchtag am Stück übertragen**: mehrere Tauchgänge auswählen (ein Tippen wählt einen ganzen
  Tauchtag) und als Folge von QR-Codes durchblättern. Das Handy mit der SSI-App bleibt liegen –
  scannen, „Weiter", scannen
- **„In SSI übernommen"**: unter dem QR-Code lässt sich abhaken, dass der Tauchgang drüben
  angekommen ist; in der Liste steht dann ein grüner Haken neben dem Datum. Wer sein SSI-Konto
  verbunden hat, bekommt den Haken zusätzlich **automatisch** – der Abgleich liest die
  Tauchgänge aus dem Logbuch und erkennt sie an Datum, Uhrzeit und Tiefe wieder. Der Haken von
  Hand hat immer Vorrang, in beide Richtungen. Nie abgeleitet wird er aus dem Export selbst:
  ein angezeigter QR-Code ist kein Beleg dafür, dass ihn jemand gescannt hat, und ein Haken,
  der zu früh kommt, markiert genau den Tauchgang, der danach übersprungen wird
- **SSI Buddy**: eine Liste aller SSI-Codes, die das Gerät kennt – die Accounts mit hinterlegter
  Nummer, die Mittaucher (aus dem SSI-Logbuch übernommen oder abgescannt, bei Profis inklusive
  SSI Professional Nr.) und unter „Tauchbasen" die Basen selbst. Jeder Eintrag lässt sich wieder
  als QR-Code anzeigen, damit ein anderes Gerät ihn einlesen kann; der Scanner erkennt selbst,
  ob ein Buddy- oder ein Basis-Code vor der Kamera ist. Aus dem Logbuch übernommen wird nur,
  was auch in einem gescannten Buddy-QR-Code steht – Nummer, Name, E-Mail, SSI Professional
  Nr.; Geburtsdatum, Wohnort, Telefonnummer und Foto stehen zwar in der Antwort, werden aber
  verworfen. Wer hier schon einen Account hat, landet nicht zusätzlich als Buddy in der Liste
- **Deutsch und Englisch**, unter „Einstellungen" umschaltbar oder der Systemsprache folgend
- **Helles oder dunkles Design**, ebenfalls dort umschaltbar oder der Systemeinstellung
  folgend. Der QR-Code bleibt immer hell – ein dunkler Code ist für Kameras unzuverlässig
- **FIT-Datei-Import** als Alternative, falls der Garmin-Login gerade nicht funktioniert
  (z.B. Original-FIT-Export aus Garmin Connect Web)
- **Offline nutzbar**: die zuletzt geladenen Tauchgänge liegen auf dem Gerät und stehen auch
  ohne Netz zur Verfügung – mit sichtbarem Hinweis, von wann sie sind
- Zugangsdaten, SSI-Token *und* die zwischengespeicherten Tauchgänge liegen verschlüsselt im
  Schlüsselspeicher des Geräts (Android Keystore / iOS Keychain). Der Zwischenspeicher lässt
  sich pro Account jederzeit löschen und verschwindet automatisch mit dem Account

## Wie benutzt man es

1. Auf dem Tablet einen oder mehrere Garmin-Accounts hinzufügen
2. Optional: beim Account unter „SSI-Identität" mit dem SSI-Konto anmelden – das trägt die
   Mitgliedsnummer ein und holt Tauchplätze und Buddys aus dem Logbuch
3. Tauchgang aus der Liste auswählen, Werte in der Detailansicht prüfen
4. "QR-Code erzeugen" antippen
5. Mit einem zweiten Gerät (z.B. dem Handy) die SSI-App öffnen, "QR-Code scannen" wählen und
   den Code vom Tablet-Bildschirm abscannen

Der QR-Code muss von einem *anderen* Gerät gescannt werden als dem, auf dem er angezeigt wird –
deshalb ist die App als Tablet-/Zweitgerät-App gedacht und nicht als Handy-App neben SSI selbst.

## Wichtige Einschränkungen

- Der Garmin-Login nutzt eine **inoffizielle, reverse-engineerte Schnittstelle** (Garmin bietet
  keine öffentliche Consumer-API an). Das kann jederzeit durch Änderungen bei Garmin brechen –
  in dem Fall hilft der FIT-Datei-Import als Fallback.
- Das SSI-QR-Format ist ebenfalls nicht offiziell dokumentiert, sondern wurde anhand echter
  Exporte aus der SSI-App rekonstruiert (siehe `lib/ssi/ssi_qr_payload_builder.dart`).
- Fehlt ein Wert in der Quelle, bleibt das entsprechende Feld im QR-Code leer, statt geraten zu
  werden. Wetter, Einstieg, Strömung und Sicht zeichnet ein Tauchcomputer nicht auf und werden
  deshalb nie befüllt.
- **Der Tauchplatz lässt sich nicht aus den Koordinaten ableiten.** SSIs Platznummern stammen aus
  einer eigenen Datenbank ohne offene Abfrage. Die App holt sie deshalb aus dem eigenen
  SSI-Logbuch – über dieselbe inoffizielle Schnittstelle, die auch die SSI-App nutzt
  (`api.divessi.com/app/a21.php`). Das deckt jeden Platz ab, an dem man schon war. Ein neuer
  Platz ist zwangsläufig noch nicht dabei: den ordnet man einmal in der SSI-App zu, danach
  kennt ihn der nächste Abgleich. SSIs Web-Suche (`rest.divessi.com`) wäre die vollständigere
  Quelle, wurde aber geprüft und verworfen – sie steht hinter einer WAF, ihr API-Key hängt an
  einer Browser-Session, und sie antwortet mit HTML statt mit Daten.
- Vom SSI-Konto wird **nur der Sitzungs-Token** gespeichert, nie das Passwort. Läuft der Token ab,
  fragt die App erneut nach der Anmeldung.
- **Buddies lassen sich nicht mit einem Tauchgang übertragen.** SSIs Import-Format hat kein
  Feld dafür – die Auswahl unter dem QR-Code wurde deshalb wieder entfernt, statt sie
  funktionsfähig aussehen zu lassen. Die Buddy-Liste bleibt und kann jeden Eintrag als
  QR-Code zeigen, sodass ihn ein anderes Gerät scannen kann.
- Diese App steht in keiner Verbindung zu Garmin Ltd. oder Scuba Schools International (SSI).

## Entwicklung

Offene Fehler und Ideen: siehe [`BACKLOG.md`](BACKLOG.md) – GitHub-Issues sind für dieses
Repository abgeschaltet.

Setup-Anleitung (Windows, macOS, Linux; Editor frei wählbar) und Build-Befehle:
siehe [`SETUP.md`](SETUP.md).
Fertige Builds veröffentlichen: siehe [`RELEASING.md`](RELEASING.md).

```
flutter analyze     # Statische Codeprüfung
flutter test         # Unit-Tests
flutter run          # App bauen + starten
```

## Lizenz

Apache License 2.0, siehe [`LICENSE`](LICENSE).
