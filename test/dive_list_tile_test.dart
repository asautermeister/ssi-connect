import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';
import 'package:ssi_connect/ui/dive_list_tile.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';
import 'package:ssi_connect/ui/widgets/dive_type_icon.dart';
import 'package:ssi_connect/ui/widgets/stat_tile.dart';
import 'support/exported_dives.dart';
import 'package:provider/provider.dart';

Dive _dive({
  double? maxDepth,
  Duration? duration,
  int diveNumberOfDay = 1,
  int? diveNumber,
  DiveType type = DiveType.scuba,
}) {
  return Dive(
    id: 'a',
    dateTime: DateTime(2025, 11, 8, 8, 56),
    maxDepthMeters: maxDepth,
    avgDepthMeters: null,
    waterTemperatureCelsius: null,
    duration: duration,
    locationName: null,
    diveNumber: diveNumber,
    type: type,
    diveNumberOfDay: diveNumberOfDay,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [exportedDivesProvider()],
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
        home: Scaffold(body: child),
      ),
    ),
  );
  // The texts are loaded by a delegate, so the first frame is still empty.
  await tester.pumpAndSettle();
}

void main() {
  group('DiveListTile', () {
    testWidgets('shows date, depth and dive-of-day', (tester) async {
      await _pump(
        tester,
        DiveListTile(
          dive: _dive(maxDepth: 44, duration: const Duration(minutes: 92)),
        ),
      );

      expect(find.text('Sa, 08.11.2025'), findsOneWidget);
      expect(find.text('44,0'), findsOneWidget);
      expect(find.text('MAX. TIEFE'), findsOneWidget);
      expect(find.textContaining('92 min'), findsOneWidget);
      expect(find.textContaining('1. TG'), findsOneWidget);
    });

    testWidgets('shows a type badge and names the type in text', (
      tester,
    ) async {
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 11.5, type: DiveType.apnea)),
      );

      final badge = tester.widget<DiveTypeIcon>(find.byType(DiveTypeIcon));
      expect(badge.type, DiveType.apnea);
      // The label is written out too, so the drawing never carries the
      // meaning on its own.
      expect(find.textContaining('Apnoe'), findsOneWidget);
    });

    testWidgets('shows the running dive number when the source has one', (
      tester,
    ) async {
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 20, diveNumber: 142)),
      );

      expect(find.text('# 142'), findsOneWidget);
    });

    testWidgets('places the number above the badge on the left edge', (
      tester,
    ) async {
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 20, diveNumber: 142)),
      );

      final number = tester.getRect(find.text('# 142'));
      final badge = tester.getRect(find.byType(DiveTypeIcon));
      final date = tester.getRect(find.text('Sa, 08.11.2025'));

      expect(number.bottom, lessThanOrEqualTo(badge.top));
      expect(badge.right, lessThanOrEqualTo(date.left));
    });

    testWidgets('omits the running number when the source has none', (
      tester,
    ) async {
      await _pump(tester, DiveListTile(dive: _dive(maxDepth: 20)));

      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('renders every dive type without error', (tester) async {
      for (final type in DiveType.values) {
        await _pump(
          tester,
          DiveListTile(dive: _dive(maxDepth: 20, type: type)),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders without a depth, showing the placeholder', (
      tester,
    ) async {
      await _pump(tester, DiveListTile(dive: _dive()));

      expect(find.text('–'), findsOneWidget);
      // Nothing to draw, so no bar - and no bare axis either.
      expect(find.byType(DepthMeter), findsNothing);
    });

    testWidgets('the depth bar reads against a fixed scale', (tester) async {
      // Fixed, so the same dive is the same length whatever else is
      // loaded. The ends are named; between them the ticks are the scale.
      await _pump(tester, DiveListTile(dive: _dive(maxDepth: 20)));

      expect(tester.widget<DepthMeter>(find.byType(DepthMeter)).value, 20);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('45 m'), findsOneWidget);
    });

    testWidgets('a dive past the scale still draws its own depth', (
      tester,
    ) async {
      // The bar fills and the arrow says "further than this"; the value is
      // passed through untouched, so nothing downstream is told it was 45.
      await _pump(tester, DiveListTile(dive: _dive(maxDepth: 58)));

      expect(tester.widget<DepthMeter>(find.byType(DepthMeter)).value, 58);
    });
  });
}
