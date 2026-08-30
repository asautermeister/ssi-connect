import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_cache_repository.dart';
import 'package:ssi_connect/dives/dive_loader.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_logged_dive.dart';
import 'package:ssi_connect/ui/developer_mode.dart';
import 'package:ssi_connect/ui/dive_list_screen.dart';
import 'package:ssi_connect/ui/dive_list_tile.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

import 'support/exported_dives.dart';

final _account = GarminAccount(
  id: 'andreas',
  email: 'a@example.com',
  displayName: 'Andreas',
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
);

Dive _dive(String id, DateTime at, {DiveType type = DiveType.scuba}) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
  type: type,
);

class _Accounts extends AccountRepository {
  @override
  Future<List<GarminAccount>> loadAll() async => [_account];

  @override
  Future<void> save(GarminAccount account) async {}

  @override
  Future<void> remove(String accountId) async {}
}

class _NoCache extends DiveCacheRepository {
  @override
  Future<CachedDives?> load(String accountId) async => null;

  @override
  Future<void> save(String accountId, List<Dive> dives) async {}

  @override
  Future<void> clear(String accountId) async {}
}

class _NoDiveSites extends DiveSiteRepository {
  @override
  Future<List<DiveSite>> loadAll() async => const [];

  @override
  Future<void> saveAll(List<DiveSite> sites) async {}
}

/// Pumps the per-account list with [dives], of which [transferred] are
/// ticked by hand and [logbook] is what SSI has on file for the account.
Future<void> _pump(
  WidgetTester tester, {
  required List<Dive> dives,
  Map<String, bool> transferred = const {},
  List<SsiLoggedDive> logbook = const [],
}) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final accounts = AccountsController(repository: _Accounts());
  await accounts.loadFromStorage();
  final recent = RecentDivesController(cache: _NoCache());

  Future<List<Dive>> fetch(GarminAccount account, {int start = 0}) async =>
      start == 0 ? dives : const [];
  await recent.load(accounts: [_account], fetch: fetch);

  final exported = ExportedDivesController(
    repository: InMemoryExportedDives(transferred),
  );
  await exported.loadFromStorage();
  if (logbook.isNotEmpty) await exported.setLogbook(_account.id, logbook);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accounts),
        ChangeNotifierProvider.value(value: recent),
        ChangeNotifierProvider.value(value: exported),
        ChangeNotifierProvider(
          create: (_) => DiveSitesController(repository: _NoDiveSites()),
        ),
        ChangeNotifierProvider(create: (_) => DeveloperMode()),
        Provider<DiveFetcher>.value(value: fetch),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        theme: AppTheme.light(),
        home: DiveListScreen(account: _account),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the filter on the dive list', () {
    testWidgets('starts on "Alle" and shows everything', (tester) async {
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9)),
          _dive('b', DateTime(2025, 11, 7, 9)),
        ],
        transferred: const {'a': true},
      );

      expect(find.text('Alle'), findsOneWidget);
      expect(find.byType(DiveListTile), findsNWidgets(2));
    });

    testWidgets('"Noch offen" hides what has gone across', (tester) async {
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9)),
          _dive('b', DateTime(2025, 11, 7, 9)),
        ],
        transferred: const {'a': true},
      );

      await tester.tap(find.text('Noch offen'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsOneWidget);
      expect(find.text('Fr, 07.11.2025'), findsOneWidget);
    });

    testWidgets('"Noch offen" leaves freediving out', (tester) async {
      // Apnoe goes into SSI a different way, so it is not part of what
      // this list is being worked through for.
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9), type: DiveType.apnea),
          _dive('b', DateTime(2025, 11, 7, 9), type: DiveType.singleGas),
        ],
      );

      await tester.tap(find.text('Noch offen'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsOneWidget);
      expect(find.text('Fr, 07.11.2025'), findsOneWidget);
    });

    testWidgets('"Rec" shows single-gas and unnamed open circuit', (
      tester,
    ) async {
      // scuba is Garmin's fallback for an open-circuit dive whose gas setup
      // it did not name - it belongs here rather than nowhere.
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas),
          _dive('b', DateTime(2025, 11, 7, 9), type: DiveType.scuba),
          _dive('c', DateTime(2025, 11, 6, 9), type: DiveType.multiGas),
          _dive('d', DateTime(2025, 11, 5, 9), type: DiveType.apnea),
        ],
      );

      await tester.tap(find.text('Rec'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsNWidgets(2));
      expect(find.text('Sa, 08.11.2025'), findsOneWidget);
      expect(find.text('Fr, 07.11.2025'), findsOneWidget);
    });

    testWidgets('"Tech" shows multi-gas and rebreather', (tester) async {
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9), type: DiveType.multiGas),
          _dive('b', DateTime(2025, 11, 7, 9), type: DiveType.rebreather),
          _dive('c', DateTime(2025, 11, 6, 9), type: DiveType.singleGas),
        ],
      );

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsNWidgets(2));
      expect(find.text('Do, 06.11.2025'), findsNothing);
    });

    testWidgets('"Rec" and "Tech" ignore whether a dive has gone across', (
      tester,
    ) async {
      // They answer "what sort of diving was that", not "what is left to
      // do" - a transferred dive is still a Rec dive.
      await _pump(
        tester,
        dives: [_dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas)],
        transferred: const {'a': true},
      );

      await tester.tap(find.text('Rec'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsOneWidget);
    });

    testWidgets('counts a dive found in the SSI logbook as done', (
      tester,
    ) async {
      // The tick does not have to have been set by hand - a dive the
      // logbook already knows is just as done.
      await _pump(
        tester,
        dives: [_dive('a', DateTime(2023, 8, 12, 12, 54))],
        logbook: [
          SsiLoggedDive(
            dateTime: DateTime(2023, 8, 12, 12, 54),
            depthMeters: 28,
          ),
        ],
      );

      await tester.tap(find.text('Noch offen'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsNothing);
      expect(find.textContaining('Keine Tauchgänge'), findsOneWidget);
    });

    testWidgets('an empty result says so and is one tap from undone', (
      tester,
    ) async {
      await _pump(
        tester,
        dives: [_dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas)],
      );

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Keine Tauchgänge'), findsOneWidget);

      // The filter bar stays put, so getting back is one tap rather than a
      // trip out of the screen.
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();
      expect(find.byType(DiveListTile), findsOneWidget);
    });

    testWidgets('the export selection still sees every dive', (tester) async {
      // Filtering narrows what is on screen, not what the screen can do -
      // "Mehrere exportieren" would otherwise silently offer less.
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9)),
          _dive('b', DateTime(2025, 11, 7, 9)),
        ],
        transferred: const {'a': true},
      );

      await tester.tap(find.text('Noch offen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.checklist_rtl));
      await tester.pumpAndSettle();

      expect(find.text('Sa, 08.11.2025 · 1 TG'), findsOneWidget);
      expect(find.text('Fr, 07.11.2025 · 1 TG'), findsOneWidget);
    });
  });
}
