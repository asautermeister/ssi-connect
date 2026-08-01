import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ui/qr_display_screen.dart';
import 'package:ssi_connect/ui/ssi_buddies_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

class _InMemoryAccounts extends AccountRepository {
  _InMemoryAccounts(this.stored);

  List<GarminAccount> stored;

  @override
  Future<List<GarminAccount>> loadAll() async => stored;

  @override
  Future<void> save(GarminAccount account) async {}

  @override
  Future<void> remove(String accountId) async {}
}

GarminAccount _account(String name, {String? ssiMemberId}) => GarminAccount(
  id: name,
  email: '$name@example.com',
  displayName: name,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
  ssiMemberId: ssiMemberId,
);

class _InMemoryBuddies extends SsiBuddyRepository {
  _InMemoryBuddies(this.stored);

  List<SsiBuddyCode> stored;

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

Future<SsiBuddiesController> _pump(
  WidgetTester tester,
  List<SsiBuddyCode> buddies, {
  List<GarminAccount> accounts = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = SsiBuddiesController(
    repository: _InMemoryBuddies(buddies),
  );
  final accountsController = AccountsController(
    repository: _InMemoryAccounts(accounts),
  );
  await controller.loadFromStorage();
  await accountsController.loadFromStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: accountsController),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SsiBuddiesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('SsiBuddiesScreen', () {
    testWidgets('tapping a buddy shows their code for someone else to scan', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(
          memberId: '3902893',
          firstName: 'Andreas',
          lastName: 'Sautermeister',
        ),
      ]);

      await tester.tap(find.text('Andreas Sautermeister'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      // The payload has to be what SSI itself shows, or another app can't
      // read it back.
      expect(
        screen.payload,
        'buddy;3902893;firstName:Andreas;lastName:Sautermeister',
      );
      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
    });

    testWidgets('the code is also reachable from the options menu', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(memberId: '99', firstName: 'Cem'),
      ]);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Als QR-Code zeigen'));
      await tester.pumpAndSettle();

      expect(find.byType(QrDisplayScreen), findsOneWidget);
    });

    testWidgets('lists accounts that have an SSI number', (tester) async {
      await _pump(
        tester,
        [const SsiBuddyCode(memberId: '99', firstName: 'Cem')],
        accounts: [
          _account('Andreas', ssiMemberId: '3902893'),
          // No SSI number: nothing to show as a code, so not listed.
          _account('Jonas'),
        ],
      );

      expect(find.text('Aus den Accounts'), findsOneWidget);
      expect(find.text('Andreas'), findsOneWidget);
      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
      expect(find.text('Jonas'), findsNothing);
      // The scanned buddy keeps its own section.
      expect(find.text('Zusätzlich gespeichert'), findsOneWidget);
      expect(find.text('Cem'), findsOneWidget);
    });

    testWidgets('an account can be shown as a code too', (tester) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      await tester.tap(find.text('Andreas'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      expect(screen.payload, startsWith('buddy;3902893'));
    });

    testWidgets('an account row offers no edit or delete', (tester) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      // Its number belongs to the account screen; a delete here would be
      // ambiguous about what it deletes.
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.text('GARMIN-ACCOUNT'), findsOneWidget);
    });

    testWidgets('someone with an account and a scan is listed once', (
      tester,
    ) async {
      await _pump(
        tester,
        [const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas')],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
      expect(find.text('Zusätzlich gespeichert'), findsNothing);
    });

    testWidgets('the empty state waits until both lists are empty', (
      tester,
    ) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );
      expect(find.text('Noch keine Buddies gespeichert'), findsNothing);

      await _pump(tester, const [], accounts: [_account('Jonas')]);
      expect(find.text('Noch keine Buddies gespeichert'), findsOneWidget);
    });

    testWidgets('a scanned code and a shown code are the same string', (
      tester,
    ) async {
      const original = 'buddy;7;firstName:Ada;lastName:L;email:ada@example.com';
      final parsed = SsiBuddyCode.tryParse(original)!;

      await _pump(tester, [parsed]);
      await tester.tap(find.text('Ada L'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      // Round trip: scanning this app's own output has to give the same
      // member back.
      expect(screen.payload, original);
      expect(SsiBuddyCode.tryParse(screen.payload)!.memberId, '7');
    });
  });
}
