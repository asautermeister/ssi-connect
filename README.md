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
  öffnet die Detailansicht, wie überall sonst auch. Über „Alle anzeigen" die vollständige
  gemeinsame Liste, die sich auf Knopfdruck seitenweise weiter in die Vergangenheit lädt
- **Farbe je Account**, als Balken am linken Rand der Tauchgänge – auf einem Familien-Tablet
  ist so auf einen Blick klar, wessen Tauchgang das ist (der Name steht zusätzlich dabei)
- **Tauchgangs-Liste** pro Account: Datum, max. Tiefe, Tauchgangs-Nummer des Tages. Ein Balken
  auf fester Skala von 0 bis 45 m macht die Tiefe auf einen Blick vergleichbar – Striche alle
  fünf Meter, längere alle zehn, beziffert nur an den Enden. Tiefer als 45 m füllt den Balken
  ganz und setzt einen Pfeil ans Ende. Fest ist dabei der Punkt: vorher richtete sich der Balken
  nach dem tiefsten Tauchgang der gerade geladenen Liste, war also je nach Filter und Ladestand
  unterschiedlich lang für denselben Tauchgang. Dazu ein
  Filter hinter dem Trichter-Symbol oben rechts: „Alle / Noch offen / Scuba / Rec / Tech".
  „Noch offen" beantwortet die Frage, die man vor dieser Liste tatsächlich hat: was muss noch
  nach SSI? (Apnoe bleibt dabei außen vor, die läuft bei SSI anders.) Die übrigen trennen nach
  Art des Tauchens: „Scuba" alles außer Apnoe, „Rec" davon Single Gas, „Tech" Multi-Gas und
  CCR. Eingeklappt, solange man ihn nicht braucht – auf dem Handy ist die Zeile sonst zwei
  Tauchgänge wert; ist gefiltert und die Zeile zu, sitzt ein Punkt am Symbol. Derselbe Filter
  sitzt auch über der gemeinsamen Liste hinter „Alle anzeigen"
- **Detailansicht** mit allen geladenen Werten (Tiefe, Dauer, Wassertemperatur, ...) und dem
  **QR-Code am Ende der Seite**, statt hinter einem weiteren Knopf: erst prüfen, dann scannen.
  Ein Tauchplatz, den man weiter oben zuordnet, ändert den Code sofort. Für schwierige Kameras
  lässt er sich weiterhin bildschirmfüllend anzeigen; das QR-Symbol oben im ersten Block
  springt direkt dorthin. Überschrift ist Garmins laufende Tauchgangsnummer („Tauchgang #260"),
  und wo Garmin keine liefert, die Art des Tauchgangs („Apnoe-Tauchgang")
- **Wischen zum nächsten Tauchgang**: links der frühere, rechts der spätere – durch alle
  geladenen Tauchgänge derselben Person, auch wenn man aus einer gemeinsamen Liste kommt oder
  von den fünf auf der Startseite. Einen Tauchtag arbeitet man am Stück durch, nicht über den
  Umweg der Liste
- **QR-Code-Export** im Format, das der SSI-QR-Scanner beim Anlegen eines Tauchgangs erwartet –
  inklusive der SSI-Mitgliedsnummer, wenn für den Account eine hinterlegt ist
- **SSI-Anmeldung pro Account**: wer mag, meldet sich bei seinem Garmin-Account zusätzlich bei
  SSI an. Die SSI-Mitgliedsnummer kommt dann direkt von SSI statt aus einem gescannten
  QR-Code – Scannen und Eintippen bleiben für alle, die kein SSI-Konto haben
- **Tauchplätze aus dem SSI-Logbuch**: dieselbe Anmeldung holt jeden Platz, an dem man laut
  SSI schon getaucht ist, mit Nummer, Name und Position auf das Gerät. Danach erkennt die App
  den Platz an der Position des Tauchgangs wieder und **übernimmt ihn direkt** – er landet als
  `site:` im QR-Code, ohne dass man ihn bestätigen muss. Stumm passiert das nie: Name, Nummer
  und die Entfernung, bei der er erkannt wurde, stehen da, der Knopf sagt „Tauchplatz
  automatisch übernommen", und ein Tipp ändert oder entfernt ihn. Liegen weitere Plätze im
  Umkreis, wird darauf hingewiesen – Plätze liegen an derselben Küste dicht beieinander, und
  SSI meldet nie, dass ein Tauchgang am falschen Ort abgelegt wurde. Ein Platz lässt sich
  weiterhin von Hand zuordnen (Nummer eintippen oder die Adresse der Platzseite einfügen).
  Eine **Karte** in der Detailansicht zeigt Tauchgang und zugeordneten Platz nebeneinander –
  die Frage „ist das der richtige Platz?" beantwortet ein Blick auf die Küstenlinie schneller
  als eine Zahl in Metern. Bis zu drei weitere bekannte Plätze im Umkreis von 15 km stehen
  als hellere Pins dabei; ein Tipp darauf ordnet den Tauchgang diesem Platz zu.
  Die Plätze gelten geräteweit, die Anmeldungen pro Person – ein Tauchplatz ist ein Ort, und
  den teilt die Familie. Unter „Einstellungen → SSI-Logbuch" stehen die bekannten Plätze,
  die verbundenen Konten und der Zeitpunkt des letzten Abgleichs
- **„In SSI übernommen"**: unter dem QR-Code lässt sich abhaken, dass der Tauchgang drüben
  angekommen ist; in der Liste steht dann ein grüner Haken neben dem Datum, in der
  Detailansicht neben der Art des Tauchgangs. Wer sein SSI-Konto
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
- **Der Tauchplatz lässt sich nicht aus den Koordinaten ableiten.** SSIs Platznummern stammen aus
  einer eigenen Datenbank ohne offene Abfrage. Die App holt sie deshalb aus dem eigenen
  SSI-Logbuch – über dieselbe inoffizielle Schnittstelle, die auch die SSI-App nutzt
  (`api.divessi.com/app/a21.php`). Das deckt jeden Platz ab, an dem man schon war. Ein neuer
  Platz ist zwangsläufig noch nicht dabei: den ordnet man einmal in der SSI-App zu, danach
  kennt ihn der nächste Abgleich. SSIs Web-Suche (`rest.divessi.com`) wäre die vollständigere
  Quelle, wurde aber geprüft und verworfen – sie steht hinter einer WAF, ihr API-Key hängt an
  einer Browser-Session, und sie antwortet mit HTML statt mit Daten.
- **Die laufende Tauchgangsnummer (`# 42`) ist Garmins Zählung, nicht die der Uhr.** Sie zählt
  die Tauchgänge im Garmin-Account: wer dort einen löscht, verschiebt alle nachfolgenden um
  eins nach unten, während die Uhr von ihrer eigenen Gesamtzahl weiterzählt. Die App reicht
  die Zahl durch, wie Garmin sie meldet – die gelöschten Tauchgänge sind weg, und ein
  geschätzter Versatz wäre für jeden falsch, dessen Logbuch vollständig ist.
- Vom SSI-Konto wird **nur der Sitzungs-Token** gespeichert, nie das Passwort. Läuft der Token ab,
  fragt die App erneut nach der Anmeldung.
- **Buddies lassen sich nicht mit einem Tauchgang übertragen.** SSIs Import-Format hat kein
  Feld dafür – die Auswahl unter dem QR-Code wurde deshalb wieder entfernt, statt sie
  funktionsfähig aussehen zu lassen. Die Buddy-Liste bleibt und kann jeden Eintrag als
  QR-Code zeigen, sodass ihn ein anderes Gerät scannen kann.
- **Die Karte ist die einzige Stelle, an der ein Dritter etwas erfährt.** Sonst spricht die App
  nur mit Garmin und SSI. Eine Kachel anzufordern verrät dem Kachelserver, wo dieser Tauchgang
  war – bewusst in Kauf genommen und so klein wie möglich gehalten: nur für den Tauchgang, der
  gerade geöffnet ist, nie in einer Liste, nie im Hintergrund, und ohne Angabe, wessen Tauchgang
  es ist. Die Kacheln kommen von [OpenStreetMap](https://www.openstreetmap.org/copyright); deren
  [Nutzungsrichtlinie](https://operations.osmfoundation.org/policies/tiles) sieht Apps ohne
  Absprache eigentlich nicht vor – bei der Nutzung im Familienkreis ist das Aufkommen
  vernachlässigbar, für eine weitere Verbreitung wäre ein eigener Kachel-Anbieter der richtige
  Schritt.
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
