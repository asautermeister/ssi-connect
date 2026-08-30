import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ui/dive_detail_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

/// Ras il-Hobz, from the SSI logbook.
const _site = DiveSite(
  siteId: '2595',
  name: 'Ras il-Hobz',
  latitude: 36.0166,
  longitude: 14.2798,
);

/// The same place again, a few hundred metres along the coast - close
/// enough to be in reach, which is the case the app must not be silent
/// about.
const _neighbour = DiveSite(
  siteId: '2596',
  name: 'Xatt l-Ahmar',
  latitude: 36.0186,
  longitude: 14.2798,
);

Dive _diveAt({double? latitude, double? longitude}) => Dive(
  id: 'a',
  dateTime: DateTime(2025, 11, 8, 9),
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
  latitude: latitude,
  longitude: longitude,
);

class _Sites extends DiveSiteRepository {
  _Sites(this.stored);

  final List<DiveSite> stored;

  @override
  Future<List<DiveSite>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<DiveSite> sites) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required Dive dive,
  List<DiveSite> known = const [_site],
}) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final sites = DiveSitesController(repository: _Sites(known));
  await sites.loadFromStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: sites)],
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
        home: DiveDetailScreen(dive: dive),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the dive site of a dive', () {
    testWidgets('a known site at the position is taken, not offered', (
      tester,
    ) async {
      await _pump(tester, dive: _diveAt(latitude: 36.0167, longitude: 14.2799));

      expect(find.text('Ras il-Hobz'), findsOneWidget);
      expect(find.textContaining('site:2595'), findsOneWidget);
      // Said outright, so a site the app filled in cannot be mistaken for
      // one the user picked.
      expect(
        find.text('Tauchplatz automatisch übernommen – Zuordnung ändern'),
        findsOneWidget,
      );
      expect(find.text('Tauchplatz zuordnen'), findsNothing);
    });

    testWidgets('a removed site stays removed', (tester) async {
      // The one way automatic matching could become a nuisance: taking the
      // site straight back the moment it is taken away.
      await _pump(tester, dive: _diveAt(latitude: 36.0167, longitude: 14.2799));

      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();

      expect(find.text('Ras il-Hobz'), findsNothing);
      expect(find.text('Noch kein Tauchplatz zugeordnet'), findsOneWidget);
      expect(find.text('Tauchplatz zuordnen'), findsOneWidget);
    });

    testWidgets('anything else in reach is still pointed out', (tester) async {
      // The nearest is taken, but it is not automatically the right one -
      // sites sit close together on the same stretch of coast.
      await _pump(
        tester,
        dive: _diveAt(latitude: 36.0167, longitude: 14.2799),
        known: const [_site, _neighbour],
      );

      expect(find.text('Ras il-Hobz'), findsOneWidget);
      expect(find.text('1 weiterer Platz in der Nähe'), findsOneWidget);
    });

    testWidgets('nothing is invented for a dive out of reach', (tester) async {
      await _pump(tester, dive: _diveAt(latitude: 47.5, longitude: 9.1));

      expect(find.text('Ras il-Hobz'), findsNothing);
      expect(find.text('Noch kein Tauchplatz zugeordnet'), findsOneWidget);
      expect(find.text('Tauchplatz zuordnen'), findsOneWidget);
    });

    testWidgets('a dive without a position says why there is no site', (
      tester,
    ) async {
      await _pump(tester, dive: _diveAt());

      expect(find.text('Noch kein Tauchplatz zugeordnet'), findsOneWidget);
      expect(find.textContaining('Ohne Position'), findsOneWidget);
    });
  });
}
