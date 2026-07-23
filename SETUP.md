# Setup unter Windows (VS Code)

Anleitung, um das Projekt lokal zu bauen und auf einem Android-Tablet/-Handy
zu testen. iOS-Builds brauchen einen Mac mit Xcode - unter Windows nicht
möglich, dafür später ggf. ein Cloud-Build-Dienst (z.B. Codemagic) oder
Zugriff auf einen Mac.

## 1. Vorbereitung (einmalig, ca. 30-60 Min inkl. Downloads)

1. **Git für Windows** installieren, falls noch nicht vorhanden:
   https://git-scm.com/download/win
2. **Flutter SDK** installieren:
   - ZIP von https://docs.flutter.dev/get-started/install/windows herunterladen
   - nach z.B. `C:\src\flutter` entpacken (nicht `C:\Program Files`, wegen
     Leerzeichen/Rechten)
   - `C:\src\flutter\bin` zum PATH hinzufügen (Windows-Suche → "Umgebungsvariablen
     bearbeiten")
3. **Android Studio** installieren (wird nur für das Android SDK + den
   Emulator gebraucht, nicht zum Programmieren):
   https://developer.android.com/studio
   - beim ersten Start den SDK-Setup-Assistenten durchlaufen lassen
     (installiert Android SDK, Platform-Tools, ein Emulator-Image)
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
git checkout claude/ssi-connect-new-project-t7rsej
flutter pub get
```

Danach den Ordner `ssi-connect` in VS Code öffnen (`code .`).

## 3. Auf einem echten Android-Gerät testen (empfohlen statt Emulator)

Da die App als Tablet-App gedacht ist und mit echten Garmin-Zugangsdaten
läuft, ist ein echtes Gerät sinnvoller als der Emulator:

1. Auf dem Android-Tablet/-Handy: Einstellungen → Über das Telefon →
   7x auf "Build-Nummer" tippen (aktiviert Entwickleroptionen)
2. Einstellungen → Entwickleroptionen → "USB-Debugging" aktivieren
3. Gerät per USB-Kabel an den PC anschließen, auf dem Gerät den Hinweis
   "USB-Debugging zulassen?" bestätigen
4. In VS Code unten rechts in der Statusleiste das Gerät als Zielgerät
   auswählen (oder `flutter devices` im Terminal zur Kontrolle)
5. Mit F5 (oder `flutter run` im Terminal) starten

Alternativ ohne echtes Gerät: in Android Studio unter "Device Manager" ein
virtuelles Gerät (Tablet-Profil) anlegen und in VS Code als Zielgerät wählen.

## 4. Nützliche Befehle

```powershell
flutter analyze     # Statische Codeprüfung
flutter test         # Unit-Tests (laufen ohne Gerät/Emulator)
flutter run          # App bauen + auf gewähltem Gerät starten
flutter pub get      # Nach jedem Pull: Abhängigkeiten aktualisieren
```

## 5. Bekannte offene Punkte beim ersten echten Test

- Der Garmin-Login ist eine inoffizielle Schnittstelle und kann fehlschlagen
  (Cloudflare-Blockade, geänderte API) - siehe Fehlermeldung in der App.
- Die genauen Feldnamen für Tiefe/Wassertemperatur bei Tauchgängen sind noch
  nicht gegen einen echten Account verifiziert.
- Bitte beim ersten erfolgreichen Login mit einem echten Tauchgang kurz
  Rückmeldung geben (oder die Rohdaten teilen), damit das Dive-Mapping bei
  Bedarf korrigiert werden kann.
