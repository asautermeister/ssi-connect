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
- **Tauchgangs-Liste** pro Account: Datum, max. Tiefe, Tauchgangs-Nummer des Tages
- **Detailansicht** mit allen geladenen Werten (Tiefe, Dauer, Wassertemperatur, ...)
- **QR-Code-Export** im Format, das der SSI-QR-Scanner beim Anlegen eines Tauchgangs erwartet –
  inklusive der SSI-Mitgliedsnummer, wenn für den Account eine hinterlegt ist
- **Tauchtag am Stück übertragen**: mehrere Tauchgänge auswählen (ein Tippen wählt einen ganzen
  Tauchtag) und als Folge von QR-Codes durchblättern. Das Handy mit der SSI-App bleibt liegen –
  scannen, „Weiter", scannen
- **SSI Buddy**: eine Liste aller SSI-Codes, die das Gerät kennt – die Accounts mit hinterlegter
  Nummer, zusätzlich gescannte Mittaucher (bei Profis inklusive SSI Professional Nr.) und unter
  „Tauchbasen" die Basen selbst. Jeder Eintrag lässt sich wieder als QR-Code anzeigen, damit ein
  anderes Gerät ihn einlesen kann; der Scanner erkennt selbst, ob ein Buddy- oder ein
  Basis-Code vor der Kamera ist
- **Helles oder dunkles Design**, unter „Einstellungen" umschaltbar oder der Systemeinstellung
  folgend. Der QR-Code bleibt immer hell – ein dunkler Code ist für Kameras unzuverlässig
- **FIT-Datei-Import** als Alternative, falls der Garmin-Login gerade nicht funktioniert
  (z.B. Original-FIT-Export aus Garmin Connect Web)
- **Offline nutzbar**: die zuletzt geladenen Tauchgänge liegen auf dem Gerät und stehen auch
  ohne Netz zur Verfügung – mit sichtbarem Hinweis, von wann sie sind
- Zugangsdaten *und* die zwischengespeicherten Tauchgänge liegen verschlüsselt im
  Schlüsselspeicher des Geräts (Android Keystore / iOS Keychain). Der Zwischenspeicher lässt
  sich pro Account jederzeit löschen und verschwindet automatisch mit dem Account

## Wie benutzt man es

1. Auf dem Tablet einen oder mehrere Garmin-Accounts hinzufügen
2. Tauchgang aus der Liste auswählen, Werte in der Detailansicht prüfen
3. "QR-Code erzeugen" antippen
4. Mit einem zweiten Gerät (z.B. dem Handy) die SSI-App öffnen, "QR-Code scannen" wählen und
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
- **Buddies lassen sich nicht mit einem Tauchgang übertragen.** SSIs Import-Format hat kein
  Feld dafür – die Auswahl unter dem QR-Code wurde deshalb wieder entfernt, statt sie
  funktionsfähig aussehen zu lassen. Die Buddy-Liste bleibt und kann jeden Eintrag als
  QR-Code zeigen, sodass ihn ein anderes Gerät scannen kann.
- Diese App steht in keiner Verbindung zu Garmin Ltd. oder Scuba Schools International (SSI).

## Entwicklung

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
