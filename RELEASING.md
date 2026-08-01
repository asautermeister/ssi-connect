# Eine Version veröffentlichen

Der Workflow [`.github/workflows/release.yml`](.github/workflows/release.yml)
baut auf einen Versions-Tag hin die Android-APK und eine unsignierte iOS-App
und hängt beides an ein GitHub-Release.

Die Dateien liegen bewusst **nicht im Repository**: eine APK ist einige
Dutzend Megabyte und bliebe für immer in der Git-Historie – löschen hilft
dort nicht, das Objekt bleibt und jeder `git clone` lädt es mit. Release-
Assets hängen dagegen am Tag und lassen sich jederzeit entfernen.

## Einmalig: Keystore anlegen

Android akzeptiert ein Update nur, wenn es mit **demselben Schlüssel**
signiert ist wie die installierte Version. Ohne eigenen Keystore signiert
der Build mit dem Debug-Schlüssel – und der wird auf jedem Rechner neu
erzeugt. Die erste Aktualisierung würde dann scheitern, und der einzige
Ausweg wäre deinstallieren und neu installieren, samt Verlust aller
gespeicherten Accounts.

Deshalb einmal einen eigenen Schlüssel erzeugen. **Das passiert auf deinem
Rechner, nicht hier**: der private Schlüssel darf die Maschine nur als
verschlüsseltes GitHub-Secret verlassen. Wer ihn hat, kann Updates
signieren, die Android als echte Aktualisierung dieser App akzeptiert.

PowerShell, im Ordner deiner Wahl (**nicht** im Projektordner):

```powershell
keytool -genkeypair -v `
  -keystore ssi-connect-upload.jks `
  -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 `
  -alias upload
```

`keytool` gehört zum JDK, das Android Studio mitbringt. Wird es nicht
gefunden, hilft der volle Pfad, z.B.
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.

Das Programm fragt nach einem Passwort und ein paar Angaben zur Person –
letztere sind für eine sideload-Installation ohne Bedeutung, dürfen aber
nicht leer bleiben. Merke dir das Passwort und den Alias (`upload`).

> **Sichere die `.jks`-Datei und das Passwort.** Geht beides verloren, lässt
> sich diese App nie wieder aktualisieren – auch nicht von dir. Ein
> Passwort-Manager oder ein Backup außerhalb des Rechners sind hier keine
> Übervorsicht.

## Einmalig: Secrets in GitHub hinterlegen

Die Keystore-Datei als Base64 in die Zwischenablage:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ssi-connect-upload.jks")) | Set-Clipboard
```

Dann unter **Settings → Secrets and variables → Actions → New repository
secret** vier Einträge anlegen:

| Name | Inhalt |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | der eben kopierte Base64-Text |
| `ANDROID_KEYSTORE_PASSWORD` | das Keystore-Passwort |
| `ANDROID_KEY_PASSWORD` | das Schlüssel-Passwort (meist dasselbe) |
| `ANDROID_KEY_ALIAS` | `upload` |

Fehlt `ANDROID_KEYSTORE_BASE64`, bricht der Workflow nicht ab: er baut mit
dem Debug-Schlüssel weiter und schreibt eine Warnung ins Protokoll. Zum
Ausprobieren brauchbar, zum Verteilen nicht.

## Lokal signiert bauen (optional)

Für einen signierten Build auf dem eigenen Rechner eine Datei
`android/key.properties` anlegen – sie ist git-ignoriert:

```properties
storeFile=C:/Pfad/zu/ssi-connect-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Ohne diese Datei bleibt es beim Debug-Schlüssel, und `flutter run --release`
funktioniert wie gehabt.

## Version erhöhen und veröffentlichen

1. In `pubspec.yaml` die Zeile `version:` erhöhen, z.B. `1.0.1+2`.
   Die Zahl hinter dem `+` ist der `versionCode`; **Android akzeptiert ein
   Update nur, wenn sie steigt.**
2. In `lib/app_info.dart` dieselbe Version eintragen. Vergisst man das,
   schlägt `flutter test` an – die beiden Stellen werden gegeneinander
   geprüft.
3. Committen, dann:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Der Workflow läuft an, prüft `flutter analyze` und die Tests, baut beide
Plattformen und legt das Release an. Dauer: rund zehn Minuten, der
iOS-Anteil ist der langsame.

Ein Lauf ohne Tag geht über **Actions → Release → Run workflow**. Der baut
dieselben Dateien, legt aber kein Release an, sondern hängt sie als
Artefakte an den Lauf.

## Was bei iOS herauskommt

Eine **unsignierte** `.ipa`. Ohne Apple-Developer-Programm (99 $/Jahr) kann
GitHub sie nicht signieren, und unsigniert installiert iOS nichts. Sie lässt
sich mit **Sideloadly** oder **AltStore** unter der eigenen Apple-ID neu
signieren; mit einer kostenlosen Apple-ID läuft die Installation nach sieben
Tagen ab und muss erneuert werden.

Für ein, zwei eigene Geräte ist der Weg aus [`SETUP.md`](SETUP.md),
Abschnitt 3b, meist einfacher: einmal mit Xcode direkt auf das Gerät bauen.
Die `.ipa` lohnt sich vor allem, wenn jemand ohne Mac das Gerät bestücken
soll.
