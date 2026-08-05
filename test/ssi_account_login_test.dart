import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_api_client.dart';
import 'package:ssi_connect/ssi/ssi_api_exceptions.dart';
import 'package:ssi_connect/ssi/ssi_session.dart';
import 'package:ssi_connect/ssi/ssi_sync_controller.dart';

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
  _FakeClient(this.byToken, {this.rejected = const {}});

  final Map<String, List<DiveSite>> byToken;
  final Set<String> rejected;

  @override
  Future<List<DiveSite>> loadLogbookSites(SsiSession session) async {
    if (rejected.contains(session.token)) {
      throw SsiApiException(
        SsiApiErrorType.invalidCredentials,
        'Sitzung abgelaufen',
      );
    }
    return byToken[session.token] ?? const [];
  }
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
        client: _FakeClient({
          'ta': [_site('1'), _site('2')],
          // '2' is in both logbooks - they dived it together.
          'tm': [_site('2'), _site('3')],
        }),
      );

      final ok = await sync.syncAll(accounts: accounts, sites: sites);

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
        client: _FakeClient(
          {
            'tm': [_site('3')],
          },
          rejected: {'stale'},
        ),
      );

      final ok = await sync.syncAll(accounts: accounts, sites: sites);

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
        client: _FakeClient(const {}, rejected: {'stale'}),
      );

      await sync.syncAll(accounts: accounts, sites: await _emptySites());

      expect(accounts.accounts.single.hasSsiLogin, isFalse);
      // But the number stays - the token expiring says nothing about it.
      expect(accounts.accounts.single.ssiMemberId, '3837926');
    });

    test('does nothing when nobody is connected', () async {
      final accounts = await _accountsWith([_account('Andreas')]);
      final sync = SsiSyncController(client: _FakeClient(const {}));

      expect(
        await sync.syncAll(accounts: accounts, sites: await _emptySites()),
        isFalse,
      );
      expect(sync.error, isNull);
    });
  });
}
