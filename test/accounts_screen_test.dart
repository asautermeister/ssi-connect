import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ui/accounts_screen.dart';
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

class _InMemoryBuddies extends SsiBuddyRepository {
  @override
  Future<List<SsiBuddyCode>> loadAll() async => const [];

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async {}
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

Dive _dive(String id, DateTime at, {double depth = 28}) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: depth,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
);

/// Pre-fills the controller so the screen's own load call is a no-op - it
/// short-circuits for a set of accounts it already has, which keeps the
/// widget test off the network.
Future<void> _pump(
  WidgetTester tester, {
  required List<GarminAccount> accounts,
  Map<String, List<Dive>> dives = const {},
  Set<String> failing = const {},
}) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final accountsController = AccountsController(
    repository: _InMemoryAccounts(accounts),
  );
  final buddies = SsiBuddiesController(repository: _InMemoryBuddies());
  final recent = RecentDivesController();
  await accountsController.loadFromStorage();
  await buddies.loadFromStorage();
  if (accounts.isNotEmpty) {
    await recent.load(
      accounts: accounts,
      fetch: (account) async {
        if (failing.contains(account.id)) throw StateError('nicht erreichbar');
        return dives[account.id] ?? const [];
      },
    );
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountsController),
        ChangeNotifierProvider.value(value: buddies),
        ChangeNotifierProvider.value(value: recent),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const AccountsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AccountsScreen', () {
    testWidgets('leads with the newest dives across all accounts', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [_account('Andreas'), _account('Marie')],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 1), depth: 44)],
          'Marie': [_dive('m1', DateTime(2025, 11, 8), depth: 12)],
        },
      );

      expect(find.text('Zuletzt getaucht'), findsOneWidget);
      // Marie's is newer, so it comes first even though Andreas is listed
      // first among the accounts.
      final marie = tester.getRect(find.text('Sa, 08.11.2025'));
      final andreas = tester.getRect(find.text('Sa, 01.11.2025'));
      expect(marie.top, lessThan(andreas.top));
      expect(find.textContaining('Marie'), findsWidgets);
    });

    testWidgets('a recent dive goes straight to its QR code', (tester) async {
      await _pump(
        tester,
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 7))],
        },
      );

      await tester.tap(find.text('Fr, 07.11.2025'));
      await tester.pumpAndSettle();

      expect(find.text('Mit SSI-App scannen'), findsOneWidget);
    });

    testWidgets('the account card names its most recent dive', (tester) async {
      await _pump(
        tester,
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
        dives: {
          'Andreas': [
            _dive('old', DateTime(2025, 10, 1), depth: 12),
            _dive('new', DateTime(2025, 11, 8), depth: 44),
          ],
        },
      );

      expect(find.text('Zuletzt: 08.11.2025 · 44,0 m'), findsOneWidget);
      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
    });

    testWidgets('an account without an SSI number is asked for one', (
      tester,
    ) async {
      await _pump(tester, accounts: [_account('Marie')]);

      expect(find.text('SSI-Nummer hinterlegen'), findsOneWidget);

      await tester.tap(find.text('SSI-Nummer hinterlegen'));
      await tester.pumpAndSettle();

      expect(find.text('SSI-Identität'), findsOneWidget);
    });

    testWidgets('an account can be renamed from its options menu', (
      tester,
    ) async {
      await _pump(tester, accounts: [_account('lang@example.com')]);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Namen ändern'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Marie');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Marie'), findsOneWidget);
      expect(find.text('lang@example.com'), findsNothing);
    });

    testWidgets('a broken account is named, not silently dropped', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [_account('Andreas'), _account('Marie')],
        dives: {
          'Marie': [_dive('m1', DateTime(2025, 11, 8))],
        },
        failing: {'Andreas'},
      );

      expect(find.textContaining('Ein Account konnte nicht'), findsOneWidget);
      expect(find.text('Tauchgänge nicht erreichbar'), findsOneWidget);
      // The working account still shows its dive.
      expect(find.text('Sa, 08.11.2025'), findsOneWidget);
    });

    testWidgets('the side entrances are cards, not hidden app-bar icons', (
      tester,
    ) async {
      await _pump(tester, accounts: [_account('Andreas')]);

      for (final label in const [
        'SSI-Buddies',
        'FIT-Datei importieren',
        'API-Protokoll',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });

    testWidgets('without accounts it still offers a way forward', (
      tester,
    ) async {
      await _pump(tester, accounts: const []);

      expect(find.text('Noch kein Garmin-Account verbunden'), findsOneWidget);
      // The FIT import is the fallback when no login works, so it must not
      // disappear along with the account list.
      expect(find.text('FIT-Datei importieren'), findsOneWidget);
      expect(find.text('Zuletzt getaucht'), findsNothing);
    });
  });
}
