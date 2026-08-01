import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';

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
}
