import 'app_strings.dart';

/// English. Written as a diver would say it rather than word-for-word from
/// the German - "Tauchgang" is a dive, not a "dive trip", and SSI's own
/// English wording is used where it exists ("SSI Professional").
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  String get languageName => 'English';

  @override
  String get appName => 'SSI Connect';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get remove => 'Remove';
  @override
  String get edit => 'Edit';
  @override
  String get options => 'Options';
  @override
  String get retry => 'Try again';
  @override
  String get name => 'Name';
  @override
  String get number => 'Number';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';

  @override
  String atTime(String time) => time;

  @override
  List<String> get weekdaysShort => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  String get accountsSection => 'Accounts';
  @override
  String get moreSection => 'More';
  @override
  String get addAccount => 'Account';
  @override
  String get recentDives => 'Recent dives';
  @override
  String get showAll => 'Show all';
  @override
  String get divesLoading => 'Loading dives …';
  @override
  String get divesLoadFailedPullToRetry =>
      'Dives could not be loaded. Pull down to try again.';
  @override
  String get noDivesLoadedYet => 'No dives loaded yet.';
  @override
  String get oneAccountFailed => 'One account could not be loaded.';
  @override
  String accountsFailed(int count) => '$count accounts could not be loaded.';
  @override
  String get noAccountYetTitle => 'No Garmin account connected yet';
  @override
  String get noAccountYetBody =>
      'Connect an account to load dives – or import a FIT file below.';
  @override
  String get divesUnreachable => 'Dives unreachable';
  @override
  String get noDivesFound => 'No dives found';
  @override
  String lastDive(String date, String depth) => 'Last: $date · $depth m';
  @override
  String ssiNumber(String memberId) => 'SSI no. $memberId';
  @override
  String get storeSsiNumber => 'Add SSI number';

  @override
  String get renameAccount => 'Rename';
  @override
  String get chooseColour => 'Choose colour';
  @override
  String get ssiIdentity => 'SSI identity';
  @override
  String get deleteStoredDives => 'Delete stored dives';
  @override
  String get removeAccount => 'Remove account';
  @override
  String get storedDivesDeleted => 'Stored dives deleted';
  @override
  String get removeAccountQuestion => 'Remove account?';
  @override
  String removeAccountBody(String name) =>
      '$name will be removed from this device along with the stored dives. '
      'Getting back in needs a fresh login.';
  @override
  String get colour => 'Colour';
  @override
  String get colourExplanation =>
      "Marks this person's dives along the left edge.";
  @override
  String get noColour => 'No colour';
  @override
  String get displayedName => 'Display name';
  @override
  String get leaveEmptyForEmail => 'Leave empty to show the email address';

  @override
  String get quickBuddyTitle => 'SSI Buddy';
  @override
  String get quickBuddySubtitle => 'Store and share buddies and dive centres';
  @override
  String get quickFitTitle => 'Import FIT file';
  @override
  String get quickFitSubtitle => 'In case the Garmin login is not working';
  @override
  String get quickSettingsTitle => 'Settings';
  @override
  String get quickSettingsSubtitle => 'Appearance and language';
  @override
  String get quickInfoTitle => 'Info';
  @override
  String get quickInfoSubtitle => 'Version, legal notes and source code';

  @override
  String get addGarminAccount => 'Add Garmin account';
  @override
  String get signIn => 'Sign in';
  @override
  String get confirm => 'Confirm';
  @override
  String get nameOptionalHint =>
      'Optional – the email address is shown otherwise';
  @override
  String get garminEmail => 'Garmin email';
  @override
  String get garminPassword => 'Garmin password';
  @override
  String mfaRequested(String method) =>
      'Garmin asked for a verification code ($method).';
  @override
  String get code => 'Code';

  @override
  String get allDives => 'All dives';
  @override
  String divesLoadedCount(int count) =>
      count == 1 ? '1 dive loaded' : '$count dives loaded';
  @override
  String get loadMoreFailed => 'Older dives could not be loaded.';
  @override
  String get loadOlderDives => 'Load older dives';
  @override
  String get noOlderDives => 'No older dives left at Garmin.';
  @override
  String get exportSeveral => 'Export several';

  @override
  String get filterDives => 'Filter dives';
  @override
  String get filterAll => 'All';
  @override
  String get filterOpen => 'Still to do';
  @override
  String get filterScuba => 'Scuba';

  @override
  String get filterRec => 'Rec';
  @override
  String get filterTech => 'Tech';
  @override
  String get noDivesForFilter => 'No dives match this filter.';
  @override
  String get apiLog => 'API log';
  @override
  String get divesLoadFailed => 'Dives could not be loaded.';
  @override
  String get importFitInstead => 'Import a FIT file instead';
  @override
  String get noDivesFoundPeriod => 'No dives found.';
  @override
  String get importedDives => 'Imported dives';
  @override
  String get noDivesInFile => 'No dives found in the file.';
  @override
  String get maxDepthLabel => 'MAX. DEPTH';
  @override
  String descentCount(int count) => '$count descents';
  @override
  String diveOfDayAndType(int number, String type) => 'Dive $number · $type';

  @override
  String diveOfDayTitle(int number) => 'Dive $number of the day';
  @override
  String get values => 'Values';
  @override
  String get duration => 'Duration';
  @override
  String get avgDepth => 'Avg. depth';
  @override
  String get waterTemperature => 'Water temp.';
  @override
  String get water => 'Water';
  @override
  String get deco => 'Deco';
  @override
  String get descents => 'Descents';
  @override
  String get diveOfDayTitleShort => 'Dive';
  @override
  String get diveOfDay => 'of the day';
  @override
  String get qrForSsi => 'QR code for SSI';
  @override
  String get position => 'Position';
  @override
  String get diveSite => 'Dive site';
  @override
  String get assignDiveSite => 'Assign a dive site';
  @override
  String get changeDiveSite => 'Change dive site';
  @override
  String get noDiveSiteYet => 'No dive site assigned yet';
  @override
  String get diveSiteNumber => 'SSI site number or link';
  @override
  String get diveSiteNumberHint =>
      'Type the number, or paste the address of the site page – the number '
      'is read out of it.';
  @override
  String get diveSiteName => 'Name of the site';
  @override
  String get siteAdoptedChange => 'Dive site adopted automatically - change';

  @override
  String get osmAttribution => '© OpenStreetMap contributors';

  @override
  String get centreOnDive => 'Centre on the dive';

  @override
  String moreSitesNearby(int count) =>
      count == 1 ? '1 more site nearby' : '$count more nearby';
  @override
  String get searchDiveSite => 'Search dive site';
  @override
  String get noSiteMatches => 'No matching dive site';
  @override
  String distance(int metres) =>
      metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';
  @override
  String get noPositionNoSite =>
      'Without a position this dive cannot be matched to a site '
      'automatically – by hand still works.';
  @override
  String get noSiteNearby =>
      'No known dive site nearby. Assign the dive to a site in the SSI app '
      'once and sync afterwards – or enter the number here by hand.';
  @override
  String get siteIdUnreadable =>
      'No number in there. A site number is expected, or an address ending '
      'in one.';

  @override
  String get ssiAccount => 'SSI account';
  @override
  String get ssiAccountHint =>
      'The member number comes straight from SSI – nothing to scan, nothing '
      'to type. The same login fetches the dive sites from the logbook.';
  @override
  String get signInWithSsi => 'Sign in with SSI';
  @override
  String get diveSites => 'Dive sites';
  @override
  String get ssiLogbook => 'SSI logbook';
  @override
  String knownDiveSites(int count) =>
      count == 1 ? '1 dive site known' : '$count dive sites known';
  @override
  String knownBuddies(int count) =>
      count == 1 ? '1 buddy stored' : '$count buddies stored';
  @override
  String lastSyncedAt(String timestamp) => 'Last synced: $timestamp';
  @override
  String ssiBuddiesImported(int added) =>
      added == 1 ? '1 new buddy added' : '$added new buddies added';
  @override
  String get noSsiAccountConnected =>
      'No SSI account connected. The login sits with each account – under '
      '"SSI identity" there.';
  @override
  String get ssiSignIn => 'Sign in';
  @override
  String get ssiSignOut => 'Sign out';
  @override
  String get ssiEmail => 'Email';
  @override
  String get ssiPassword => 'Password';
  @override
  String get ssiPasswordNotStored =>
      'The password is only used to sign in and is not stored – all that stays '
      'on the device is the session token, encrypted.';
  @override
  String get ssiSyncSites => 'Sync dive sites';
  @override
  String ssiConnectedAs(String email) => 'Connected as $email';
  @override
  String ssiSitesImported(int added, int total) => added == 1
      ? '1 new dive site added (of $total in the logbook)'
      : '$added new dive sites added (of $total in the logbook)';
  @override
  String ssiSitesUpToDate(int total) =>
      'Up to date – $total dive sites in the logbook, none new.';
  @override
  String get ssiSyncExplanation =>
      'Fetches every dive site SSI has you logged at – number, name and '
      'position – and the buddies from the logbook. Entries you already have '
      'are left as they are.';
  @override
  String get ssiUnofficialNote =>
      'Uses the same unofficial interface as the SSI app. Should it change, '
      'entering sites by hand remains.';

  @override
  String get selectDives => 'Select dives';
  @override
  String get oneDiveAsQr => '1 dive as a QR code';
  @override
  String divesAsQr(int count) => '$count dives as QR codes';
  @override
  String dayWithDiveCount(String day, int count) =>
      count == 1 ? '$day · 1 dive' : '$day · $count dives';
  @override
  String get noneOfDay => 'None';
  @override
  String get wholeDiveDay => 'Whole dive day';
  @override
  String get scanWithSsiApp => 'Scan with the SSI app';
  @override
  String get qrHintSingle =>
      'In the SSI app, add a dive and choose "Scan QR code".';
  @override
  String get transferredToSsi => 'Carried over into SSI';
  @override
  String get qrFullScreen => 'Show large';

  @override
  String get qrHintBatch =>
      'In the SSI app, add a dive and choose "Scan QR code", then continue '
      'here.';
  @override
  String get back => 'Back';
  @override
  String get next => 'Next';
  @override
  String get done => 'Done';
  @override
  String pageOf(int index, int total) => '$index of $total';
  @override
  String get noMaxDepthNoQr => 'Dive has no maximum depth - no QR code.';
  @override
  String get noDurationNoQr => 'Dive has no duration - no QR code.';

  @override
  String get ssiBuddy => 'SSI Buddy';
  @override
  String get fromAccounts => 'From the accounts';
  @override
  String get stored => 'Stored';
  @override
  String get alsoStored => 'Also stored';
  @override
  String get diveCentres => 'Dive centres';
  @override
  String get scanCode => 'Scan code';
  @override
  String get garminAccountChip => 'GARMIN ACCOUNT';
  @override
  String get noBuddiesYetTitle => 'No buddies stored yet';
  @override
  String get noBuddiesYetBody =>
      'Have your buddy open "Your QR code" in the SSI app and scan it here. '
      'A dive centre code works the same way.';
  @override
  String get addBuddyByHand => 'Add a buddy by hand';
  @override
  String get addCentreByHand => 'Add a dive centre by hand';
  @override
  String get showAsQr => 'Show as QR code';
  @override
  String get buddyQrHint =>
      "Scan with another device's camera to store this buddy there.";
  @override
  String get centreQrHint =>
      "Scan with another device's camera to store this dive centre there.";
  @override
  String savedConfirmation(String name) => '$name saved';
  @override
  String get newBuddy => 'New buddy';
  @override
  String get editBuddy => 'Edit buddy';
  @override
  String get ssiMemberNumber => 'SSI member number';
  @override
  String get firstName => 'First name';
  @override
  String get lastName => 'Last name';
  @override
  String get newCentre => 'New dive centre';
  @override
  String get editCentre => 'Edit dive centre';
  @override
  String get centreNumber => 'Centre number';
  @override
  String get centreName => 'Centre name';
  @override
  String centreNumberLine(String centerId) => 'Centre no. $centerId';
  @override
  String professionalNumber(String leaderNumber) =>
      'SSI Professional no. $leaderNumber';

  @override
  String get accountNotFound => 'Account not found.';
  @override
  String get noSsiNumberYet => 'No SSI number stored yet.';
  @override
  String get storeIt => 'Add it';
  @override
  String get scanSsiQr => 'Scan SSI QR code';
  @override
  String get enterNumberByHand => 'Enter the number by hand';
  @override
  String get removeSsiNumber => 'Remove SSI number';
  @override
  String get ssiNumberWhereToFind =>
      'The number is in the SSI app under "Your QR code". It is stored on '
      'this device only.';
  @override
  String ssiNumberStored(String memberId) => 'SSI number $memberId stored';

  @override
  String get torch => 'Light';
  @override
  String get switchCamera => 'Switch camera';
  @override
  String get scanHintMember =>
      'Open "Your QR code" in the SSI app and point the camera at it.';
  @override
  String get scanHintMemberOrCentre =>
      'Hold a buddy\'s QR code ("Your QR code" in the SSI app) or a dive '
      "centre's code in front of the camera.";
  @override
  String get cameraDenied =>
      'No camera access. Allow it for SSI Connect in the system settings – '
      'or type the member number in by hand.';
  @override
  String get cameraFailed =>
      'The camera could not be started. The member number can also be typed '
      'in by hand.';

  @override
  String get settings => 'Settings';
  @override
  String get appearance => 'Appearance';
  @override
  String get qrStaysLightNote =>
      'The QR code always stays light – some cameras cannot read a dark one '
      'reliably.';
  @override
  String get themeSystem => 'Follow the device';
  @override
  String get themeSystemHint => 'Uses the system setting';
  @override
  String get themeLight => 'Light';
  @override
  String get themeLightHint => 'Good in sunlight on deck';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeDarkHint => 'Easier on the eyes at night';
  @override
  String get language => 'Language';
  @override
  String get languageSystem => 'Follow the device';
  @override
  String get languageSystemHint =>
      'German if the device asks for a language this app does not have';

  @override
  String get whatTheAppDoes => 'What the app does';
  @override
  String get whatTheAppDoesBody =>
      'SSI Connect reads the dives your Garmin watch records anyway and '
      'turns them into a QR code the SSI app can read. The code is shown on '
      'this device and scanned by a second one.';
  @override
  String get yourData => 'Your data';
  @override
  String get yourDataStorage =>
      'Credentials, SSI numbers, buddies and the most recently loaded dives '
      "are stored encrypted in this device's keystore.";
  @override
  String get yourDataNoThirdParty =>
      'Outbound connections go where your own data already is: to Garmin, and '
      'to SSI if you sign in. Plus the map: it loads its tiles from '
      'OpenStreetMap, which thereby learns where this dive was. That happens '
      'only while you have a dive open, and without saying who you are.';
  @override
  String get yourDataNoServer =>
      'There is no server and no account with us. Removing the app deletes '
      'everything.';
  @override
  String get yourDataDeletable =>
      'Stored dives can be deleted per account at any time; they also go '
      'when you remove the account.';
  @override
  String get legal => 'Legal';
  @override
  String get legalNoAffiliation =>
      'This app is not affiliated with Garmin Ltd. or with Scuba Schools '
      'International (SSI). Both names and logos belong to their respective '
      'owners and are used here for description only.';
  @override
  String get legalUnofficialApi =>
      'Access to Garmin Connect uses an interface that is not officially '
      'documented. It can break at any time without notice.';
  @override
  String get legalNoWarranty =>
      'Use is at your own risk, with no warranty as to the accuracy or '
      'completeness of the transferred values. Check every dive before you '
      'accept it.';
  @override
  String get legalNotADiveComputer =>
      'This app is not a dive computer, not a replacement for one and not a '
      'replacement for dive training. It only shows values that were already '
      'recorded, and calculates nothing.';
  @override
  String get sourceAndLicences => 'Source code & licences';
  @override
  String get openSourceLicences => 'Open source licences';
  @override
  String get licencesSubtitle => 'The licences of the packages used';
  @override
  String get sourceCode => 'Source code';
  @override
  String get copyAddress => 'Copy address';
  @override
  String get addressCopied => 'Address copied';
  @override
  String version(String version) => 'Version $version';
  @override
  String tapsRemaining(int count) => '$count more taps';
  @override
  String get diagnostics => 'Diagnostics';
  @override
  String get apiLogSubtitle => 'Look at the recorded Garmin calls';
  @override
  String get inspectSsiCode => 'Inspect SSI code';
  @override
  String get inspectSsiCodeSubtitle =>
      'The fields of a real SSI QR code, in plain text';
  @override
  String get diagnosticsUnlocked => 'Diagnostic tools visible';

  @override
  String get logCopied => 'Log copied to the clipboard';
  @override
  String get copyAll => 'Copy all';
  @override
  String get clearLog => 'Clear log';
  @override
  String get recordingActive => 'Recording on';
  @override
  String get recordingExplanation =>
      'Records Garmin API calls and shows raw data on failures. Passwords '
      'and tokens are masked.';
  @override
  String get noCallsRecorded => 'No calls recorded yet.';
  @override
  String get payloadCopied => 'Payload copied to the clipboard';
  @override
  String get copyPayload => 'Copy payload';
  @override
  String get inspectExplanation =>
      'Shows which fields a real SSI code contains. That is how to find '
      'fields SSI Connect does not know yet – the buddy entry, say: export a '
      'dive with a buddy from the SSI app and scan the QR code here.';
  @override
  String get scanQrCode => 'Scan QR code';
  @override
  String get scanAnother => 'Scan another';
  @override
  String get fields => 'Fields';
  @override
  String get rawData => 'Raw data';
  @override
  String get type => 'Type';
  @override
  String get noKeyValueFields => 'No key:value fields present.';
  @override
  String get emptyValue => '(empty)';
  @override
  String get inspectHint =>
      'Scan any SSI QR code – for instance the export of a dive that already '
      'carries the value you are looking for.';

  @override
  String get noInternet => 'No internet connection';
  @override
  String get storedDives => 'Stored dives';
  @override
  String get noCurrentData => 'No current data is being loaded.';
  @override
  String asOf(String timestamp) => 'As of $timestamp';
  @override
  String get openApiLog => 'Open the API log';

  @override
  String filePickFailed(String error) => 'Picking the file failed: $error';
  @override
  String fileReadFailed(String error) => 'The file could not be read: $error';

  @override
  String get diveTypeApnea => 'Freediving';
  @override
  String get diveTypeSingleGas => 'Single gas';
  @override
  String get diveTypeMultiGas => 'Multi gas';
  @override
  String get diveTypeRebreather => 'Rebreather (CCR)';
  @override
  String get diveTypeScuba => 'Scuba';
  @override
  String get waterFresh => 'Fresh water';
  @override
  String get waterSalt => 'Salt water';
  @override
  List<String> get colourNames => const [
    'Coral',
    'Amber',
    'Green',
    'Blue',
    'Violet',
    'Pink',
  ];
}
