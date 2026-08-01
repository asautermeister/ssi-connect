import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';
import 'package:ssi_connect/ui/dive_list_tile.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';
import 'package:ssi_connect/ui/widgets/dive_type_icon.dart';

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

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('DiveListTile', () {
    testWidgets('shows date, depth and dive-of-day', (tester) async {
      await _pump(
        tester,
        DiveListTile(
          dive: _dive(maxDepth: 44, duration: const Duration(minutes: 92)),
          maxDepthInList: 44,
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
        DiveListTile(
          dive: _dive(maxDepth: 11.5, type: DiveType.apnea),
          maxDepthInList: 11.5,
        ),
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
        DiveListTile(
          dive: _dive(maxDepth: 20, diveNumber: 142),
          maxDepthInList: 20,
        ),
      );

      expect(find.text('# 142'), findsOneWidget);
    });

    testWidgets('places the number above the badge on the left edge', (
      tester,
    ) async {
      await _pump(
        tester,
        DiveListTile(
          dive: _dive(maxDepth: 20, diveNumber: 142),
          maxDepthInList: 20,
        ),
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
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 20), maxDepthInList: 20),
      );

      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('renders every dive type without error', (tester) async {
      for (final type in DiveType.values) {
        await _pump(
          tester,
          DiveListTile(
            dive: _dive(maxDepth: 20, type: type),
            maxDepthInList: 20,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('renders without a depth, showing the placeholder', (
      tester,
    ) async {
      await _pump(tester, DiveListTile(dive: _dive(), maxDepthInList: 0));

      expect(find.text('–'), findsOneWidget);
      // No shared scale and no value, so no magnitude bar is drawn.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('draws the depth meter when a scale is available', (
      tester,
    ) async {
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 20), maxDepthInList: 40),
      );

      final meter = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(meter.value, closeTo(0.5, 0.001));
    });

    testWidgets('clamps the meter when a dive is the deepest', (tester) async {
      await _pump(
        tester,
        DiveListTile(dive: _dive(maxDepth: 40), maxDepthInList: 40),
      );

      final meter = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(meter.value, 1.0);
    });
  });
}
