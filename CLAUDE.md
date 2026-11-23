# SSI Connect

Flutter-App für Tablets: liest Tauchgänge aus Garmin Connect und zeigt sie
als QR-Code, den die offizielle SSI-App einliest.

## Nach jedem Merge aus `master`: Review und Aufräumen

**Stehende Regel.** Sobald ein Pull Request nach `master` gemergt wurde —
oder `master` in den Arbeitsbranch gezogen wird — laufen zwei Durchgänge,
bevor neue Funktionen gebaut werden:

### 1. Sicherheits-Durchgang

An OWASP entlang, aber mit den Schwerpunkten, die diese App wirklich hat:

- **Zugangsdaten und Tokens** — alles gehört in den verschlüsselten
  Keystore (`FlutterSecureStorage`), nichts in `SharedPreferences`, nichts
  in ein Log.
- **Das API-Log** (`ApiLogInterceptor`) ist zum Kopieren und Teilen gebaut.
  Jedes neue Feld in einer API-Antwort ist zu prüfen: Geheimnisse *und*
  Personendaten Dritter müssen redigiert sein. Der Import verwirft
  Geburtsdatum, Stadt, Telefon und Foto bewusst — über das Log dürfen sie
  nicht doch hinausgehen.
- **QR-Payloads** — jedes neue Feld durch `ssiPayloadValue()`. Freitext aus
  fremden Logbüchern landet sonst als zusätzliches Feld beim Empfänger.
- **Plattform-Konfiguration** — Manifest, `gradle.properties`, Info.plist.
- Abhängigkeiten: `flutter pub outdated`, besonders alles mit
  Plattform-Code.

Was ausdrücklich in Ordnung ist, steht in `BACKLOG.md` unter „Aufräumen und
Härten" — **erst dort nachsehen**, statt es erneut herzuleiten.

### 2. Code-Optimierung

- Nicht mehr aufgerufene Member und ungenutzte l10n-Strings.
- Doppelter Code, der zu einer Stelle zusammengezogen gehört.
- Jeden Treffer **einzeln von Hand nachprüfen**: `AccountColor`-Werte sind
  über `.values` erreichbar, `isSupported`/`shouldReload` sind
  Framework-Overrides, und `apply false` in Gradle heißt nicht
  „wirkungslos". Für all das gab es schon falsche Befunde.
- Nur aus Tests erreichbarer Code wird **nicht** blind gelöscht: wo ein
  Test eine Eigenschaft absichert, ist er der Grund für ihre Existenz.

### Ergebnis

Was eindeutig und prüfbar ist, wird behoben — mit Test. Alles andere kommt
nach `BACKLOG.md`, zusammen mit dem Grund, **warum** es nicht gemacht
wurde. Erledigtes wird dort gelöscht; die Historie steht im Git-Log.

## Grenzen der Cloud-Umgebung

Lokal (Windows, Pixel 7 per USB) laufen Gradle-Builds und `flutter run`;
dort lassen sich Gradle, Manifest und Signierung am Gerät prüfen. Das
Folgende gilt nur für den Cloud-Container:

- `flutter analyze` und `flutter test` laufen hier. **Gradle-Builds nicht**
  — es gibt kein Android-SDK. An Gradle, Manifest oder Signierung wird
  deshalb nichts geändert, ohne dass ein echter Gerätebuild es bestätigt.
- Das Flutter-SDK verschwindet gelegentlich aus dem Container. Die Version
  steht in `.github/workflows/release.yml` und ist mit
  `git clone --depth 1 -b <version> https://github.com/flutter/flutter.git`
  wiederherstellbar.

## Arbeitsweise, die sich hier bewährt hat

- **Formatieren mit der Flutter-Version aus `release.yml`.** Ein älteres
  `dart format` bricht anders um, und jeder Commit aus der anderen
  Umgebung schreibt dieselben Zeilen dann wieder zurück.

- **Nie eine Zuordnung raten.** SSIs Format und Garmins Feldnamen sind
  nicht dokumentiert; beides wurde aus echten Mitschnitten rekonstruiert.
  Ein ausgelassenes Feld wird nicht importiert, ein falsch geratenes landet
  still falsch im Logbuch. Geraten wurde hier dreimal, und dreimal falsch.
- **Belege in den Doc-Kommentar**, wo der Code steht — nicht nur in den
  Commit.
- **Verhalten mit Tests festnageln**, besonders das, was nur an echten
  Daten belegt ist.
- Antworten an den Nutzer auf **Deutsch**.
