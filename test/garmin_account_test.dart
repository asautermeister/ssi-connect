import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/models/account_color.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';

GarminAccount _account({
  String? ssiMemberId,
  String? ssiFirstName,
  String? ssiLastName,
}) {
  return GarminAccount(
    id: 'local-1',
    email: 'diver@example.com',
    displayName: 'Andreas',
    session: const GarminSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      diClientId: 'client',
    ),
    ssiMemberId: ssiMemberId,
    ssiFirstName: ssiFirstName,
    ssiLastName: ssiLastName,
  );
}

void main() {
  group('GarminAccount SSI identity', () {
    test('reports whether an identity is stored', () {
      expect(_account().hasSsiIdentity, isFalse);
      expect(_account(ssiMemberId: '3902893').hasSsiIdentity, isTrue);
    });

    test('joins the name, tolerating a missing half', () {
      expect(
        _account(
          ssiFirstName: 'Andreas',
          ssiLastName: 'Sautermeister',
        ).ssiFullName,
        'Andreas Sautermeister',
      );
      expect(_account(ssiFirstName: 'Andreas').ssiFullName, 'Andreas');
      expect(_account().ssiFullName, isNull);
    });

    test('round-trips through JSON, since accounts are persisted', () {
      final original = _account(
        ssiMemberId: '3902893',
        ssiFirstName: 'Andreas',
        ssiLastName: 'Sautermeister',
      );

      final restored = GarminAccount.fromJson(original.toJson());

      expect(restored.ssiMemberId, '3902893');
      expect(restored.ssiFullName, 'Andreas Sautermeister');
      expect(restored.session.accessToken, 'token');
    });

    test('reads back an account saved before SSI fields existed', () {
      // Older stored accounts simply lack the keys; they must still load.
      final restored = GarminAccount.fromJson({
        'id': 'local-1',
        'email': 'diver@example.com',
        'displayName': 'Andreas',
        'session': {
          'accessToken': 'token',
          'refreshToken': 'refresh',
          'diClientId': 'client',
        },
      });

      expect(restored.hasSsiIdentity, isFalse);
    });

    test('withoutSsiIdentity clears fields copyWith cannot', () {
      final cleared = _account(
        ssiMemberId: '3902893',
        ssiFirstName: 'Andreas',
      ).withoutSsiIdentity();

      expect(cleared.hasSsiIdentity, isFalse);
      expect(cleared.ssiFirstName, isNull);
      // Everything else survives.
      expect(cleared.displayName, 'Andreas');
      expect(cleared.session.accessToken, 'token');
    });
  });

  group('GarminAccount colour', () {
    test('survives a JSON round trip', () {
      final restored = GarminAccount.fromJson(
        _account().withColor(AccountColor.violet).toJson(),
      );

      expect(restored.color, AccountColor.violet);
    });

    test('an account stored before colours existed simply has none', () {
      final restored = GarminAccount.fromJson({
        'id': 'local-1',
        'email': 'diver@example.com',
        'displayName': 'Andreas',
        'session': {
          'accessToken': 'token',
          'refreshToken': 'refresh',
          'diClientId': 'client',
        },
      });

      expect(restored.color, isNull);
    });

    test('withColor(null) clears it, which copyWith cannot', () {
      final cleared = _account().withColor(AccountColor.blue).withColor(null);

      expect(cleared.color, isNull);
    });

    test('the colour survives a rename and an SSI identity change', () {
      final coloured = _account().withColor(AccountColor.green);

      expect(coloured.copyWith(displayName: 'Marie').color, AccountColor.green);
      expect(coloured.withoutSsiIdentity().color, AccountColor.green);
    });
  });
}
