import 'app_strings.dart';

/// German - the language the app was written in, and the fallback for any
/// device language that isn't English.
class AppStringsDe extends AppStrings {
  const AppStringsDe();

  @override
  String get languageName => 'Deutsch';

  @override
  String get appName => 'SSI Connect';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get save => 'Speichern';
  @override
  String get remove => 'Entfernen';
  @override
  String get edit => 'Bearbeiten';
  @override
  String get options => 'Optionen';
  @override
  String get retry => 'Erneut versuchen';
  @override
  String get name => 'Name';
  @override
  String get number => 'Nummer';
  @override
  String get yes => 'Ja';
  @override
  String get no => 'Nein';

  @override
  String atTime(String time) => '$time Uhr';

  @override
  List<String> get weekdaysShort => const [
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So',
  ];

  @override
  String get accountsSection => 'Accounts';
  @override
  String get moreSection => 'Mehr';
  @override
  String get addAccount => 'Account';
  @override
  String get recentDives => 'Zuletzt getaucht';
  @override
  String get showAll => 'Alle anzeigen';
  @override
  String get divesLoading => 'Tauchgänge werden geladen …';
  @override
  String get divesLoadFailedPullToRetry =>
      'Tauchgänge konnten nicht geladen werden. '
      'Zum Erneut-Versuchen nach unten ziehen.';
  @override
  String get noDivesLoadedYet => 'Noch keine Tauchgänge geladen.';
  @override
  String get oneAccountFailed => 'Ein Account konnte nicht geladen werden.';
  @override
  String accountsFailed(int count) =>
      '$count Accounts konnten nicht geladen werden.';
  @override
  String get noAccountYetTitle => 'Noch kein Garmin-Account verbunden';
  @override
  String get noAccountYetBody =>
      'Verbinde einen Account, um Tauchgänge zu laden – oder importiere '
      'unten eine FIT-Datei.';
  @override
  String get divesUnreachable => 'Tauchgänge nicht erreichbar';
  @override
  String get noDivesFound => 'Keine Tauchgänge gefunden';
  @override
  String lastDive(String date, String depth) => 'Zuletzt: $date · $depth m';
  @override
  String ssiNumber(String memberId) => 'SSI-Nr. $memberId';
  @override
  String get storeSsiNumber => 'SSI-Nummer hinterlegen';

  @override
  String get renameAccount => 'Namen ändern';
  @override
  String get chooseColour => 'Farbe wählen';
  @override
  String get ssiIdentity => 'SSI-Identität';
  @override
  String get deleteStoredDives => 'Gespeicherte Tauchgänge löschen';
  @override
  String get removeAccount => 'Account entfernen';
  @override
  String get storedDivesDeleted => 'Gespeicherte Tauchgänge gelöscht';
  @override
  String get removeAccountQuestion => 'Account entfernen?';
  @override
  String removeAccountBody(String name) =>
      '$name wird mitsamt den gespeicherten Tauchgängen von diesem Gerät '
      'entfernt. Für einen erneuten Zugriff ist ein neuer Login nötig.';
  @override
  String get colour => 'Farbe';
  @override
  String get colourExplanation =>
      'Markiert die Tauchgänge dieser Person am linken Rand.';
  @override
  String get noColour => 'Keine Farbe';
  @override
  String get displayedName => 'Angezeigter Name';
  @override
  String get leaveEmptyForEmail => 'Leer lassen für die E-Mail-Adresse';

  @override
  String get quickBuddyTitle => 'SSI Buddy';
  @override
  String get quickBuddySubtitle => 'Mittaucher und Basen speichern und teilen';
  @override
  String get quickFitTitle => 'FIT-Datei importieren';
  @override
  String get quickFitSubtitle =>
      'Falls der Garmin-Login gerade nicht funktioniert';
  @override
  String get quickSettingsTitle => 'Einstellungen';
  @override
  String get quickSettingsSubtitle => 'Design und Sprache';
  @override
  String get quickInfoTitle => 'Info';
  @override
  String get quickInfoSubtitle => 'Version, Rechtliches und Quelltext';

  @override
  String get addGarminAccount => 'Garmin-Account hinzufügen';
  @override
  String get signIn => 'Einloggen';
  @override
  String get confirm => 'Bestätigen';
  @override
  String get nameOptionalHint =>
      'Optional – sonst wird die E-Mail-Adresse angezeigt';
  @override
  String get garminEmail => 'Garmin E-Mail';
  @override
  String get garminPassword => 'Garmin Passwort';
  @override
  String mfaRequested(String method) =>
      'Garmin hat einen Bestätigungscode angefordert ($method).';
  @override
  String get code => 'Code';

  @override
  String get allDives => 'Alle Tauchgänge';
  @override
  String divesLoadedCount(int count) =>
      count == 1 ? '1 Tauchgang geladen' : '$count Tauchgänge geladen';
  @override
  String get loadMoreFailed =>
      'Weitere Tauchgänge konnten nicht geladen werden.';
  @override
  String get loadOlderDives => 'Ältere Tauchgänge laden';
  @override
  String get noOlderDives => 'Keine älteren Tauchgänge mehr bei Garmin.';
  @override
  String get exportSeveral => 'Mehrere exportieren';

  @override
  String get filterDives => 'Tauchgänge filtern';
  @override
  String get filterAll => 'Alle';
  @override
  String get filterOpen => 'Noch offen';
  @override
  String get filterScuba => 'Scuba';

  @override
  String get filterRec => 'Rec';
  @override
  String get filterTech => 'Tech';
  @override
  String get noDivesForFilter =>
      'Keine Tauchgänge, auf die dieser Filter passt.';
  @override
  String get apiLog => 'API-Protokoll';
  @override
  String get divesLoadFailed => 'Tauchgänge konnten nicht geladen werden.';
  @override
  String get importFitInstead => 'Stattdessen FIT-Datei importieren';
  @override
  String get noDivesFoundPeriod => 'Keine Tauchgänge gefunden.';
  @override
  String get importedDives => 'Importierte Tauchgänge';
  @override
  String get noDivesInFile => 'Keine Tauchgänge in der Datei gefunden.';
  @override
  String get maxDepthLabel => 'MAX. TIEFE';
  @override
  String descentCount(int count) => '$count× abgetaucht';
  @override
  String diveOfDayAndType(int number, String type) => '$number. TG · $type';

  @override
  String diveOfDayTitle(int number) => '$number. Tauchgang';
  @override
  String diveNumberTitle(int number) => 'Tauchgang #$number';

  @override
  String get values => 'Werte';
  @override
  String get duration => 'Dauer';
  @override
  String get avgDepth => 'Ø Tiefe';
  @override
  String get waterTemperature => 'Wassertemp.';
  @override
  String get water => 'Wasser';
  @override
  String get deco => 'Deko';
  @override
  String get descents => 'Abtauchvorgänge';
  @override
  String get diveOfDayTitleShort => 'Tauchgang';
  @override
  String get diveOfDay => 'des Tages';
  @override
  String get qrForSsi => 'QR-Code für SSI';
  @override
  String get position => 'Position';
  @override
  String get diveSite => 'Tauchplatz';
  @override
  String get assignDiveSite => 'Tauchplatz zuordnen';
  @override
  String get changeDiveSite => 'Tauchplatz ändern';
  @override
  String get noDiveSiteYet => 'Noch kein Tauchplatz zugeordnet';
  @override
  String get diveSiteNumber => 'SSI-Platznummer oder Link';
  @override
  String get diveSiteNumberHint =>
      'Nummer eintippen oder die Adresse der Platzseite einfügen – die '
      'Nummer wird daraus gelesen.';
  @override
  String get diveSiteName => 'Name des Platzes';
  @override
  String get siteAdoptedChange =>
      'Tauchplatz automatisch übernommen – Zuordnung ändern';

  @override
  String get osmAttribution => '© OpenStreetMap-Mitwirkende';

  @override
  String get centreOnDive => 'Auf den Tauchgang zentrieren';

  @override
  String moreSitesNearby(int count) => count == 1
      ? '1 weiterer Platz in der Nähe'
      : '$count weitere in der Nähe';
  @override
  String get searchDiveSite => 'Tauchplatz suchen';
  @override
  String get noSiteMatches => 'Kein passender Tauchplatz';
  @override
  String distance(int metres) => metres < 1000
      ? '$metres m'
      : '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  @override
  String get noPositionNoSite =>
      'Ohne Position lässt sich dieser Tauchgang keinem Platz automatisch '
      'zuordnen – von Hand geht es trotzdem.';
  @override
  String get noSiteNearby =>
      'Kein bekannter Tauchplatz in der Nähe. Den Tauchgang einmal in der '
      'SSI-App einem Platz zuordnen und danach abgleichen – oder die Nummer '
      'hier von Hand eintragen.';
  @override
  String get siteIdUnreadable =>
      'Darin steckt keine Nummer. Erwartet wird eine Platznummer oder eine '
      'Adresse, die auf eine endet.';

  @override
  String get ssiAccount => 'SSI-Konto';
  @override
  String get ssiAccountHint =>
      'Die Mitgliedsnummer kommt dabei direkt von SSI – kein Scannen, kein '
      'Abtippen. Dieselbe Anmeldung holt die Tauchplätze aus dem Logbuch.';
  @override
  String get signInWithSsi => 'Mit SSI anmelden';
  @override
  String get diveSites => 'Tauchplätze';
  @override
  String get ssiLogbook => 'SSI-Logbuch';
  @override
  String knownDiveSites(int count) =>
      count == 1 ? '1 Tauchplatz bekannt' : '$count Tauchplätze bekannt';
  @override
  String knownBuddies(int count) =>
      count == 1 ? '1 Buddy gespeichert' : '$count Buddys gespeichert';
  @override
  String lastSyncedAt(String timestamp) =>
      'Zuletzt abgeglichen: $timestamp Uhr';
  @override
  String ssiBuddiesImported(int added) =>
      added == 1 ? '1 neuer Buddy übernommen' : '$added neue Buddys übernommen';
  @override
  String get noSsiAccountConnected =>
      'Kein SSI-Konto verbunden. Die Anmeldung liegt beim jeweiligen Account – '
      'dort unter „SSI-Identität".';
  @override
  String get ssiSignIn => 'Anmelden';
  @override
  String get ssiSignOut => 'Abmelden';
  @override
  String get ssiEmail => 'E-Mail';
  @override
  String get ssiPassword => 'Passwort';
  @override
  String get ssiPasswordNotStored =>
      'Das Passwort wird nur für die Anmeldung benutzt und nicht gespeichert – '
      'auf dem Gerät bleibt nur der Sitzungs-Token, verschlüsselt.';
  @override
  String get ssiSyncSites => 'Tauchplätze abgleichen';
  @override
  String ssiConnectedAs(String email) => 'Verbunden als $email';
  @override
  String ssiSitesImported(int added, int total) => added == 1
      ? '1 neuer Tauchplatz übernommen (von $total im Logbuch)'
      : '$added neue Tauchplätze übernommen (von $total im Logbuch)';
  @override
  String ssiSitesUpToDate(int total) =>
      'Alles aktuell – $total Tauchplätze im Logbuch, keine neuen.';
  @override
  String get ssiSyncExplanation =>
      'Holt jeden Tauchplatz, an dem du laut SSI schon getaucht bist – mit '
      'Nummer, Name und Position – und die Buddys aus dem Logbuch. Bereits '
      'vorhandene Einträge bleiben, wie sie sind.';
  @override
  String get ssiUnofficialNote =>
      'Nutzt dieselbe inoffizielle Schnittstelle wie die SSI-App. Sollte sie '
      'sich ändern, bleibt die Eingabe von Hand.';

  @override
  String get selectDives => 'Tauchgänge auswählen';
  @override
  String get oneDiveAsQr => '1 Tauchgang als QR-Code';
  @override
  String divesAsQr(int count) => '$count Tauchgänge als QR-Codes';
  @override
  String dayWithDiveCount(String day, int count) => '$day · $count TG';
  @override
  String get noneOfDay => 'Keinen';
  @override
  String get wholeDiveDay => 'Ganzer Tauchtag';
  @override
  String get scanWithSsiApp => 'Mit SSI-App scannen';
  @override
  String get qrHintSingle =>
      'In der SSI-App einen Tauchgang hinzufügen und „QR-Code scannen" '
      'wählen.';
  @override
  String get transferredToSsi => 'In SSI übernommen';
  @override
  String get qrFullScreen => 'Groß anzeigen';

  @override
  String get qrHintBatch =>
      'In der SSI-App einen Tauchgang hinzufügen und „QR-Code scannen" '
      'wählen, danach hier weiter.';
  @override
  String get back => 'Zurück';
  @override
  String get next => 'Weiter';
  @override
  String get done => 'Fertig';
  @override
  String pageOf(int index, int total) => '$index von $total';
  @override
  String get noMaxDepthNoQr =>
      'Tauchgang hat keine maximale Tiefe - QR-Code nicht möglich.';
  @override
  String get noDurationNoQr =>
      'Tauchgang hat keine Dauer - QR-Code nicht möglich.';

  @override
  String get ssiBuddy => 'SSI Buddy';
  @override
  String get search => 'Suchen';
  @override
  String filteredCount(int shown, int total) => '$shown von $total';
  @override
  String get showMore => 'Mehr anzeigen';
  @override
  String syncFailedFor(String account, String message) =>
      'SSI-Abgleich für $account: $message';
  @override
  String get signInAgain => 'Erneut anmelden';
  @override
  String get fromAccounts => 'Aus den Accounts';
  @override
  String get stored => 'Gespeichert';
  @override
  String get alsoStored => 'Zusätzlich gespeichert';
  @override
  String get diveCentres => 'Tauchbasen';
  @override
  String get scanCode => 'Code scannen';
  @override
  String get garminAccountChip => 'GARMIN-ACCOUNT';
  @override
  String get noBuddiesYetTitle => 'Noch keine Buddies gespeichert';
  @override
  String get noBuddiesYetBody =>
      'Lass dir den QR-Code deines Buddys in der SSI-App unter „Dein '
      'QR-Code" zeigen und scanne ihn hier. Der Code einer Tauchbasis '
      'funktioniert genauso.';
  @override
  String get addBuddyByHand => 'Buddy von Hand eintragen';
  @override
  String get addCentreByHand => 'Tauchbasis von Hand eintragen';
  @override
  String get showAsQr => 'Als QR-Code zeigen';
  @override
  String get buddyQrHint =>
      'Mit der Kamera eines anderen Geräts scannen, um diesen Buddy dort zu '
      'speichern.';
  @override
  String get centreQrHint =>
      'Mit der Kamera eines anderen Geräts scannen, um diese Tauchbasis dort '
      'zu speichern.';
  @override
  String savedConfirmation(String name) => '$name gespeichert';
  @override
  String get newBuddy => 'Buddy anlegen';
  @override
  String get editBuddy => 'Buddy bearbeiten';
  @override
  String get ssiMemberNumber => 'SSI-Mitgliedsnummer';
  @override
  String get firstName => 'Vorname';
  @override
  String get lastName => 'Nachname';
  @override
  String get newCentre => 'Tauchbasis anlegen';
  @override
  String get editCentre => 'Tauchbasis bearbeiten';
  @override
  String get centreNumber => 'Basis-Nummer';
  @override
  String get centreName => 'Name der Basis';
  @override
  String centreNumberLine(String centerId) => 'Basis-Nr. $centerId';
  @override
  String professionalNumber(String leaderNumber) =>
      'SSI Professional Nr. $leaderNumber';

  @override
  String get accountNotFound => 'Account nicht gefunden.';
  @override
  String get noSsiNumberYet => 'Noch keine SSI-Nummer hinterlegt.';
  @override
  String get storeIt => 'Hinterlegen';
  @override
  String get scanSsiQr => 'SSI-QR-Code scannen';
  @override
  String get enterNumberByHand => 'Nummer von Hand eintragen';
  @override
  String get removeSsiNumber => 'SSI-Nummer entfernen';
  @override
  String get ssiNumberWhereToFind =>
      'Die Nummer steht in der SSI-App unter „Dein QR-Code". Sie wird nur '
      'auf diesem Gerät gespeichert.';
  @override
  String ssiNumberStored(String memberId) => 'SSI-Nummer $memberId gespeichert';

  @override
  String get torch => 'Licht';
  @override
  String get switchCamera => 'Kamera wechseln';
  @override
  String get scanHintMember =>
      'In der SSI-App „Dein QR-Code" öffnen und die Kamera darauf richten.';
  @override
  String get scanHintMemberOrCentre =>
      'Den QR-Code eines Buddys („Dein QR-Code" in der SSI-App) oder einer '
      'Tauchbasis in die Kamera halten.';
  @override
  String get cameraDenied =>
      'Kein Kamerazugriff. Bitte in den Systemeinstellungen für SSI Connect '
      'erlauben – oder die Mitgliedsnummer von Hand eintragen.';
  @override
  String get cameraFailed =>
      'Kamera konnte nicht gestartet werden. Die Mitgliedsnummer lässt sich '
      'auch von Hand eintragen.';

  @override
  String get settings => 'Einstellungen';
  @override
  String get appearance => 'Darstellung';
  @override
  String get qrStaysLightNote =>
      'Der QR-Code bleibt immer hell – ein dunkler Code lässt sich von '
      'manchen Kameras nicht zuverlässig scannen.';
  @override
  String get themeSystem => 'Wie das Gerät';
  @override
  String get themeSystemHint => 'Folgt der Systemeinstellung';
  @override
  String get themeLight => 'Hell';
  @override
  String get themeLightHint => 'Gut bei Sonnenlicht an Deck';
  @override
  String get themeDark => 'Dunkel';
  @override
  String get themeDarkHint => 'Schont die Augen am Abend';
  @override
  String get language => 'Sprache';
  @override
  String get languageSystem => 'Wie das Gerät';
  @override
  String get languageSystemHint =>
      'Deutsch, wenn das Gerät keine unterstützte Sprache nennt';

  @override
  String get whatTheAppDoes => 'Was die App tut';
  @override
  String get whatTheAppDoesBody =>
      'SSI Connect liest die Tauchgänge, die deine Garmin-Uhr ohnehin '
      'aufzeichnet, und macht daraus einen QR-Code, den die SSI-App einlesen '
      'kann. Der Code wird auf diesem Gerät angezeigt und von einem zweiten '
      'Gerät abgescannt.';
  @override
  String get yourData => 'Deine Daten';
  @override
  String get yourDataStorage =>
      'Zugangsdaten, SSI-Nummern, Buddies und die zuletzt geladenen '
      'Tauchgänge liegen verschlüsselt im Schlüsselspeicher dieses Geräts.';
  @override
  String get yourDataNoThirdParty =>
      'Verbindungen nach außen gehen dorthin, wo deine eigenen Daten liegen: '
      'zu Garmin und, wenn du dich anmeldest, zu SSI. Dazu kommt die Karte: '
      'sie lädt ihre Kacheln von OpenStreetMap, das dabei erfährt, wo dieser '
      'Tauchgang war. Das passiert nur, während du einen Tauchgang geöffnet '
      'hast, und ohne Angabe, wer du bist.';
  @override
  String get yourDataNoServer =>
      'Es gibt keinen Server und kein Konto bei uns. Die App entfernen '
      'löscht alles.';
  @override
  String get yourDataDeletable =>
      'Gespeicherte Tauchgänge lassen sich jederzeit pro Account löschen; '
      'sie verschwinden auch, wenn du den Account entfernst.';
  @override
  String get legal => 'Rechtliches';
  @override
  String get legalNoAffiliation =>
      'Diese App steht in keiner Verbindung zu Garmin Ltd. oder zu Scuba '
      'Schools International (SSI). Beide Namen und Logos gehören ihren '
      'jeweiligen Inhabern und werden hier nur zur Beschreibung verwendet.';
  @override
  String get legalUnofficialApi =>
      'Der Zugriff auf Garmin Connect nutzt eine nicht offiziell '
      'dokumentierte Schnittstelle. Sie kann jederzeit ohne Vorankündigung '
      'brechen.';
  @override
  String get legalNoWarranty =>
      'Die Nutzung erfolgt auf eigene Verantwortung, ohne Gewähr für '
      'Richtigkeit oder Vollständigkeit der übertragenen Werte. Prüfe jeden '
      'Tauchgang, bevor du ihn übernimmst.';
  @override
  String get legalNotADiveComputer =>
      'Die App ist kein Tauchcomputer, kein Ersatz für einen und kein Ersatz '
      'für eine Tauchausbildung. Sie zeigt nur Werte, die bereits '
      'aufgezeichnet wurden, und berechnet nichts.';
  @override
  String get sourceAndLicences => 'Quelltext & Lizenzen';
  @override
  String get openSourceLicences => 'Open-Source-Lizenzen';
  @override
  String get licencesSubtitle => 'Die Lizenzen der verwendeten Pakete';
  @override
  String get sourceCode => 'Quelltext';
  @override
  String get copyAddress => 'Adresse kopieren';
  @override
  String get addressCopied => 'Adresse kopiert';
  @override
  String version(String version) => 'Version $version';
  @override
  String tapsRemaining(int count) => 'Noch $count× tippen';
  @override
  String get diagnostics => 'Diagnose';
  @override
  String get apiLogSubtitle => 'Aufgezeichnete Garmin-Aufrufe ansehen';
  @override
  String get inspectSsiCode => 'SSI-Code analysieren';
  @override
  String get inspectSsiCodeSubtitle =>
      'Felder eines echten SSI-QR-Codes im Klartext';
  @override
  String get diagnosticsUnlocked => 'Diagnose-Werkzeuge sichtbar';

  @override
  String get logCopied => 'Log in die Zwischenablage kopiert';
  @override
  String get copyAll => 'Alles kopieren';
  @override
  String get clearLog => 'Log leeren';
  @override
  String get recordingActive => 'Aufzeichnung aktiv';
  @override
  String get recordingExplanation =>
      'Zeichnet Garmin-API-Aufrufe auf und zeigt Rohdaten bei Fehlern. '
      'Passwörter und Tokens werden dabei unkenntlich gemacht.';
  @override
  String get noCallsRecorded => 'Noch keine Aufrufe aufgezeichnet.';
  @override
  String get payloadCopied => 'Payload in die Zwischenablage kopiert';
  @override
  String get copyPayload => 'Payload kopieren';
  @override
  String get inspectExplanation =>
      'Zeigt an, welche Felder ein echter SSI-Code enthält. Damit lassen '
      'sich Felder ermitteln, die SSI Connect noch nicht kennt – etwa die '
      'Buddy-Angabe: in der SSI-App einen Tauchgang mit Buddy exportieren '
      'und den QR-Code hier scannen.';
  @override
  String get scanQrCode => 'QR-Code scannen';
  @override
  String get scanAnother => 'Weiteren scannen';
  @override
  String get fields => 'Felder';
  @override
  String get rawData => 'Rohdaten';
  @override
  String get type => 'Typ';
  @override
  String get noKeyValueFields => 'Keine key:value-Felder enthalten.';
  @override
  String get emptyValue => '(leer)';
  @override
  String get inspectHint =>
      'Beliebigen SSI-QR-Code scannen – z. B. den Export eines Tauchgangs, '
      'in dem der gesuchte Wert schon eingetragen ist.';

  @override
  String get noInternet => 'Keine Internetverbindung';
  @override
  String get storedDives => 'Gespeicherte Tauchgänge';
  @override
  String get noCurrentData => 'Es werden keine aktuellen Daten geladen.';
  @override
  String asOf(String timestamp) => 'Stand: $timestamp Uhr';
  @override
  String get openApiLog => 'API-Protokoll öffnen';

  @override
  String filePickFailed(String error) => 'Dateiauswahl fehlgeschlagen: $error';
  @override
  String fileReadFailed(String error) =>
      'Datei konnte nicht gelesen werden: $error';

  @override
  String get diveTypeApnea => 'Apnoe';
  @override
  String get diveTypeSingleGas => 'Single Gas';
  @override
  String get diveTypeMultiGas => 'Multi Gas';
  @override
  String get diveTypeRebreather => 'Rebreather (CCR)';
  @override
  String get diveTypeScuba => 'Gerätetauchgang';
  @override
  String diveTypeTitle(String type) => '$type-Tauchgang';
  @override
  String get diveTypeScubaTitle => 'Gerätetauchgang';
  @override
  String get waterFresh => 'Süßwasser';
  @override
  String get waterSalt => 'Salzwasser';
  @override
  List<String> get colourNames => const [
    'Koralle',
    'Bernstein',
    'Grün',
    'Blau',
    'Violett',
    'Pink',
  ];
}
