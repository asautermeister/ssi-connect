import 'package:flutter/material.dart';

import 'app_strings_de.dart';
import 'app_strings_en.dart';

/// Every text the app shows, in one place per language.
///
/// A hand-written class rather than `gen_l10n` with ARB files: that would
/// add a code-generation step to every build and to CI, and this project is
/// worked on from a plain editor. An abstract class gives the same thing
/// that matters - the compiler refuses a missing or misspelt text, and a
/// new language cannot be half-finished, because an incomplete
/// implementation does not compile.
///
/// Texts that are the same in both languages (`SSI Connect`, `min`, `m`)
/// still live here, so there is exactly one place to look.
abstract class AppStrings {
  const AppStrings();

  static const supportedLocales = [Locale('de'), Locale('en')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// The texts for the closest supported language. Falls back to German,
  /// which is what the app was written in.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? const AppStringsDe();

  /// What this language is called in itself - never translated, because a
  /// language picker is read by someone who does not yet speak the language
  /// the app is currently in.
  String get languageName;

  // ---------------------------------------------------------------- shared

  String get appName;
  String get cancel;
  String get save;
  String get remove;
  String get edit;
  String get options;
  String get retry;
  String get name;
  String get number;
  String get yes;
  String get no;

  /// A clock time as a phrase: German appends "Uhr", English says
  /// nothing extra.
  String atTime(String time);

  /// Weekday abbreviations, Monday first.
  List<String> get weekdaysShort;

  // ------------------------------------------------------------ start screen

  String get accountsSection;
  String get moreSection;
  String get addAccount;
  String get recentDives;
  String get showAll;
  String get divesLoading;
  String get divesLoadFailedPullToRetry;
  String get noDivesLoadedYet;
  String get oneAccountFailed;
  String accountsFailed(int count);
  String get noAccountYetTitle;
  String get noAccountYetBody;
  String get divesUnreachable;
  String get noDivesFound;
  String lastDive(String date, String depth);
  String ssiNumber(String memberId);
  String get storeSsiNumber;

  // account menu
  String get renameAccount;
  String get chooseColour;
  String get ssiIdentity;
  String get deleteStoredDives;
  String get removeAccount;
  String get storedDivesDeleted;
  String get removeAccountQuestion;
  String removeAccountBody(String name);
  String get colour;
  String get colourExplanation;
  String get noColour;
  String get displayedName;
  String get leaveEmptyForEmail;

  // quick actions
  String get quickBuddyTitle;
  String get quickBuddySubtitle;
  String get quickFitTitle;
  String get quickFitSubtitle;
  String get quickSettingsTitle;
  String get quickSettingsSubtitle;
  String get quickInfoTitle;
  String get quickInfoSubtitle;

  // ----------------------------------------------------------- account login

  String get addGarminAccount;
  String get signIn;
  String get confirm;
  String get nameOptionalHint;
  String get garminEmail;
  String get garminPassword;
  String mfaRequested(String method);
  String get code;

  // ------------------------------------------------------------- dive lists

  String get allDives;
  String divesLoadedCount(int count);
  String get loadMoreFailed;
  String get loadOlderDives;
  String get noOlderDives;
  String get exportSeveral;
  String get filterDives;
  String get filterAll;
  String get filterOpen;
  String get filterScuba;
  String get filterRec;
  String get filterTech;
  String get noDivesForFilter;
  String get apiLog;
  String get divesLoadFailed;
  String get importFitInstead;
  String get noDivesFoundPeriod;
  String get importedDives;
  String get noDivesInFile;
  String get maxDepthLabel;
  String descentCount(int count);
  String diveOfDayAndType(int number, String type);

  // ------------------------------------------------------------ dive detail

  String diveOfDayTitle(int number);
  String get values;
  String get duration;
  String get avgDepth;
  String get waterTemperature;
  String get water;
  String get deco;
  String get descents;
  String get diveOfDayTitleShort;
  String get diveOfDay;
  String get qrForSsi;
  String get position;
  String get diveSite;
  String get assignDiveSite;
  String get changeDiveSite;
  String get noDiveSiteYet;
  String get diveSiteNumber;
  String get diveSiteNumberHint;
  String get diveSiteName;
  String get siteAdoptedChange;
  String get osmAttribution;
  String get centreOnDive;
  String moreSitesNearby(int count);
  String get searchDiveSite;
  String get noSiteMatches;

  /// A distance in metres, rendered the way the language writes it -
  /// metres up close, kilometres once that stops being readable.
  String distance(int metres);
  String get noPositionNoSite;
  String get noSiteNearby;
  String get siteIdUnreadable;

  // ----------------------------------------------------------- SSI account

  String get ssiAccount;
  String get ssiAccountHint;
  String get signInWithSsi;
  String get diveSites;
  String get ssiLogbook;
  String knownDiveSites(int count);
  String knownBuddies(int count);
  String lastSyncedAt(String timestamp);
  String ssiBuddiesImported(int added);
  String get noSsiAccountConnected;
  String get ssiSignIn;
  String get ssiSignOut;
  String get ssiEmail;
  String get ssiPassword;
  String get ssiPasswordNotStored;
  String get ssiSyncSites;
  String ssiConnectedAs(String email);
  String ssiSitesImported(int added, int total);
  String ssiSitesUpToDate(int total);
  String get ssiSyncExplanation;
  String get ssiUnofficialNote;

  // ------------------------------------------------------- batch and export

  String get selectDives;
  String get oneDiveAsQr;
  String divesAsQr(int count);
  String dayWithDiveCount(String day, int count);
  String get noneOfDay;
  String get wholeDiveDay;
  String get scanWithSsiApp;
  String get qrHintSingle;
  String get qrFullScreen;
  String get qrHintBatch;
  String get transferredToSsi;
  String get back;
  String get next;
  String get done;
  String pageOf(int index, int total);
  String get noMaxDepthNoQr;
  String get noDurationNoQr;

  // ------------------------------------------------------------- buddies

  String get ssiBuddy;
  String get fromAccounts;
  String get stored;
  String get alsoStored;
  String get diveCentres;
  String get scanCode;
  String get garminAccountChip;
  String get noBuddiesYetTitle;
  String get noBuddiesYetBody;
  String get addBuddyByHand;
  String get addCentreByHand;
  String get showAsQr;
  String get buddyQrHint;
  String get centreQrHint;
  String savedConfirmation(String name);
  String get newBuddy;
  String get editBuddy;
  String get ssiMemberNumber;
  String get firstName;
  String get lastName;
  String get newCentre;
  String get editCentre;
  String get centreNumber;
  String get centreName;
  String centreNumberLine(String centerId);
  String professionalNumber(String leaderNumber);

  // ------------------------------------------------------------- identity

  String get accountNotFound;
  String get noSsiNumberYet;
  String get storeIt;
  String get scanSsiQr;
  String get enterNumberByHand;
  String get removeSsiNumber;
  String get ssiNumberWhereToFind;
  String ssiNumberStored(String memberId);

  // --------------------------------------------------------------- scanner

  String get torch;
  String get switchCamera;
  String get scanHintMember;
  String get scanHintMemberOrCentre;
  String get cameraDenied;
  String get cameraFailed;

  // -------------------------------------------------------------- settings

  String get settings;
  String get appearance;
  String get qrStaysLightNote;
  String get themeSystem;
  String get themeSystemHint;
  String get themeLight;
  String get themeLightHint;
  String get themeDark;
  String get themeDarkHint;
  String get language;
  String get languageSystem;
  String get languageSystemHint;

  // ------------------------------------------------------------------ info

  String get whatTheAppDoes;
  String get whatTheAppDoesBody;
  String get yourData;
  String get yourDataStorage;
  String get yourDataNoThirdParty;
  String get yourDataNoServer;
  String get yourDataDeletable;
  String get legal;
  String get legalNoAffiliation;
  String get legalUnofficialApi;
  String get legalNoWarranty;
  String get legalNotADiveComputer;
  String get sourceAndLicences;
  String get openSourceLicences;
  String get licencesSubtitle;
  String get sourceCode;
  String get copyAddress;
  String get addressCopied;
  String version(String version);
  String tapsRemaining(int count);
  String get diagnostics;
  String get apiLogSubtitle;
  String get inspectSsiCode;
  String get inspectSsiCodeSubtitle;
  String get diagnosticsUnlocked;

  // ------------------------------------------------------------ diagnostics

  String get logCopied;
  String get copyAll;
  String get clearLog;
  String get recordingActive;
  String get recordingExplanation;
  String get noCallsRecorded;
  String get payloadCopied;
  String get copyPayload;
  String get inspectExplanation;
  String get scanQrCode;
  String get scanAnother;
  String get fields;
  String get rawData;
  String get type;
  String get noKeyValueFields;
  String get emptyValue;
  String get inspectHint;

  // --------------------------------------------------------------- offline

  String get noInternet;
  String get storedDives;
  String get noCurrentData;
  String asOf(String timestamp);
  String get openApiLog;

  // ------------------------------------------------------------- FIT import
  String filePickFailed(String error);
  String fileReadFailed(String error);

  // ---------------------------------------------------------------- domain

  String get diveTypeApnea;
  String get diveTypeSingleGas;
  String get diveTypeMultiGas;
  String get diveTypeRebreather;
  String get diveTypeScuba;
  String get waterFresh;
  String get waterSalt;
  List<String> get colourNames;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  /// Anything that is not English gets German - which is also what an
  /// unknown device language resolves to, since it is first in
  /// [AppStrings.supportedLocales].
  @override
  Future<AppStrings> load(Locale locale) async =>
      locale.languageCode == 'en' ? const AppStringsEn() : const AppStringsDe();

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
