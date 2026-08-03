# Setup

Anleitung, um das Projekt lokal zu bauen und auf einem Gerät zu testen.

Sie ist bewusst nicht auf eine Kombination aus Betriebssystem und Editor
zugeschnitten. Der gemeinsame Nenner ist das **Terminal**: alles, was hier
steht, funktioniert unter Windows, macOS und Linux mit denselben
`flutter`-Befehlen. Wo ein Editor etwas bequemer macht, steht es dabei –
nötig ist keiner.

| Ziel | Windows | macOS | Linux |
|---|---|---|---|
| Android bauen und testen | ja | ja | ja |
| iOS bauen und testen | **nein** | ja | **nein** |

> **iOS gibt es nur auf einem Mac.** Apples Toolchain (Xcode) läuft
> ausschließlich unter macOS; ein per USB angeschlossenes iPhone taucht
> unter Windows oder Linux gar nicht erst als Zielgerät auf. Ohne Mac
> bleiben ein Cloud-Build-Dienst oder der GitHub-Actions-Workflow aus
> [`RELEASING.md`](RELEASING.md). Für einen vollständigen Funktionstest
> reicht Android völlig aus.

## 1. Grundinstallation

Drei Dinge braucht jeder, unabhängig vom System: Git, das Flutter SDK und
ein Java 17. Für Android kommt das Android SDK dazu, für iOS Xcode.

### 1.1 Git

- **Windows:** https://git-scm.com/download/win
- **macOS:** ist nach `xcode-select --install` dabei, sonst `brew install git`
- **Linux:** `sudo apt install git` o.ä.

### 1.2 Flutter SDK

Das Projekt braucht Dart **3.12.2 oder neuer** (siehe `environment` in
`pubspec.yaml`), also ein entsprechend aktuelles Flutter.

- **Windows:** ZIP von https://docs.flutter.dev/get-started/install/windows
  nach z.B. `C:\src\flutter` entpacken – **nicht** nach `C:\Program Files`,
  der Leerzeichen und Schreibrechte wegen. Dann `C:\src\flutter\bin` zum
  PATH hinzufügen (Windows-Suche → „Umgebungsvariablen bearbeiten").
- **macOS:** ZIP von https://docs.flutter.dev/get-started/install/macos nach
  z.B. `~/development/flutter` entpacken und `export PATH="$PATH:$HOME/development/flutter/bin"`
  in `~/.zshrc` eintragen. Auf Apple Silicon zusätzlich einmalig:
  ```bash
  sudo softwareupdate --install-rosetta --agree-to-license
  ```
  Einige Android- und iOS-Werkzeuge sind weiterhin x86-Binaries.
- **Linux:** Tarball von https://docs.flutter.dev/get-started/install/linux
  entpacken und `bin` in den PATH.

Homebrew (`brew install --cask flutter`) und andere Paketmanager gehen auch;
der offizielle Weg ist der ZIP, weil `flutter upgrade` dann selbst
aktualisiert und nicht mit dem Paketmanager streitet.

### 1.3 Java 17

Das Android-Build ist auf Java 17 festgelegt (`android/app/build.gradle.kts`).
Neuere JDKs brechen den Gradle-Lauf.

- **Mit Android Studio:** nichts zu tun, dessen mitgeliefertes JBR passt.
- **Ohne Android Studio:** ein JDK 17 installieren (Temurin, Zulu,
  `brew install openjdk@17`, `apt install openjdk-17-jdk`) und Flutter darauf
  zeigen lassen:
  ```bash
  flutter config --jdk-dir "<Pfad zum JDK 17>"
  ```

### 1.4 Android SDK – zwei Wege

**Weg A: Android Studio** (der bequeme, ~1 GB extra)

https://developer.android.com/studio installieren, beim ersten Start den
SDK-Assistenten durchlaufen lassen. Danach **unbedingt** die Command-line
Tools nachinstallieren, sonst fehlt u.a. `avdmanager` und
`flutter doctor --android-licenses` schlägt fehl:

Settings → `Languages & Frameworks` → **Android SDK** → Tab **SDK Tools** →
Haken bei **„Android SDK Command-line Tools (latest)"** → Apply.

Android Studio muss man danach nicht zum Programmieren benutzen – es liefert
nur das SDK.

**Weg B: nur die Command-line Tools** (schlank, ohne IDE)

„Command line tools only" von https://developer.android.com/studio
herunterladen, nach `<sdk>/cmdline-tools/latest/` entpacken, dann:

```bash
export ANDROID_HOME="<sdk>"          # Windows: Umgebungsvariable setzen
sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35"
flutter config --android-sdk "$ANDROID_HOME"
```

Welche `platforms;`- und `build-tools;`-Version genau nötig ist, sagt
`flutter doctor` – es nennt die fehlende Version beim Namen, statt dass man
raten müsste.

### 1.5 Xcode (nur macOS, nur für iOS)

1. **Xcode** aus dem App Store, einmal öffnen, Lizenz bestätigen. Danach:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
2. **CocoaPods** (verwaltet die iOS-Abhängigkeiten der Plugins):
   ```bash
   brew install cocoapods
   ```
   `sudo gem install cocoapods` geht auch, scheitert auf neueren macOS-
   Versionen aber gern an der system-eigenen Ruby-Installation.

### 1.6 Prüfen

```bash
flutter doctor
```

Für Android müssen die Häkchen bei „Flutter" und „Android toolchain" stehen,
für iOS zusätzlich bei „Xcode" und „CocoaPods". Ein Kreuz bei „Android
Studio" oder „VS Code" ist **kein Problem** – das sind Bequemlichkeiten, keine
Voraussetzungen. Lizenzen bestätigen:

```bash
flutter doctor --android-licenses
```

## 2. Editor – freie Wahl

Zum Bauen und Starten reicht das Terminal. Wer Sprungmarken, Autovervoll-
ständigung und einen Debugger will, nimmt eines davon:

| Editor | Was zu installieren ist | Starten |
|---|---|---|
| **VS Code / VSCodium** | Erweiterungen „Flutter" und „Dart" (Dart Code) | Gerät unten rechts in der Statusleiste wählen, dann `F5` |
| **Android Studio / IntelliJ** | Plugins „Flutter" und „Dart" | Gerät oben in der Toolbar wählen, dann Run |
| **Neovim / Emacs / Zed / …** | LSP gegen `dart language-server` | `flutter run` im Terminal |
| **gar keiner** | – | `flutter run` im Terminal |

Alle Beispiele unten sind Terminal-Befehle, weil die überall gleich sind.
Unter Windows funktionieren sie in PowerShell, in der Eingabeaufforderung
und in Git Bash gleichermaßen.

## 3. Projekt holen

```bash
git clone https://github.com/asautermeister/ssi-connect.git
cd ssi-connect
flutter pub get
```

`flutter pub get` nach jedem `git pull` wiederholen, wenn sich
`pubspec.yaml` geändert hat.

## 4. Auf einem Android-Gerät testen

Ein echtes Gerät ist sinnvoller als der Emulator: die App ist als Tablet-App
gedacht, läuft mit echten Garmin-Zugangsdaten, und der QR-Code muss ohnehin
von einem *zweiten* Gerät abgescannt werden.

**a) Entwickleroptionen freischalten**

Einstellungen → „Über das Telefon" / „Telefoninfo" → 7× auf **„Build-Nummer"**
tippen, bis „Du bist jetzt ein Entwickler" erscheint.

**b) Entwickleroptionen finden** – der Menüpunkt liegt je nach Hersteller
woanders:

| Hersteller | Pfad |
|---|---|
| Pixel / Stock-Android | Einstellungen → **System** → Entwickleroptionen |
| Samsung | Einstellungen → ganz unten: **Entwickleroptionen** |
| Xiaomi / Redmi / POCO (MIUI/HyperOS) | Einstellungen → **Zusätzliche Einstellungen** → Entwickleroptionen |
| OnePlus / Oppo / Realme | Einstellungen → **Zusätzliche Einstellungen** → Entwickleroptionen |
| Huawei | Einstellungen → **System & Aktualisierungen** → Entwickleroptionen |

Am schnellsten geht die **Suche in den Einstellungen**: „Entwickler" oder
„USB" eintippen.

**c) USB-Debugging aktivieren**

In den Entwickleroptionen **„USB-Debugging"** einschalten. Bei Xiaomi/MIUI
zusätzlich **„USB-Debugging (Sicherheitseinstellungen)"**, sonst schlägt die
Installation fehl – dafür ist ggf. eine Mi-Konto-Anmeldung nötig.

**d) Verbinden und starten**

1. Datenkabel verwenden, kein reines Ladekabel.
2. Auf dem Gerät **„USB-Debugging zulassen?"** bestätigen, Haken bei „Von
   diesem Computer immer zulassen".
3. ```bash
   flutter devices        # Gerät muss hier auftauchen
   flutter run            # bei mehreren Geräten: -d <ID aus flutter devices>
   ```

**Ohne Kabel:** `adb pair` / `adb connect` über WLAN-Debugging in den
Entwickleroptionen – praktisch bei einem Tablet, das ohnehin nur auf dem
Tisch liegt.

**Ohne echtes Gerät:** Emulator anlegen, entweder über Android Studio →
*Device Manager* oder auf der Kommandozeile:

```bash
sdkmanager "system-images;android-35;google_apis;x86_64"
avdmanager create avd -n tablet -k "system-images;android-35;google_apis;x86_64"
emulator -avd tablet
```

Den QR-Code muss dann ein Handy mit der SSI-App vom Bildschirm abscannen.

## 5. Auf einem iPhone/iPad testen (nur macOS)

**Signieren – der Teil, der erfahrungsgemäß hakt.** Apple lässt nichts ohne
Signatur auf ein Gerät; eine kostenlose Apple-ID reicht zum Testen:

1. `ios/Runner.xcworkspace` in Xcode öffnen – **nicht** `Runner.xcodeproj`,
   sonst fehlen die Plugin-Abhängigkeiten.
2. Links `Runner` anwählen → Tab **Signing & Capabilities**.
3. Haken bei **Automatically manage signing**, bei **Team** die eigene
   Apple-ID wählen (ggf. über „Add an Account…" anlegen).
4. **Bundle Identifier** auf etwas Eigenes ändern, z.B.
   `de.deinname.ssiconnect`. Der Standardwert funktioniert nur, solange ihn
   nicht schon jemand registriert hat.

Das ist der einzige Schritt, für den Xcode wirklich aufgehen muss – gebaut
wird danach wieder im Terminal:

```bash
flutter pub get
flutter devices
flutter run --release -d <ID aus flutter devices>
```

Beim allerersten Start meldet das Gerät „Nicht vertrauter Entwickler":
**Einstellungen → Allgemein → VPN & Geräteverwaltung → eigene Apple-ID →
Vertrauen**.

**Was man dazu wissen sollte:**

- Mit einer **kostenlosen** Apple-ID läuft die Installation nach **7 Tagen**
  ab; danach einfach erneut `flutter run`, die Daten bleiben erhalten. Mit dem
  kostenpflichtigen Developer-Programm (99 $/Jahr) sind es 12 Monate, und
  TestFlight wird möglich.
- Die App braucht **iOS 14 oder neuer** (`IPHONEOS_DEPLOYMENT_TARGET = 14.0`,
  von `file_picker` vorgegeben).
- Beim ersten Scannen fragt iOS nach der **Kamera-Erlaubnis**. Wird sie
  abgelehnt, lässt sie sich nur in den Systemeinstellungen wieder erteilen –
  die SSI-Nummer kann man alternativ immer von Hand eintippen.

## 6. Nützliche Befehle

```bash
flutter analyze      # Statische Codeprüfung
flutter test         # Unit-Tests (laufen ohne Gerät/Emulator)
dart format lib test tool
flutter devices      # Zeigt erkannte Geräte/Emulatoren
flutter run          # App bauen + auf gewähltem Gerät starten
flutter pub get      # Nach einem Pull mit geändertem pubspec.yaml
flutter clean        # Wenn ein Build unerklärlich bleibt
```

Vor einem Commit sollten `dart format`, `flutter analyze` und `flutter test`
durchlaufen – dieselben drei, die auch der Release-Workflow prüft.

## 7. Häufige Probleme

**„avdmanager is missing from the Android SDK"** *(alle Systeme)*

Das Paket „Android SDK Command-line Tools" fehlt; Android Studio installiert
es nicht immer mit. Siehe Abschnitt 1.4, danach den Editor neu starten.

**Gradle bricht mit einer Java-Version ab** *(alle Systeme)*

Das Projekt braucht Java 17, gefunden wird ein neueres. Siehe Abschnitt 1.3.
Prüfen mit `flutter doctor -v`, dort steht das benutzte JDK.

**Gerät wird von `flutter devices` nicht angezeigt** *(alle Systeme)*

- Ein reines Ladekabel verwendet? Datenkabel nutzen.
- USB-Modus am Gerät auf „Dateiübertragung" statt „Nur laden" stellen.
- USB-Debugging-Dialog auf dem Gerät bestätigt?
- `adb devices` zeigt oft mehr als `flutter devices`; steht dort
  `unauthorized`, fehlt die Bestätigung auf dem Gerät.

**Kein Zielgerät, obwohl das Kabel steckt** *(Windows)*

Es fehlt der USB-Treiber des Herstellers. Google USB Driver über Android
Studio → SDK Manager → SDK Tools installieren, bei anderen Herstellern deren
eigenen.

**`pod install` scheitert** *(macOS)*

Meist eine zu alte oder eine System-Ruby-CocoaPods-Installation. `brew install
cocoapods` statt `sudo gem install`, dann:
```bash
cd ios && pod repo update && pod install
```

**„Command PhaseScriptExecution failed"** *(macOS)*

Fast immer ein Signierungsproblem – Abschnitt 5, Punkte 2–4. Danach einmal
`flutter clean`.

**iOS-Gerät wird nicht erkannt** *(Windows/Linux)*

Erwartetes Verhalten – siehe Kasten ganz oben.

## 8. Bekannte offene Punkte

- Der Garmin-Login nutzt eine **inoffizielle Schnittstelle** und kann
  fehlschlagen (Cloudflare-Blockade, geänderte API). Die App sagt es in der
  Fehlermeldung; als Ausweg gibt es den FIT-Datei-Import.
- Das Mapping der Garmin-Felder auf Tiefe, Dauer und Wassertemperatur ist
  gegen echte Aktivitäten geprüft, aber nicht gegen jedes Uhrenmodell. Weicht
  ein Wert ab, hilft die Diagnose-Funktion in der App (Info-Screen, 3× auf die
  Versionsnummer tippen) – deren `PROBE`-Ausgabe zeigt die Rohfelder der
  Garmin-Antwort.
- Das SSI-QR-Format ist rekonstruiert, nicht dokumentiert. Felder, deren
  Bedeutung nicht belegt ist, bleiben absichtlich leer; die Begründung steht
  jeweils in `lib/ssi/ssi_qr_payload_builder.dart`.
