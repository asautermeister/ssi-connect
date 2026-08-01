import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ui/dive_list_tile.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

Dive _dive({double? maxDepth, Duration? duration, int diveNumberOfDay = 1}) {
  return Dive(
    id: 'a',
    dateTime: DateTime(2025, 11, 8, 8, 56),
    maxDepthMeters: maxDepth,
    avgDepthMeters: null,
    waterTemperatureCelsius: null,
    duration: duration,
    locationName: null,
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
      expect(find.text('1. TG DES TAGES'), findsOneWidget);
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
