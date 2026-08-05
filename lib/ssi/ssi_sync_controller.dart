import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../accounts/accounts_controller.dart';
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

  static const _lastSyncKey = 'ssi_connect.ssi.last_sync';

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

  /// When the logbooks were last read.
  ///
  /// Outlives the app run, unlike the counts beside it: those describe the
  /// sync you just watched happen, this answers "is what I am looking at
  /// still current?" days later.
  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  Future<void> initialize() async {
    await _storage.delete(key: _legacyAccountKey);
    final stored = await _storage.read(key: _lastSyncKey);
    _lastSyncAt = stored == null ? null : DateTime.tryParse(stored);
    notifyListeners();
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

  /// Pulls the logbooks of every connected account: dive sites into
  /// [sites], the buddies into [buddies].
  ///
  /// One failing account does not stop the others: a stale token on one
  /// logbook is no reason to withhold the rest. Whatever failed is
  /// reported afterwards.
  Future<bool> syncAll({
    required AccountsController accounts,
    required DiveSitesController sites,
    required SsiBuddiesController buddies,
    required ExportedDivesController exported,
  }) async {
    final connected = accounts.accounts.where((a) => a.hasSsiLogin).toList();
    if (connected.isEmpty) return false;

    _begin(null);
    var siteTotal = 0;
    var siteAdded = 0;
    var buddyTotal = 0;
    final harvested = <SsiBuddyCode>[];
    final failures = <String>[];
    try {
      for (final account in connected) {
        try {
          final logbook = await _client.loadLogbook(account.ssiSession!);
          siteTotal += logbook.sites.length;
          siteAdded += await sites.addAllNew(logbook.sites);
          buddyTotal += logbook.buddies.length;
          harvested.addAll(logbook.buddies);
          // Kept per account: a logbook may only ever be matched against
          // its own person's dives.
          await exported.setLogbook(account.id, logbook.dives);
        } on SsiApiException catch (e) {
          failures.add('${account.displayName}: ${e.message}');
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

      // Recorded when at least one logbook came through: what is on the
      // device really is that fresh. Had every account failed, the old
      // timestamp is the honest answer and stays.
      if (failures.length < connected.length) {
        _lastSyncAt = DateTime.now();
        await _storage.write(
          key: _lastSyncKey,
          value: _lastSyncAt!.toIso8601String(),
        );
      }

      if (failures.isNotEmpty) _error = failures.join('\n');
      return failures.isEmpty;
    } finally {
      _end();
    }
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
