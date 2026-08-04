import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_cache_repository.dart';
import 'package:ssi_connect/dives/dive_loader.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ui/all_dives_screen.dart';
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

GarminAccount _account(String name) => GarminAccount(
  id: name,
  email: '$name@example.com',
  displayName: name,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
);

Dive _dive(String id, DateTime at) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
);

/// A logbook of [total] dives, one per day counting backwards, served in
/// pages of [divePageSize] the way Garmin does.
DiveFetcher _paged(int total, {List<int>? requestedStarts}) =>
    (account, {int start = 0}) async {
      requestedStarts?.add(start);
      return [
        for (var i = start; i < start + divePageSize && i < total; i++)
          _dive('d$i', DateTime(2025, 11, 8).subtract(Duration(days: i))),
      ];
    };

void main() {
  group('RecentDivesController paging', () {
    test('a full first page leaves the door open for more', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');

      await controller.load(accounts: [account], fetch: _paged(120));

      expect(controller.forAccount('a').dives, hasLength(divePageSize));
      expect(controller.hasMore, isTrue);
    });

    test('a short first page means there is nothing older', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());

      await controller.load(accounts: [_account('a')], fetch: _paged(3));

      expect(controller.hasMore, isFalse);
    });

    test(
      'loading more appends the next page and asks from the right offset',
      () async {
        final controller = RecentDivesController(cache: _InMemoryCache());
        final account = _account('a');
        final starts = <int>[];
        final fetch = _paged(120, requestedStarts: starts);

        await controller.load(accounts: [account], fetch: fetch);
        await controller.loadMore(accounts: [account], fetch: fetch);

        expect(starts, [0, divePageSize]);
        expect(controller.forAccount('a').dives, hasLength(divePageSize * 2));
        expect(controller.hasMore, isTrue);

        await controller.loadMore(accounts: [account], fetch: fetch);

        expect(starts, [0, divePageSize, divePageSize * 2]);
        expect(controller.forAccount('a').dives, hasLength(120));
        // The last page was short, so there is nothing left to ask for.
        expect(controller.hasMore, isFalse);
      },
    );

    test('asking again once exhausted does not hit the network', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');
      final starts = <int>[];
      final fetch = _paged(3, requestedStarts: starts);

      await controller.load(accounts: [account], fetch: fetch);
      await controller.loadMore(accounts: [account], fetch: fetch);

      expect(starts, [0]);
    });

    test('a dive seen in two pages is kept once', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');
      var call = 0;
      Future<List<Dive>> fetch(GarminAccount _, {int start = 0}) async {
        call++;
        // Both pages full, but the second repeats one dive from the first -
        // what happens when something is logged while paging.
        return [
          for (var i = 0; i < divePageSize; i++)
            _dive(
              'd${call == 1 ? i : i + divePageSize - 1}',
              DateTime(
                2025,
                11,
                8,
              ).subtract(Duration(days: call == 1 ? i : i + divePageSize - 1)),
            ),
        ];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.loadMore(accounts: [account], fetch: fetch);

      final ids = controller.forAccount('a').dives.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(divePageSize * 2 - 1));
    });

    test('re-numbers a dive day split across a page boundary', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');
      var call = 0;
      // Page 1 ends with the second dive of 6 Nov, page 2 starts with the
      // first - numbered per page, both would come out as "1. TG".
      Future<List<Dive>> fetch(GarminAccount _, {int start = 0}) async {
        call++;
        return call == 1
            ? [
                for (var i = 0; i < divePageSize - 1; i++)
                  _dive('x$i', DateTime(2025, 11, 8, 9).add(Duration(days: i))),
                _dive('spaet', DateTime(2025, 11, 6, 14)),
              ]
            : [_dive('frueh', DateTime(2025, 11, 6, 9))];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.loadMore(accounts: [account], fetch: fetch);

      final byId = {
        for (final dive in controller.forAccount('a').dives) dive.id: dive,
      };
      expect(byId['frueh']!.diveNumberOfDay, 1);
      expect(byId['spaet']!.diveNumberOfDay, 2);
    });

    test('a failed page keeps what is on screen', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');
      var call = 0;
      Future<List<Dive>> fetch(GarminAccount _, {int start = 0}) async {
        if (++call > 1) {
          throw GarminAuthException(
            GarminAuthErrorType.offline,
            'Keine Internetverbindung.',
          );
        }
        return [
          for (var i = 0; i < divePageSize; i++)
            _dive('d$i', DateTime(2025, 11, 8).subtract(Duration(days: i))),
        ];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.loadMore(accounts: [account], fetch: fetch);

      expect(controller.forAccount('a').dives, hasLength(divePageSize));
      expect(controller.loadMoreError, isA<GarminAuthException>());
      // Still worth another try - the failure says nothing about whether
      // older dives exist.
      expect(controller.hasMore, isTrue);
    });

    test('a refresh starts the paging over', () async {
      final controller = RecentDivesController(cache: _InMemoryCache());
      final account = _account('a');
      final starts = <int>[];
      final fetch = _paged(200, requestedStarts: starts);

      await controller.load(accounts: [account], fetch: fetch);
      await controller.loadMore(accounts: [account], fetch: fetch);
      await controller.load(accounts: [account], fetch: fetch, force: true);

      expect(starts, [0, divePageSize, 0]);
      expect(controller.forAccount('a').dives, hasLength(divePageSize));
    });
  });

  group('AllDivesScreen', () {
    Future<RecentDivesController> pump(
      WidgetTester tester, {
      required List<GarminAccount> accounts,
      required DiveFetcher fetch,
    }) async {
      tester.view.physicalSize = const Size(1100, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final accountsController = AccountsController(
        repository: _InMemoryAccounts(accounts),
      );
      final recent = RecentDivesController(cache: _InMemoryCache());
      await accountsController.loadFromStorage();
      await recent.load(accounts: accounts, fetch: fetch);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: accountsController),
            ChangeNotifierProvider.value(value: recent),
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
            home: const AllDivesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return recent;
    }

    testWidgets('opens on what is already loaded and counts it', (
      tester,
    ) async {
      await pump(tester, accounts: [_account('a')], fetch: _paged(3));

      expect(find.text('3 Tauchgänge geladen'), findsOneWidget);
      // Nothing older to ask for, so say that instead of offering a button
      // that would come back empty.
      expect(find.text('Ältere Tauchgänge laden'), findsNothing);
      expect(
        find.text('Keine älteren Tauchgänge mehr bei Garmin.'),
        findsOneWidget,
      );
    });

    testWidgets('the button fetches the next page and grows the list', (
      tester,
    ) async {
      final controller = await pump(
        tester,
        accounts: [_account('a')],
        fetch: _paged(divePageSize + 4),
      );

      // With a full page loaded the foot of the list is off screen, so it
      // has to be scrolled to before it exists as an element at all.
      await tester.scrollUntilVisible(
        find.text('Ältere Tauchgänge laden'),
        300,
      );
      expect(find.text('$divePageSize Tauchgänge geladen'), findsOneWidget);

      await tester.tap(find.text('Ältere Tauchgänge laden'));
      await tester.pumpAndSettle();

      expect(controller.forAccount('a').dives, hasLength(divePageSize + 4));
      expect(controller.hasMore, isFalse);
    });

    testWidgets('a failed page says so and offers another go', (tester) async {
      var call = 0;
      Future<List<Dive>> fetch(GarminAccount _, {int start = 0}) async {
        if (++call > 1) {
          throw GarminAuthException(
            GarminAuthErrorType.offline,
            'Keine Internetverbindung.',
          );
        }
        return [
          for (var i = 0; i < divePageSize; i++)
            _dive('d$i', DateTime(2025, 11, 8).subtract(Duration(days: i))),
        ];
      }

      await pump(tester, accounts: [_account('a')], fetch: fetch);

      await tester.scrollUntilVisible(
        find.text('Ältere Tauchgänge laden'),
        300,
      );
      await tester.tap(find.text('Ältere Tauchgänge laden'));
      await tester.pumpAndSettle();

      expect(find.text('Keine Internetverbindung.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });
  });
}
