import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/exported_dives_controller.dart';
import 'dive_sites_controller.dart';
import 'ssi_api_client.dart';
import 'ssi_api_exceptions.dart';
import 'ssi_buddies_controller.dart';
import 'ssi_buddy_code.dart';

/// Signing in to SSI, and pulling dive sites out of the connected
/// logbooks.
///
/// Holds no account state of its own: an SSI login belongs to the person it
/// is for, so it lives on their [GarminAccount] alongside their Garmin one.
/// What this controller owns is only the progress of the current call.
///
/// The sites, by contrast, are device-wide. A dive site is a place, and a
/// family shares those - keeping a separate list per account would store
/// the same place several times and, worse, would hide a site from the
/// person who did not import it.
class SsiSyncController extends ChangeNotifier {
  SsiSyncController({SsiApiClient? client, FlutterSecureStorage? storage})
    : _client = client ?? SsiApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final SsiApiClient _client;
  final FlutterSecureStorage _storage;

  /// Where the SSI login lived while it was a single device-wide account.
  /// Removed on startup so a token from that version does not sit in the
  /// keystore unused and unreachable.
  static const _legacyAccountKey = 'ssi_connect.ssi_account';

  /// Where a single device-wide timestamp lived, before the sync learned to
  /// run for one account at a time. Read once on startup so an existing
  /// install does not re-sync everything the first time, then dropped.
  static const _legacyLastSyncKey = 'ssi_connect.ssi.last_sync';

  static const _lastSyncKey = 'ssi_connect.ssi.last_sync_by_account';

  bool _busy = false;
  bool get isBusy => _busy;

  /// The account currently being worked on, so a row can show its own
  /// spinner instead of the whole screen freezing.
  String? _busyAccountId;
  String? get busyAccountId => _busyAccountId;

  String? _error;
  String? get error => _error;

  /// How the last sync went: how many sites the logbooks hold in total, and
  /// how many of them were new to this device.
  int? _lastSiteCount;
  int? get lastSiteCount => _lastSiteCount;

  int? _lastAddedCount;
  int? get lastAddedCount => _lastAddedCount;

  /// The same two numbers for the buddies that came with the logbooks.
  int? _lastBuddyCount;
  int? get lastBuddyCount => _lastBuddyCount;

  int? _lastBuddyAddedCount;
  int? get lastBuddyAddedCount => _lastBuddyAddedCount;

  /// When each account's logbook was last read.
  ///
  /// Outlives the app run, unlike the counts beside it: those describe the
  /// sync you just watched happen, this answers "is what I am looking at
  /// still current?" days later - and, since the sync runs per account now,
  /// it is what decides whether a given account is due at all.
  final _lastSyncAt = <String, DateTime>{};

  DateTime? lastSyncAtFor(String accountId) => _lastSyncAt[accountId];

  /// The oldest of them, which is the honest answer to "how current is what
  /// I see?" when several logbooks feed one screen. Null until the first
  /// sync of the first account.
  DateTime? get lastSyncAt {
    DateTime? oldest;
    for (final at in _lastSyncAt.values) {
      if (oldest == null || at.isBefore(oldest)) oldest = at;
    }
    return oldest;
  }

  /// When each account's logbook was last *asked* for, successfully or not.
  ///
  /// Separate from [_lastSyncAt], which records success and is what gets
  /// shown. This one only holds the floor open: a screen asks on every
  /// build, so an account whose token is refused would otherwise be asked
  /// again on every frame.
  final _lastAttemptAt = <String, DateTime>{};

  /// What went wrong per account on the last attempt, by account id. Empty
  /// while everything is in order, which is most of the time.
  final _failures = <String, String>{};
  Map<String, String> get failures => Map.unmodifiable(_failures);

  Future<void> initialize() async {
    await _storage.delete(key: _legacyAccountKey);
    final stored = await _storage.read(key: _lastSyncKey);
    if (stored != null) {
      for (final entry in stored.split('\n')) {
        final at = entry.indexOf('=');
        if (at <= 0) continue;
        final parsed = DateTime.tryParse(entry.substring(at + 1));
        if (parsed != null) _lastSyncAt[entry.substring(0, at)] = parsed;
      }
    }
    _legacyAt ??= DateTime.tryParse(
      await _storage.read(key: _legacyLastSyncKey) ?? '',
    );
    await _storage.delete(key: _legacyLastSyncKey);
    notifyListeners();
  }

  /// The device-wide timestamp from before this was per account. Stands in
  /// for an account that has no timestamp of its own yet, so upgrading does
  /// not look like "never synced" and re-read every logbook at once.
  DateTime? _legacyAt;

  Future<void> _rememberSync(String accountId) async {
    _lastSyncAt[accountId] = DateTime.now();
    await _storage.write(
      key: _lastSyncKey,
      value: [
        for (final entry in _lastSyncAt.entries)
          '${entry.key}=${entry.value.toIso8601String()}',
      ].join('\n'),
    );
  }

  /// Signs in and stores the session on [accountId].
  ///
  /// Returns whether it worked; on failure [error] says why.
  Future<bool> signIn({
    required String accountId,
    required String email,
    required String password,
    required AccountsController accounts,
  }) async {
    _begin(accountId);
    try {
      final session = await _client.authenticate(
        email: email,
        password: password,
      );
      await accounts.setSsiSession(accountId, session);
      return true;
    } on SsiApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _end();
    }
  }

  /// Pulls the logbooks of the connected accounts in [scope]: dive sites
  /// into [sites], the buddies into [buddies], the logged dives into
  /// [exported] for the transferred tick.
  ///
  /// Skips any account whose logbook was read less than [notWithin] ago, so
  /// this is safe to call from a screen opening or from a pull-to-refresh
  /// without asking first whether it is worth it.
  ///
  /// One failing account does not stop the others: a stale token on one
  /// logbook is no reason to withhold the rest. What failed is kept per
  /// account in [failures].
  Future<bool> syncAccounts({
    required List<GarminAccount> scope,
    required AccountsController accounts,
    required DiveSitesController sites,
    required SsiBuddiesController buddies,
    required ExportedDivesController exported,
    Duration notWithin = Duration.zero,
  }) async {
    final now = DateTime.now();
    final due = [
      for (final account in scope)
        if (account.hasSsiLogin && _isDue(account.id, now, notWithin)) account,
    ];
    if (due.isEmpty) return false;

    _begin(null);
    var siteTotal = 0;
    var siteAdded = 0;
    var buddyTotal = 0;
    final harvested = <SsiBuddyCode>[];
    // Named for the message a person reads, keyed by id for the screen that
    // will one day put the failure on the account it belongs to.
    final named = <String>[];
    try {
      for (final account in due) {
        _lastAttemptAt[account.id] = DateTime.now();
        try {
          final logbook = await _client.loadLogbook(account.ssiSession!);
          siteTotal += logbook.sites.length;
          siteAdded += await sites.addAllNew(logbook.sites);
          buddyTotal += logbook.buddies.length;
          harvested.addAll(logbook.buddies);
          // Kept per account: a logbook may only ever be matched against
          // its own person's dives.
          await exported.setLogbook(account.id, logbook.dives);
          _failures.remove(account.id);
          await _rememberSync(account.id);
        } on SsiApiException catch (e) {
          named.add('${account.displayName}: ${e.message}');
          _failures[account.id] = e.message;
          // A rejected token would fail the same way every time, and the
          // message would never change. Drop it and let them sign in again.
          if (e.type == SsiApiErrorType.invalidCredentials) {
            await accounts.clearSsiSession(account.id);
            // Without a login there is nothing keeping it current, and a
            // stale logbook would go on ticking dives.
            await exported.forgetLogbook(account.id);
          }
        }
      }

      _lastSiteCount = siteTotal;
      _lastAddedCount = siteAdded;
      _lastBuddyCount = buddyTotal;
      _lastBuddyAddedCount = await _absorbBuddies(harvested, accounts, buddies);

      if (named.isNotEmpty) _error = named.join('\n');
      return named.isEmpty;
    } finally {
      _end();
    }
  }

  /// Whether this account's logbook is old enough to be worth reading.
  ///
  /// An account with no timestamp of its own falls back to the device-wide
  /// one from before this was per account, so upgrading does not read every
  /// logbook at once on the first screen that opens.
  bool _isDue(String accountId, DateTime now, Duration notWithin) {
    final attempted = _lastAttemptAt[accountId];
    if (attempted != null && now.difference(attempted) < notWithin) {
      return false;
    }
    final last = _lastSyncAt[accountId] ?? _legacyAt;
    return last == null || now.difference(last) >= notWithin;
  }

  /// Forgets what is known about an account, so it is due again. For the
  /// moment a fresh login is stored on it.
  void forgetSyncState(String accountId) {
    _lastSyncAt.remove(accountId);
    _lastAttemptAt.remove(accountId);
    _failures.remove(accountId);
  }

  /// Files the harvested buddies, keeping the people who already have an
  /// account here out of the buddy list.
  ///
  /// Two family members on each other's buddy lists would otherwise show up
  /// twice: once under their own account, once as a buddy. The buddy entry
  /// is still worth having though - it is the only place SSI writes their
  /// name, which a login does not report. So it goes to the account instead
  /// of into the list.
  Future<int> _absorbBuddies(
    List<SsiBuddyCode> harvested,
    AccountsController accounts,
    SsiBuddiesController buddies,
  ) async {
    final ownNumbers = {
      for (final account in accounts.accounts) ?account.ssiMemberId,
    };

    final strangers = <SsiBuddyCode>[];
    for (final buddy in harvested) {
      if (ownNumbers.contains(buddy.memberId)) {
        await accounts.completeSsiName(
          buddy.memberId,
          firstName: buddy.firstName,
          lastName: buddy.lastName,
        );
      } else {
        strangers.add(buddy);
      }
    }
    return buddies.addAllNew(strangers);
  }

  void _begin(String? accountId) {
    _busy = true;
    _busyAccountId = accountId;
    _error = null;
    notifyListeners();
  }

  void _end() {
    _busy = false;
    _busyAccountId = null;
    notifyListeners();
  }
}
