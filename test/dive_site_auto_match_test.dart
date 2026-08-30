import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import 'package:ssi_connect/ui/widgets/dive_map.dart';

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

/// Progressively further along the same coast: roughly 1.1 km, 2.2 km and
/// 3.3 km from the dive used below, so the cut at three has something to
/// cut.
const _acrossTheIsland = DiveSite(
  siteId: '2597',
  name: 'Mgarr ix-Xini',
  latitude: 36.0300,
  longitude: 14.2798,
);
const _fourth = DiveSite(
  siteId: '2598',
  name: 'Dwejra',
  latitude: 36.0400,
  longitude: 14.2798,
);
const _fifth = DiveSite(
  siteId: '2599',
  name: 'Fungus Rock',
  latitude: 36.0500,
  longitude: 14.2798,
);

/// About 20 km north - past the point where a site says anything about
/// where this dive was.
const _tooFarAway = DiveSite(
  siteId: '2600',
  name: 'Marsalforn',
  latitude: 36.2000,
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

      // Gone as the dive's site. It may well still be on the map as a
      // neighbour - it is a known site nearby, which is a different claim.
      expect(find.textContaining('site:2595'), findsNothing);
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

    testWidgets('the position is drawn, credited, and also written out', (
      tester,
    ) async {
      await _pump(tester, dive: _diveAt(latitude: 36.0167, longitude: 14.2799));

      expect(find.byType(DiveMap), findsOneWidget);
      // OpenStreetMap asks for the credit, and it is the honest place to
      // say who drew the map.
      expect(find.text('© OpenStreetMap-Mitwirkende'), findsOneWidget);
      // Without a network there are no tiles, so the numbers stay too.
      expect(find.text('36.01670, 14.27990'), findsOneWidget);
    });

    testWidgets('the site pin carries its name', (tester) async {
      // Roughly 200 m north of the site, so the two are far enough apart to
      // be drawn separately.
      await _pump(tester, dive: _diveAt(latitude: 36.0186, longitude: 14.2798));

      // Twice on screen: the card's heading, and the pin on the map.
      expect(find.text('Ras il-Hobz'), findsNWidgets(2));
    });

    testWidgets('one pin, not two, when the dive is on the site', (
      tester,
    ) async {
      // Fourteen metres apart - two pins would sit on top of each other and
      // say less than one.
      await _pump(tester, dive: _diveAt(latitude: 36.0167, longitude: 14.2799));

      expect(find.text('Ras il-Hobz'), findsOneWidget);
    });

    testWidgets('the nearest few other sites go on the map, up to a point', (
      tester,
    ) async {
      // Read off the map rather than off the screen: flutter_map only
      // builds the markers inside the current viewport, so at the zoom the
      // map opens on, a site a few hundred metres away is real but not yet
      // painted. What is being checked here is which sites were handed to
      // it, which is the decision this code makes.
      //
      // Nearest is Xatt l-Ahmar at about 160 m, so that is the one taken;
      // the rest line up behind it at roughly 0.4, 1.1, 2.2 and 3.3 km.
      await _pump(
        tester,
        dive: _diveAt(latitude: 36.0200, longitude: 14.2798),
        known: const [
          _site,
          _neighbour,
          _acrossTheIsland,
          _fourth,
          _fifth,
          _tooFarAway,
        ],
      );

      final map = tester.widget<DiveMap>(find.byType(DiveMap));
      final names = [for (final site in map.otherSites) site.name];

      // Three at most, nearest first, so a well-dived coast does not turn
      // the map into a field of pins. The assigned site is not among them:
      // it has its own, darker pin, and drawing it twice would say there
      // are two places there.
      expect(names, ['Ras il-Hobz', 'Mgarr ix-Xini', 'Dwejra']);
      expect(map.site?.name, 'Xatt l-Ahmar');
    });

    testWidgets('nothing beyond 15 km, even with room to spare', (
      tester,
    ) async {
      // A site that far off says nothing about where this dive was.
      await _pump(
        tester,
        dive: _diveAt(latitude: 36.0200, longitude: 14.2798),
        known: const [_neighbour, _tooFarAway],
      );

      final map = tester.widget<DiveMap>(find.byType(DiveMap));
      expect(map.otherSites, isEmpty);
    });

    testWidgets('the map can be moved, and found again', (tester) async {
      await _pump(tester, dive: _diveAt(latitude: 36.0167, longitude: 14.2799));

      final map = find.byType(DiveMap);
      final before = tester.widget<FlutterMap>(
        find.descendant(of: map, matching: find.byType(FlutterMap)),
      );
      expect(
        before.options.interactionOptions.flags & InteractiveFlag.drag,
        isNot(0),
        reason: 'a map that cannot be panned is a picture',
      );
      // Rotation stays off - disorienting on a map this small, and easy to
      // trigger by accident while pinching.
      expect(
        before.options.interactionOptions.flags & InteractiveFlag.rotate,
        0,
      );

      // Panning has no edges, so the way back has to be on screen rather
      // than only in the gesture the user just lost their place with.
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pumpAndSettle();
    });

    testWidgets('no position, no map and nothing requested', (tester) async {
      // The map is the only thing in the app that talks to a third party.
      // A dive without a fix must not produce a request at all.
      await _pump(tester, dive: _diveAt());

      expect(find.byType(DiveMap), findsNothing);
    });
  });
}
