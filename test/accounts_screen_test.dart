import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/account_color.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_cache_repository.dart';
import 'package:ssi_connect/dives/dive_loader.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ui/accounts_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';
import 'package:ssi_connect/ui/widgets/app_card.dart';

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

class _InMemoryCache extends DiveCacheRepository {
  final stored = <String, CachedDives>{};

  @override
  Future<CachedDives?> load(String accountId) async => stored[accountId];

  @override
  Future<void> save(String accountId, List<Dive> dives) async {
    stored[accountId] = CachedDives(dives: dives, fetchedAt: DateTime.now());
  }

  @override
  Future<void> clear(String accountId) async => stored.remove(accountId);
}

GarminAccount _account(
  String name, {
  String? ssiMemberId,
  AccountColor? color,
}) => GarminAccount(
  id: name,
  email: '$name@example.com',
  displayName: name,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
  ssiMemberId: ssiMemberId,
  color: color,
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
  Map<String, CachedDives> cached = const {},
  bool offline = false,
}) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final accountsController = AccountsController(
    repository: _InMemoryAccounts(accounts),
  );
  final buddies = SsiBuddiesController(repository: _InMemoryBuddies());
  final cache = _InMemoryCache()..stored.addAll(cached);
  final recent = RecentDivesController(cache: cache);
  await accountsController.loadFromStorage();
  await buddies.loadFromStorage();

  Future<List<Dive>> fetch(GarminAccount account) async {
    if (offline) {
      throw GarminAuthException(
        GarminAuthErrorType.offline,
        'Keine Internetverbindung.',
      );
    }
    if (failing.contains(account.id)) throw StateError('nicht erreichbar');
    return dives[account.id] ?? const [];
  }

  if (accounts.isNotEmpty) {
    await recent.load(accounts: accounts, fetch: fetch);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountsController),
        ChangeNotifierProvider.value(value: buddies),
        ChangeNotifierProvider.value(value: recent),
        Provider<DiveFetcher>.value(value: fetch),
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
        'SSI Buddy',
        'FIT-Datei importieren',
        'Info',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // The diagnostic tools moved behind the version tap in the info
      // screen, so nothing on the start screen mentions them.
      expect(find.text('API-Protokoll'), findsNothing);
      expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
    });

    testWidgets('a dive is marked with its account colour', (tester) async {
      await _pump(
        tester,
        accounts: [
          _account('Andreas', color: AccountColor.blue),
          _account('Marie'),
        ],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 8))],
          'Marie': [_dive('m1', DateTime(2025, 11, 7))],
        },
      );

      final blue = AccountColor.blue.resolve(Brightness.light);
      final marked = tester
          .widgetList<AppCard>(find.byType(AppCard))
          .where((card) => card.edgeColor == blue);
      // Two: the dive card and the account card, so the bar on a dive can
      // be traced back to a person on the same screen.
      expect(marked, hasLength(2));

      // Nobody else gets a bar just because someone picked a colour.
      final unmarked = tester
          .widgetList<AppCard>(find.byType(AppCard))
          .where((card) => card.edgeColor == null);
      expect(unmarked, isNotEmpty);
    });

    testWidgets('a colour can be picked from the account menu', (tester) async {
      await _pump(
        tester,
        accounts: [_account('Andreas')],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 8))],
        },
      );

      expect(
        tester
            .widgetList<AppCard>(find.byType(AppCard))
            .every((card) => card.edgeColor == null),
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Farbe wählen'));
      await tester.pumpAndSettle();
      // Named, so the picker is usable without seeing the colours.
      await tester.tap(find.byTooltip('Grün'));
      await tester.pumpAndSettle();

      final green = AccountColor.green.resolve(Brightness.light);
      expect(
        tester
            .widgetList<AppCard>(find.byType(AppCard))
            .where((card) => card.edgeColor == green),
        hasLength(2),
      );
    });

    testWidgets('the colour can be taken away again', (tester) async {
      await _pump(
        tester,
        accounts: [_account('Andreas', color: AccountColor.pink)],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 8))],
        },
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Farbe wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keine Farbe'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<AppCard>(find.byType(AppCard))
            .every((card) => card.edgeColor == null),
        isTrue,
      );
    });

    testWidgets('offline, it shows the cached dives and says so', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [_account('Andreas')],
        cached: {
          'Andreas': CachedDives(
            dives: [_dive('a1', DateTime(2025, 11, 7), depth: 28)],
            fetchedAt: DateTime(2025, 11, 7, 16, 30),
          ),
        },
        offline: true,
      );

      expect(find.text('Keine Internetverbindung'), findsOneWidget);
      // The age is the thing that decides whether this is the dive you just
      // did, so it has to be on screen.
      expect(find.text('Stand: 07.11.2025 · 16:30 Uhr'), findsOneWidget);
      // And the dives are still usable, which is the whole point.
      expect(find.text('Fr, 07.11.2025'), findsOneWidget);
    });

    testWidgets('a failure that reached Garmin is not called offline', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [_account('Andreas')],
        cached: {
          'Andreas': CachedDives(
            dives: [_dive('a1', DateTime(2025, 11, 7))],
            fetchedAt: DateTime(2025, 11, 7, 16, 30),
          ),
        },
        failing: {'Andreas'},
      );

      // Telling someone to check their connection when the request got
      // through would send them looking in the wrong place.
      expect(find.text('Keine Internetverbindung'), findsNothing);
      expect(find.text('Gespeicherte Tauchgänge'), findsOneWidget);
    });

    testWidgets('online, nothing claims the data is stale', (tester) async {
      await _pump(
        tester,
        accounts: [_account('Andreas')],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 7))],
        },
      );

      expect(find.text('Keine Internetverbindung'), findsNothing);
      expect(find.text('Gespeicherte Tauchgänge'), findsNothing);
    });

    testWidgets('cached dives can be deleted from the account menu', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [_account('Andreas')],
        dives: {
          'Andreas': [_dive('a1', DateTime(2025, 11, 7))],
        },
      );

      expect(find.text('Fr, 07.11.2025'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gespeicherte Tauchgänge löschen'));
      await tester.pump();

      expect(find.text('Gespeicherte Tauchgänge gelöscht'), findsOneWidget);

      // Let the snack bar time out, so the test doesn't end with a pending
      // timer.
      await tester.pump(const Duration(seconds: 5));
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
