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

/// Opens the filter row. It starts closed, so every chip tap needs this
/// first - which is the point of the funnel, and worth stating once here
/// rather than looking like ceremony in every test.
Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.filter_list));
  await tester.pumpAndSettle();
}

void main() {
  group('the filter on the dive list', () {
    testWidgets('is out of the way until the funnel is tapped', (tester) async {
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9)),
          _dive('b', DateTime(2025, 11, 7, 9)),
        ],
        transferred: const {'a': true},
      );

      // The row costs height a phone hasn't got to spare, and the list is
      // what one comes here for. Nothing is filtered meanwhile.
      expect(find.text('Alle'), findsNothing);
      expect(find.byType(DiveListTile), findsNWidgets(2));

      await _openFilters(tester);
      expect(find.text('Alle'), findsOneWidget);
      expect(find.text('Noch offen'), findsOneWidget);
      expect(find.byType(DiveListTile), findsNWidgets(2));

      // And it closes again on the same button.
      await _openFilters(tester);
      expect(find.text('Alle'), findsNothing);
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

      await _openFilters(tester);
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

      await _openFilters(tester);
      await tester.tap(find.text('Noch offen'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsOneWidget);
      expect(find.text('Fr, 07.11.2025'), findsOneWidget);
    });

    testWidgets('"Scuba" is everything except freediving', (tester) async {
      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas),
          _dive('b', DateTime(2025, 11, 7, 9), type: DiveType.rebreather),
          _dive('c', DateTime(2025, 11, 6, 9), type: DiveType.scuba),
          _dive('d', DateTime(2025, 11, 5, 9), type: DiveType.apnea),
        ],
        // Whether a dive has gone across is not the question here.
        transferred: const {'a': true},
      );

      await _openFilters(tester);
      await tester.tap(find.text('Scuba'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsNWidgets(3));
      expect(find.text('Mi, 05.11.2025'), findsNothing);
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

      await _openFilters(tester);
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

      await _openFilters(tester);
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

      await _openFilters(tester);
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

      await _openFilters(tester);
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

      await _openFilters(tester);
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Keine Tauchgänge'), findsOneWidget);

      // The filter row stays put, so getting back is one tap rather than a
      // trip out of the screen.
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();
      expect(find.byType(DiveListTile), findsOneWidget);
    });

    testWidgets('a closed row with a filter on it is marked', (tester) async {
      // The one thing hiding the row could get wrong: a narrowed list
      // looks exactly like a short one, and the control that would explain
      // it is off screen. So the funnel carries a dot.
      Finder dot() => find.descendant(
        of: find.byType(Badge),
        matching: find.byIcon(Icons.filter_list),
      );
      bool dotVisible() =>
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible;

      await _pump(
        tester,
        dives: [
          _dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas),
          _dive('b', DateTime(2025, 11, 7, 9), type: DiveType.multiGas),
        ],
      );

      expect(dot(), findsOneWidget);
      expect(dotVisible(), isFalse, reason: 'nothing is filtered yet');

      await _openFilters(tester);
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      // Still open, so the chips say it themselves.
      expect(dotVisible(), isFalse);

      await _openFilters(tester);
      expect(find.text('Tech'), findsNothing);
      expect(find.byType(DiveListTile), findsOneWidget);
      expect(dotVisible(), isTrue, reason: 'the list is still narrowed');
    });

    testWidgets('an empty result offers the way out on its own', (
      tester,
    ) async {
      // With the chips hidden there is nothing above the empty list to tap,
      // so the empty state has to carry the way back itself.
      await _pump(
        tester,
        dives: [_dive('a', DateTime(2025, 11, 8, 9), type: DiveType.singleGas)],
      );

      await _openFilters(tester);
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      await _openFilters(tester);

      expect(find.textContaining('Keine Tauchgänge'), findsOneWidget);
      await tester.tap(find.text('Alle anzeigen'));
      await tester.pumpAndSettle();

      expect(find.byType(DiveListTile), findsOneWidget);
    });
  });
}
