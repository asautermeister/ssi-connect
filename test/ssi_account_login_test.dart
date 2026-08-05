import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_api_client.dart';
import 'package:ssi_connect/ssi/ssi_api_exceptions.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ssi/ssi_logged_dive.dart';
import 'package:ssi_connect/ssi/ssi_session.dart';
import 'package:ssi_connect/ssi/ssi_sync_controller.dart';

import 'support/exported_dives.dart';

GarminAccount _account(
  String name, {
  SsiSession? ssiSession,
  String? memberId,
}) => GarminAccount(
  id: name,
  email: '$name@example.com',
  displayName: name,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
  ssiMemberId: memberId,
  ssiSession: ssiSession,
);

class _StoringAccounts extends AccountRepository {
  _StoringAccounts(this.stored);

  List<GarminAccount> stored;

  @override
  Future<List<GarminAccount>> loadAll() async => stored;

  @override
  Future<void> save(GarminAccount account) async {
    final index = stored.indexWhere((a) => a.id == account.id);
    stored = [...stored];
    if (index == -1) {
      stored.add(account);
    } else {
      stored[index] = account;
    }
  }

  @override
  Future<void> remove(String accountId) async =>
      stored = stored.where((a) => a.id != accountId).toList();
}

class _InMemorySites extends DiveSiteRepository {
  List<DiveSite> stored = const [];

  @override
  Future<List<DiveSite>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<DiveSite> sites) async => stored = sites;
}

/// Answers per token, so two accounts can hold different logbooks.
class _FakeClient extends SsiApiClient {
  _FakeClient(
    this.byToken, {
    this.buddiesByToken = const {},
    this.divesByToken = const {},
    this.rejected = const {},
  });

  final Map<String, List<DiveSite>> byToken;
  final Map<String, List<SsiBuddyCode>> buddiesByToken;
  final Map<String, List<SsiLoggedDive>> divesByToken;
  final Set<String> rejected;

  @override
  Future<SsiLogbook> loadLogbook(SsiSession session) async {
    if (rejected.contains(session.token)) {
      throw SsiApiException(
        SsiApiErrorType.invalidCredentials,
        'Sitzung abgelaufen',
      );
    }
    return (
      sites: byToken[session.token] ?? const [],
      buddies: buddiesByToken[session.token] ?? const [],
      dives: divesByToken[session.token] ?? const [],
    );
  }
}

class _InMemoryBuddies extends SsiBuddyRepository {
  List<SsiBuddyCode> stored = const [];

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

/// Stands in for the keystore, which needs a platform under a widget-less
/// test - and the sync timestamp is written there.
class _FakeStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);
}

ExportedDivesController _exported() =>
    ExportedDivesController(repository: InMemoryExportedDives());

Future<SsiBuddiesController> _emptyBuddies() async {
  final controller = SsiBuddiesController(repository: _InMemoryBuddies());
  await controller.loadFromStorage();
  return controller;
}

DiveSite _site(String id) =>
    DiveSite(siteId: id, name: 'Platz $id', latitude: 36, longitude: 14);

Future<AccountsController> _accountsWith(List<GarminAccount> accounts) async {
  final controller = AccountsController(repository: _StoringAccounts(accounts));
  await controller.loadFromStorage();
  return controller;
}

Future<DiveSitesController> _emptySites() async {
  final controller = DiveSitesController(repository: _InMemorySites());
  await controller.loadFromStorage();
  return controller;
}

void main() {
  group('GarminAccount with an SSI login', () {
    const session = SsiSession(
      email: 'diver@example.com',
      token: 'tok',
      memberId: 3837926,
    );

    test('survives a JSON round trip', () {
      final restored = GarminAccount.fromJson(
        _account('Andreas', ssiSession: session).toJson(),
      );

      expect(restored.ssiSession?.token, 'tok');
      expect(restored.ssiSession?.memberId, 3837926);
      expect(restored.hasSsiLogin, isTrue);
    });

    test('an account stored before the login existed still reads', () {
      // No `ssiSession` key at all in the older shape.
      final json = _account('Andreas').toJson()..remove('ssiSession');

      expect(GarminAccount.fromJson(json).hasSsiLogin, isFalse);
    });

    test('signing out keeps the member number', () {
      // It is still this person's number, and a QR export needs nothing
      // else - dropping it would cost a scan for no reason.
      final account = _account(
        'Andreas',
        ssiSession: session,
        memberId: '3837926',
      ).withoutSsiSession();

      expect(account.hasSsiLogin, isFalse);
      expect(account.ssiMemberId, '3837926');
    });

    test('removing the identity drops the login with it', () {
      // The login is what vouches for the number; keeping it would leave a
      // token behind that nothing uses.
      final account = _account(
        'Andreas',
        ssiSession: session,
        memberId: '3837926',
      ).withoutSsiIdentity();

      expect(account.hasSsiLogin, isFalse);
      expect(account.ssiMemberId, isNull);
    });
  });

  group('AccountsController.setSsiSession', () {
    test('fills the member number from the login', () async {
      // `mid` is SSI's own number for the account - no scan, no typo.
      final accounts = await _accountsWith([_account('Andreas')]);

      await accounts.setSsiSession(
        'Andreas',
        const SsiSession(
          email: 'diver@example.com',
          token: 'tok',
          memberId: 3837926,
        ),
      );

      final account = accounts.accounts.single;
      expect(account.ssiMemberId, '3837926');
      expect(account.ssiEmail, 'diver@example.com');
      expect(account.hasSsiIdentity, isTrue);
    });

    test('keeps a name that was scanned earlier', () async {
      // The login reports no name, and losing one already on file would
      // make signing in a downgrade.
      final accounts = await _accountsWith([
        GarminAccount(
          id: 'a',
          email: 'a@example.com',
          displayName: 'Andreas',
          session: const GarminSession(
            accessToken: 'a',
            refreshToken: 'r',
            diClientId: 'c',
          ),
          ssiMemberId: '3837926',
          ssiFirstName: 'Andreas',
          ssiLastName: 'Sautermeister',
        ),
      ]);

      await accounts.setSsiSession(
        'a',
        const SsiSession(email: 'x@example.com', token: 't', memberId: 3837926),
      );

      expect(accounts.accounts.single.ssiFullName, 'Andreas Sautermeister');
    });
  });

  group('SsiSyncController.syncAll', () {
    test('pools the sites of every connected account', () async {
      // Two people, two logbooks, one device-wide list - a dive site is a
      // place, and the family shares those.
      final accounts = await _accountsWith([
        _account(
          'Andreas',
          ssiSession: const SsiSession(email: 'a@x', token: 'ta'),
        ),
        _account(
          'Marie',
          ssiSession: const SsiSession(email: 'm@x', token: 'tm'),
        ),
      ]);
      final sites = await _emptySites();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient({
          'ta': [_site('1'), _site('2')],
          // '2' is in both logbooks - they dived it together.
          'tm': [_site('2'), _site('3')],
        }),
      );

      final ok = await sync.syncAll(
        accounts: accounts,
        sites: sites,
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      expect(ok, isTrue);
      expect(sites.sites.map((s) => s.siteId).toSet(), {'1', '2', '3'});
      expect(sync.lastAddedCount, 3);
      // Four entries came back, one of them twice.
      expect(sync.lastSiteCount, 4);
    });

    test('one stale login does not withhold the other logbook', () async {
      final accounts = await _accountsWith([
        _account(
          'Andreas',
          ssiSession: const SsiSession(email: 'a@x', token: 'stale'),
        ),
        _account(
          'Marie',
          ssiSession: const SsiSession(email: 'm@x', token: 'tm'),
        ),
      ]);
      final sites = await _emptySites();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          {
            'tm': [_site('3')],
          },
          rejected: {'stale'},
        ),
      );

      final ok = await sync.syncAll(
        accounts: accounts,
        sites: sites,
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      expect(ok, isFalse);
      expect(sync.error, contains('Andreas'));
      // Marie's sites arrived regardless.
      expect(sites.sites.single.siteId, '3');
    });

    test('a rejected token is dropped rather than retried forever', () async {
      final accounts = await _accountsWith([
        _account(
          'Andreas',
          ssiSession: const SsiSession(email: 'a@x', token: 'stale'),
          memberId: '3837926',
        ),
      ]);
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(const {}, rejected: {'stale'}),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      expect(accounts.accounts.single.hasSsiLogin, isFalse);
      // But the number stays - the token expiring says nothing about it.
      expect(accounts.accounts.single.ssiMemberId, '3837926');
    });

    test('takes the buddies from the logbook too', () async {
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
          memberId: '3837926',
        ),
      ]);
      final buddies = await _emptyBuddies();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          const {},
          buddiesByToken: {
            'tj': const [
              SsiBuddyCode(
                memberId: '3902893',
                firstName: 'Andreas',
                lastName: 'Sautermeister',
                leaderNumber: '110890',
              ),
            ],
          },
        ),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: buddies,
        exported: _exported(),
      );

      expect(buddies.buddies.single.memberId, '3902893');
      // The professional number rides along - it is the same field a
      // scanned code carries.
      expect(buddies.buddies.single.leaderNumber, '110890');
      expect(sync.lastBuddyAddedCount, 1);
    });

    test('someone who has an account here is not also a buddy', () async {
      // Two family members on each other's buddy lists would otherwise
      // appear twice: once under their account, once in the buddy list.
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
          memberId: '3837926',
        ),
        _account('Andreas', memberId: '3902893'),
      ]);
      final buddies = await _emptyBuddies();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          const {},
          buddiesByToken: {
            'tj': const [
              SsiBuddyCode(
                memberId: '3902893',
                firstName: 'Andreas',
                lastName: 'Sautermeister',
              ),
            ],
          },
        ),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: buddies,
        exported: _exported(),
      );

      expect(buddies.buddies, isEmpty);
      // Instead the entry gives the account the name that a login does not
      // report.
      final andreas = accounts.accounts.firstWhere((a) => a.id == 'Andreas');
      expect(andreas.ssiFullName, 'Andreas Sautermeister');
    });

    test('a name already on file is not overwritten', () async {
      final accounts = await _accountsWith([
        GarminAccount(
          id: 'Andreas',
          email: 'a@example.com',
          displayName: 'Andreas',
          session: const GarminSession(
            accessToken: 'a',
            refreshToken: 'r',
            diClientId: 'c',
          ),
          ssiMemberId: '3902893',
          ssiFirstName: 'Andi',
          ssiSession: const SsiSession(email: 'a@x', token: 'ta'),
        ),
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
          memberId: '3837926',
        ),
      ]);
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          const {},
          buddiesByToken: {
            'tj': const [
              SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
            ],
          },
        ),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      // Somebody chose "Andi" on this device; a stranger's spelling does
      // not get to replace it.
      final andreas = accounts.accounts.firstWhere((a) => a.id == 'Andreas');
      expect(andreas.ssiFirstName, 'Andi');
    });

    test('the same buddy in two logbooks is stored once', () async {
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
        ),
        _account(
          'Eva',
          ssiSession: const SsiSession(email: 'e@x', token: 'te'),
        ),
      ]);
      final buddies = await _emptyBuddies();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          const {},
          buddiesByToken: {
            'tj': const [SsiBuddyCode(memberId: '3902893')],
            'te': const [SsiBuddyCode(memberId: '3902893')],
          },
        ),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: buddies,
        exported: _exported(),
      );

      expect(buddies.buddies, hasLength(1));
      expect(sync.lastBuddyAddedCount, 1);
      // Both logbooks named them, and that is what was seen.
      expect(sync.lastBuddyCount, 2);
    });

    test('records when the logbooks were last read', () async {
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
        ),
      ]);
      final storage = _FakeStorage();
      final sync = SsiSyncController(
        storage: storage,
        client: _FakeClient(const {}),
      );

      final before = DateTime.now();
      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      expect(sync.lastSyncAt, isNotNull);
      expect(sync.lastSyncAt!.isBefore(before), isFalse);

      // Survives a restart: the counts describe a sync you just watched,
      // this answers "is this still current?" days later.
      final restarted = SsiSyncController(
        storage: storage,
        client: _FakeClient(const {}),
      );
      await restarted.initialize();
      expect(
        restarted.lastSyncAt?.toIso8601String(),
        sync.lastSyncAt?.toIso8601String(),
      );
    });

    test('a sync where everything failed does not count as fresh', () async {
      // Otherwise the timestamp would promise data that never arrived.
      final storage = _FakeStorage();
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'stale'),
        ),
      ]);
      final sync = SsiSyncController(
        storage: storage,
        client: _FakeClient(const {}, rejected: {'stale'}),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: await _emptyBuddies(),
        exported: _exported(),
      );

      expect(sync.lastSyncAt, isNull);
      expect(storage.values, isEmpty);
    });

    test("keeps each account's logbook to itself", () async {
      final accounts = await _accountsWith([
        _account(
          'Jan',
          ssiSession: const SsiSession(email: 'j@x', token: 'tj'),
        ),
      ]);
      final exported = ExportedDivesController(
        repository: InMemoryExportedDives(),
      );
      await exported.loadFromStorage();
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(
          const {},
          divesByToken: {
            'tj': [
              SsiLoggedDive(
                dateTime: DateTime(2023, 8, 12, 12, 54),
                depthMeters: 13,
              ),
            ],
          },
        ),
      );

      await sync.syncAll(
        accounts: accounts,
        sites: await _emptySites(),
        buddies: await _emptyBuddies(),
        exported: exported,
      );

      final dive = Dive(
        id: 'd',
        dateTime: DateTime(2023, 8, 12, 12, 54),
        maxDepthMeters: 13,
        avgDepthMeters: null,
        waterTemperatureCelsius: null,
        duration: const Duration(minutes: 19),
        locationName: null,
      );
      expect(exported.matchedIn('Jan', [dive]), {'d'});
      // The same dive under somebody else's account is not theirs to tick.
      expect(exported.matchedIn('Eva', [dive]), isEmpty);
    });

    test('does nothing when nobody is connected', () async {
      final accounts = await _accountsWith([_account('Andreas')]);
      final sync = SsiSyncController(
        storage: _FakeStorage(),
        client: _FakeClient(const {}),
      );

      expect(
        await sync.syncAll(
          accounts: accounts,
          sites: await _emptySites(),
          buddies: await _emptyBuddies(),
          exported: _exported(),
        ),
        isFalse,
      );
      expect(sync.error, isNull);
    });
  });
}
