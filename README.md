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
- **Tauchgangs-Liste** pro Account: Datum, max. Tiefe, Tauchgangs-Nummer des Tages
- **Detailansicht** mit allen geladenen Werten (Tiefe, Dauer, Wassertemperatur, ...)
- **QR-Code-Export** im Format, das der SSI-QR-Scanner beim Anlegen eines Tauchgangs erwartet –
  inklusive der SSI-Mitgliedsnummer, wenn für den Account eine hinterlegt ist
- **SSI-Buddies**: Mittaucher ohne eigenen Garmin-Account lassen sich per QR-Code-Scan speichern
  und beim Export auswählen (siehe Einschränkungen)
- **FIT-Datei-Import** als Alternative, falls der Garmin-Login gerade nicht funktioniert
  (z.B. Original-FIT-Export aus Garmin Connect Web)
- Zugangsdaten werden verschlüsselt auf dem Gerät gespeichert; Tauchgangsdaten selbst werden
  **nicht** dauerhaft gespeichert, sondern nur für die laufende Sitzung geladen

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
- **Buddies stehen noch nicht im QR-Code.** Wie SSI sie im Import benennt, geht aus den bisher
  vorliegenden Exporten nicht hervor, und ein geratener Feldname würde stillschweigend
  verschwinden. Bis das geklärt ist, dient die Auswahl als Merkzettel für den Eintrag in der
  SSI-App. Zum Klären gibt es im API-Protokoll den Punkt „SSI-Code analysieren": einen
  SSI-Export mit Buddy scannen, dann steht der Feldname da.
- Diese App steht in keiner Verbindung zu Garmin Ltd. oder Scuba Schools International (SSI).

## Entwicklung

Setup-Anleitung (Windows/VS Code) und Build-Befehle: siehe [`SETUP.md`](SETUP.md).

```
flutter analyze     # Statische Codeprüfung
flutter test         # Unit-Tests
flutter run          # App bauen + starten
```

## Lizenz

Apache License 2.0, siehe [`LICENSE`](LICENSE).
