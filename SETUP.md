# Setup unter Windows (VS Code)

Anleitung, um das Projekt lokal zu bauen und auf einem Android-Tablet/-Handy
zu testen.

> **iOS unter Windows nicht möglich:** iOS-Apps lassen sich ausschließlich auf
> einem Mac mit Xcode bauen (Apples Toolchain gibt es nicht für Windows). Ein
> per USB angeschlossenes iPhone/iPad taucht unter Windows deshalb gar nicht
> erst als Zielgerät auf. Optionen für später: ein Mac, oder ein Cloud-Build-
> Dienst wie Codemagic bzw. GitHub Actions mit macOS-Runner (zum Installieren
> auf einem echten iOS-Gerät ist dann zusätzlich ein Apple-Developer-Programm
> nötig). Für den vollständigen Funktionstest reicht Android völlig aus.
> Wenn ein Mac zur Hand ist: siehe **Abschnitt 3b**.

## 1. Vorbereitung (einmalig, ca. 30-60 Min inkl. Downloads)

1. **Git für Windows** installieren, falls noch nicht vorhanden:
   https://git-scm.com/download/win
2. **Flutter SDK** installieren:
   - ZIP von https://docs.flutter.dev/get-started/install/windows herunterladen
   - nach z.B. `C:\src\flutter` entpacken (nicht `C:\Program Files`, wegen
     Leerzeichen/Rechten)
   - `C:\src\flutter\bin` zum PATH hinzufügen (Windows-Suche → "Umgebungsvariablen
     bearbeiten")
3. **Android Studio** installieren (wird nur für das Android SDK gebraucht,
   nicht zum Programmieren): https://developer.android.com/studio
   - beim ersten Start den SDK-Setup-Assistenten durchlaufen lassen
   - **Wichtig:** anschließend die Command-line Tools nachinstallieren, sonst
     fehlt u.a. `avdmanager` (siehe Abschnitt 5, "Häufige Probleme"):
     Android Studio → Settings → `Languages & Frameworks` → **Android SDK** →
     Tab **SDK Tools** → Haken bei **"Android SDK Command-line Tools (latest)"**
     → Apply
4. **VS Code** + Erweiterungen installieren:
   - VS Code: https://code.visualstudio.com/
   - Erweiterungen: "Flutter" und "Dart" (von Dart Code) über den
     Extensions-Tab installieren
5. Terminal (PowerShell) öffnen und prüfen:
   ```
   flutter doctor
   ```
   Fehlt etwas (rotes Kreuz), zeigt `flutter doctor` direkt den nötigen
   nächsten Schritt an. Android-Lizenzen ggf. bestätigen:
   ```
   flutter doctor --android-licenses
   ```
   (alle mit `y` bestätigen)

## 2. Projekt auschecken

```powershell
git clone https://github.com/asautermeister/ssi-connect.git
cd ssi-connect
flutter pub get
```

Danach den Ordner `ssi-connect` in VS Code öffnen (`code .`).

## 3. Auf einem echten Android-Gerät testen (empfohlen statt Emulator)

Da die App als Tablet-App gedacht ist und mit echten Garmin-Zugangsdaten
läuft, ist ein echtes Gerät sinnvoller als der Emulator.

**a) Entwickleroptionen freischalten**

Einstellungen → "Über das Telefon" / "Telefoninfo" → 7x auf **"Build-Nummer"**
tippen, bis die Meldung "Du bist jetzt ein Entwickler" erscheint.

**b) Entwickleroptionen finden** – der Menüpunkt taucht je nach Hersteller an
unterschiedlicher Stelle auf und ist oft nicht dort, wo man ihn erwartet:

| Hersteller | Pfad |
|---|---|
| Pixel / Stock-Android | Einstellungen → **System** → Entwickleroptionen |
| Samsung | Einstellungen → ganz unten: **Entwickleroptionen** |
| Xiaomi / Redmi / POCO (MIUI/HyperOS) | Einstellungen → **Zusätzliche Einstellungen** → Entwickleroptionen |
| OnePlus / Oppo / Realme | Einstellungen → **Zusätzliche Einstellungen** → Entwickleroptionen |
| Huawei | Einstellungen → **System & Aktualisierungen** → Entwickleroptionen |

Am schnellsten geht es meist über die **Suchfunktion in den Einstellungen**:
oben in das Lupensymbol tippen und "Entwickler" oder "USB" eingeben.

**c) USB-Debugging aktivieren**

In den Entwickleroptionen **"USB-Debugging"** einschalten.
(Bei Xiaomi/MIUI zusätzlich **"USB-Debugging (Sicherheitseinstellungen)"**
aktivieren, sonst schlägt die Installation fehl – dafür muss ggf. eine
Mi-Konto-Anmeldung bestehen.)

**d) Gerät verbinden und starten**

1. Gerät per USB-Kabel an den PC anschließen (Datenkabel, kein reines Ladekabel)
2. Auf dem Gerät den Hinweis **"USB-Debugging zulassen?"** bestätigen
   (Häkchen "Von diesem Computer immer zulassen" setzen)
3. Prüfen, ob das Gerät erkannt wird:
   ```powershell
   flutter devices
   ```
4. In VS Code unten rechts in der Statusleiste das Gerät als Zielgerät auswählen
5. Mit F5 (oder `flutter run` im Terminal) starten

**Alternative ohne echtes Gerät:** In Android Studio unter "Device Manager" ein
virtuelles Gerät (Tablet-Profil) anlegen und in VS Code als Zielgerät wählen.
Zum Testen des QR-Codes muss dann das Handy mit der SSI-App den QR-Code vom
PC-Bildschirm abscannen.

## 3b. Auf einem iPhone/iPad testen (braucht einen Mac)

Nur der Vollständigkeit halber hier, weil unter Windows nichts davon geht –
siehe Kasten ganz oben. Auf einem Mac ist es dafür kurz.

**Einmalig:**

1. **Xcode** aus dem App Store installieren, einmal öffnen und die
   Lizenzabfrage bestätigen. Danach im Terminal:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
2. **CocoaPods** installieren (verwaltet die iOS-Abhängigkeiten der Plugins):
   ```bash
   sudo gem install cocoapods
   ```
3. **Flutter SDK** wie unter Punkt 1, nur die macOS-Variante. Prüfen mit
   `flutter doctor` – für iOS müssen die Häkchen bei „Xcode" und
   „CocoaPods" stehen.

**Signieren (der Teil, der erfahrungsgemäß hakt):**

Apple lässt nichts ohne Signatur auf ein Gerät. Eine kostenlose Apple-ID
reicht zum Testen:

1. `ios/Runner.xcworkspace` in Xcode öffnen – **nicht** `Runner.xcodeproj`,
   sonst fehlen die Plugin-Abhängigkeiten.
2. Links `Runner` anwählen → Tab **Signing & Capabilities**.
3. Haken bei **Automatically manage signing**, bei **Team** die eigene
   Apple-ID wählen (ggf. über „Add an Account…" anlegen).
4. **Bundle Identifier** auf etwas Eigenes ändern, z.B.
   `de.deinname.ssiconnect`. Der Standardwert `com.ssiconnect.ssiConnect`
   funktioniert nur, solange ihn nicht schon jemand registriert hat.

**Bauen und starten:**

```bash
flutter pub get
flutter devices                 # iPhone/iPad muss hier auftauchen
flutter run --release -d <ID aus flutter devices>
```

Beim allerersten Start meldet das Gerät „Nicht vertrauter Entwickler".
Auf dem iPhone/iPad: **Einstellungen → Allgemein → VPN & Geräteverwaltung →
eigene Apple-ID → Vertrauen**. Danach startet die App.

**Was du dabei wissen solltest:**

- Mit einer **kostenlosen** Apple-ID läuft die Installation nach **7 Tagen**
  ab; danach einfach erneut `flutter run` – dieselben Daten bleiben erhalten.
  Mit dem kostenpflichtigen Developer-Programm (99 $/Jahr) sind es 12 Monate,
  und TestFlight wird möglich.
- Die App braucht **iOS 14 oder neuer** (`file_picker` setzt das voraus).
- Beim ersten Scannen fragt iOS nach der **Kamera-Erlaubnis**. Wird sie
  abgelehnt, lässt sie sich nur in den Systemeinstellungen wieder erteilen –
  die SSI-Nummer kann man alternativ immer von Hand eintippen.
- Das **Tablet ist das Anzeigegerät**: den QR-Code muss ein *zweites* Gerät
  mit der SSI-App abscannen.

## 4. Nützliche Befehle

```powershell
flutter analyze      # Statische Codeprüfung
flutter test         # Unit-Tests (laufen ohne Gerät/Emulator)
flutter devices      # Zeigt erkannte Geräte/Emulatoren
flutter run          # App bauen + auf gewähltem Gerät starten
flutter pub get      # Nach jedem Pull: Abhängigkeiten aktualisieren
```

## 5. Häufige Probleme

**"avdmanager is missing from the Android SDK"** (beim Anlegen eines Emulators)

Das Paket "Android SDK Command-line Tools" fehlt – Android Studio installiert es
nicht immer automatisch mit. Nachinstallieren:
Android Studio → Settings → `Languages & Frameworks` → **Android SDK** →
Tab **SDK Tools** → Haken bei **"Android SDK Command-line Tools (latest)"** →
Apply. Danach VS Code neu starten.

**Entwickleroptionen sind freigeschaltet, aber nicht auffindbar**

Siehe Tabelle in Abschnitt 3b – der Menüpunkt liegt je nach Hersteller an
unterschiedlicher Stelle. Notfalls die Suche in den Einstellungen nutzen.

**Gerät wird von `flutter devices` nicht angezeigt**

- Ein reines Ladekabel verwendet? Ein Datenkabel nutzen.
- USB-Modus am Gerät auf "Dateiübertragung" statt "Nur laden" stellen
  (Benachrichtigungsleiste antippen).
- USB-Debugging-Dialog auf dem Gerät bestätigt?
- Bei manchen Windows-Systemen fehlt der USB-Treiber des Herstellers –
  Google USB Driver via Android Studio → SDK Manager → SDK Tools installieren.

**iOS-Gerät wird nicht erkannt**

Erwartetes Verhalten unter Windows – siehe Hinweis ganz oben.

## 6. Bekannte offene Punkte beim ersten echten Test

- Der Garmin-Login ist eine inoffizielle Schnittstelle und kann fehlschlagen
  (Cloudflare-Blockade, geänderte API) - siehe Fehlermeldung in der App. In dem
  Fall über den Upload-Button den FIT-Datei-Import als Alternative nutzen.
- Die genauen Feldnamen für Tiefe/Wassertemperatur bei Tauchgängen sind noch
  nicht gegen einen echten Account verifiziert.
- Bitte beim ersten erfolgreichen Login mit einem echten Tauchgang kurz
  Rückmeldung geben (oder die Rohdaten teilen), damit das Dive-Mapping bei
  Bedarf korrigiert werden kann.
