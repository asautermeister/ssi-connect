import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/account_color.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/garmin_personal_api_client.dart';

class _InMemoryRepository extends AccountRepository {
  final saved = <String, GarminAccount>{};

  @override
  Future<List<GarminAccount>> loadAll() async => saved.values.toList();

  @override
  Future<void> save(GarminAccount account) async => saved[account.id] = account;

  @override
  Future<void> remove(String accountId) async => saved.remove(accountId);
}

const _session = GarminSession(
  accessToken: 'a',
  refreshToken: 'r',
  diClientId: 'c',
);

/// Stands in for Garmin's token endpoint and records what it was asked.
class _RecordingPersonalApi implements GarminPersonalApiClient {
  _RecordingPersonalApi(this._answer);
  _RecordingPersonalApi.failing() : _answer = null;

  final GarminSession? _answer;
  final exchanged = <String>[];

  @override
  Future<GarminSession> exchange(String key) async {
    exchanged.add(key);
    final answer = _answer;
    if (answer == null) {
      throw GarminAuthException(
        GarminAuthErrorType.invalidCredentials,
        'Schlüssel abgelehnt.',
      );
    }
    return answer;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AccountsController naming', () {
    test('uses the given name for a new account', () async {
      final repository = _InMemoryRepository();
      final controller = AccountsController(repository: repository);

      final account = await controller.addAccountFromSuccess(
        email: 'marie.mustermann.1987@example.com',
        session: _session,
        displayName: 'Marie',
      );

      expect(account.displayName, 'Marie');
      expect(account.email, 'marie.mustermann.1987@example.com');
      expect(repository.saved[account.id]?.displayName, 'Marie');
    });

    test('falls back to the mail address when no name was given', () async {
      final controller = AccountsController(repository: _InMemoryRepository());

      final withoutName = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );
      final withBlankName = await controller.addAccountFromSuccess(
        email: 'b@example.com',
        session: _session,
        displayName: '   ',
      );

      expect(withoutName.displayName, 'a@example.com');
      expect(withBlankName.displayName, 'b@example.com');
    });

    test('trims a name typed with stray spaces', () async {
      final controller = AccountsController(repository: _InMemoryRepository());

      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
        displayName: '  Marie  ',
      );

      expect(account.displayName, 'Marie');
    });

    test('renames an existing account and persists it', () async {
      final repository = _InMemoryRepository();
      final controller = AccountsController(repository: repository);
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );

      await controller.rename(account.id, 'Andreas');

      expect(controller.accounts.single.displayName, 'Andreas');
      expect(repository.saved[account.id]?.displayName, 'Andreas');
    });

    test('renaming to nothing restores the mail address', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
        displayName: 'Andreas',
      );

      await controller.rename(account.id, '  ');

      // A nameless card on the start screen would be worse than a long one.
      expect(controller.accounts.single.displayName, 'a@example.com');
    });

    test('renaming keeps the session and the SSI identity', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );
      await controller.setSsiIdentity(
        account.id,
        const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
      );

      await controller.rename(account.id, 'Andreas');

      final updated = controller.accounts.single;
      expect(updated.ssiMemberId, '3902893');
      expect(updated.session.accessToken, 'a');
    });
  });

  group('AccountsController one entry per Garmin account', () {
    test('a key for an account that is here switches it over', () async {
      // Seen on the test device: the same person once by password and once
      // by key, two entries, the same dives loaded twice.
      final repository = _InMemoryRepository();
      final controller = AccountsController(repository: repository);
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
        displayName: 'Andreas',
      );
      await controller.setSsiIdentity(
        account.id,
        const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
      );
      await controller.setColor(account.id, AccountColor.blue);

      final result = await controller.addAccountFromSuccess(
        email: 'A@Example.com',
        session: const GarminSession.personal(
          accessToken: 'k',
          key: 'GCDC_a.b.c.d',
        ),
        displayName: 'Andreas Sautermeister',
      );

      final only = controller.accounts.single;
      expect(result.id, account.id);
      expect(only.id, account.id);
      expect(only.session.isPersonal, isTrue);
      expect(only.displayName, 'Andreas');
      expect(only.ssiMemberId, '3902893');
      expect(only.color, AccountColor.blue);
      expect(repository.saved.keys, [account.id]);
      expect(repository.saved[account.id]!.session.isPersonal, isTrue);
    });

    test('a password for a key account switches it back', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: const GarminSession.personal(
          accessToken: 'k',
          key: 'GCDC_a.b.c.d',
        ),
      );

      await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );

      final only = controller.accounts.single;
      expect(only.id, account.id);
      expect(only.session.isPersonal, isFalse);
    });

    test('a different address is a different account', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );
      await controller.addAccountFromSuccess(
        email: 'b@example.com',
        session: _session,
      );

      expect(controller.accounts, hasLength(2));
    });

    test('without an address there is nothing to match', () async {
      // The key route takes the address from the profile, and Garmin may
      // leave it out. Then two entries are better than a wrong merge.
      final controller = AccountsController(repository: _InMemoryRepository());
      await controller.addAccountFromSuccess(email: '', session: _session);
      await controller.addAccountFromSuccess(email: '', session: _session);

      expect(controller.accounts, hasLength(2));
    });
  });

  group('AccountsController.removePersonalKey', () {
    test('signs the account out and keeps everything else', () async {
      final repository = _InMemoryRepository();
      final controller = AccountsController(repository: repository);
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: const GarminSession.personal(
          accessToken: 'k',
          key: 'GCDC_a.b.c.d',
        ),
        displayName: 'Andreas',
      );
      await controller.setSsiIdentity(
        account.id,
        const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
      );
      await controller.setColor(account.id, AccountColor.blue);

      await controller.removePersonalKey(account.id);

      final only = controller.accounts.single;
      expect(only.session.isSignedOut, isTrue);
      expect(only.session.personalApiKey, isNull);
      expect(only.displayName, 'Andreas');
      expect(only.ssiMemberId, '3902893');
      expect(only.color, AccountColor.blue);
      // The key must be gone from storage too, not just from memory.
      expect(repository.saved[account.id]!.session.personalApiKey, isNull);
    });

    test('a password account is left alone', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );

      await controller.removePersonalKey(account.id);

      expect(controller.accounts.single.session.refreshToken, 'r');
    });

    test('a signed-out account takes a sign-in again', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: const GarminSession.personal(
          accessToken: 'k',
          key: 'GCDC_a.b.c.d',
        ),
      );
      await controller.removePersonalKey(account.id);

      await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );

      final only = controller.accounts.single;
      expect(only.id, account.id);
      expect(only.session.isSignedOut, isFalse);
    });
  });

  test('a signed-out session survives storage', () {
    final back = GarminSession.fromJson(const GarminSession.none().toJson());
    expect(back.isSignedOut, isTrue);
  });

  group('AccountsController.reconnect', () {
    test('a fresh session lands on the account that already exists', () async {
      // The reported failure: Garmin stopped accepting the refresh token on
      // the test device, nothing loaded any more, and the only way out was
      // to delete the account and set it up again from scratch.
      final repository = _InMemoryRepository();
      final controller = AccountsController(repository: repository);
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
        displayName: 'Andreas',
      );
      await controller.setSsiIdentity(
        account.id,
        const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
      );
      await controller.setColor(account.id, AccountColor.blue);

      await controller.reconnect(
        accountId: account.id,
        session: const GarminSession(
          accessToken: 'fresh',
          refreshToken: 'fresh-r',
          diClientId: 'c',
        ),
      );

      // One account, not two, and the same one: everything hanging off its
      // id has to survive, or signing in again costs the SSI number, the
      // colour and the cached dives.
      final updated = controller.accounts.single;
      expect(updated.id, account.id);
      expect(updated.session.accessToken, 'fresh');
      expect(updated.session.refreshToken, 'fresh-r');
      expect(updated.displayName, 'Andreas');
      expect(updated.ssiMemberId, '3902893');
      expect(updated.color, AccountColor.blue);

      // And it reached storage, not just memory.
      expect(repository.saved[account.id]!.session.accessToken, 'fresh');
    });

    test('an unknown id changes nothing', () async {
      final controller = AccountsController(repository: _InMemoryRepository());
      await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: _session,
      );

      await controller.reconnect(accountId: 'nobody', session: _session);

      expect(controller.accounts, hasLength(1));
      expect(controller.accounts.single.session.accessToken, 'a');
    });
  });

  group('AccountsController.ensureFreshSession', () {
    test('a key account mints a new token instead of refreshing', () async {
      // There is no refresh token on the Personal API side, so the only
      // way to a fresh token is asking again with the same key.
      final api = _RecordingPersonalApi(
        GarminSession.personal(
          accessToken: 'fresh',
          key: 'GCDC_a.b.c.d',
          tokenExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 20)),
        ),
      );
      final repository = _InMemoryRepository();
      final controller = AccountsController(
        repository: repository,
        personalApi: api,
      );
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: GarminSession.personal(
          accessToken: 'stale',
          key: 'GCDC_a.b.c.d',
          // Already gone, so it cannot be reused.
          tokenExpiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );

      final session = await controller.ensureFreshSession(account);

      expect(api.exchanged, ['GCDC_a.b.c.d']);
      expect(session.accessToken, 'fresh');
      // And it is kept, so the next start does not ask again.
      expect(repository.saved[account.id]!.session.accessToken, 'fresh');
    });

    test('a token with time left is reused, costing no round trip', () async {
      final api = _RecordingPersonalApi(
        const GarminSession.personal(accessToken: 'fresh', key: 'k'),
      );
      final controller = AccountsController(
        repository: _InMemoryRepository(),
        personalApi: api,
      );
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: GarminSession.personal(
          accessToken: 'still-good',
          key: 'GCDC_a.b.c.d',
          tokenExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
        ),
      );

      final session = await controller.ensureFreshSession(account);

      expect(api.exchanged, isEmpty);
      expect(session.accessToken, 'still-good');
    });

    test('a token without a known expiry is always renewed', () async {
      // Rather than assuming it is still good: the expiry is unknown, not
      // far away.
      final api = _RecordingPersonalApi(
        const GarminSession.personal(accessToken: 'fresh', key: 'k'),
      );
      final controller = AccountsController(
        repository: _InMemoryRepository(),
        personalApi: api,
      );
      final account = await controller.addAccountFromSuccess(
        email: 'a@example.com',
        session: const GarminSession.personal(
          accessToken: 'unknown-age',
          key: 'GCDC_a.b.c.d',
        ),
      );

      await controller.ensureFreshSession(account);

      expect(api.exchanged, hasLength(1));
    });

    test(
      'a dead key surfaces as credentials, so the card can offer a new one',
      () {
        final api = _RecordingPersonalApi.failing();
        final controller = AccountsController(
          repository: _InMemoryRepository(),
          personalApi: api,
        );

        expect(
          controller
              .addAccountFromSuccess(
                email: 'a@example.com',
                session: const GarminSession.personal(
                  accessToken: 'stale',
                  key: 'GCDC_a.b.c.d',
                ),
              )
              .then(controller.ensureFreshSession),
          throwsA(
            isA<GarminAuthException>().having(
              (e) => e.type,
              'type',
              GarminAuthErrorType.invalidCredentials,
            ),
          ),
        );
      },
    );
  });
}
