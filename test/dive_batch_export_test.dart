import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_qr_payload_builder.dart';
import 'package:ssi_connect/ui/dive_export_selection_screen.dart';
import 'package:ssi_connect/ui/dive_qr_batch_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

Dive _dive(
  String id,
  DateTime at, {
  double? depth = 28,
  Duration? duration = const Duration(minutes: 54),
}) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: depth,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: duration,
  locationName: null,
);

Future<void> _pumpSelection(
  WidgetTester tester,
  List<Dive> dives, {
  SsiBuddyCode? diver,
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: DiveExportSelectionScreen(
        dives: assignDiveNumbersOfDay(dives),
        diver: diver,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SsiQrPayloadBuilder.unexportableReason', () {
    test('agrees with what build throws on', () {
      final complete = _dive('a', DateTime(2025, 11, 8));
      final noDepth = _dive('b', DateTime(2025, 11, 8), depth: null);
      final noDuration = _dive('c', DateTime(2025, 11, 8), duration: null);

      expect(SsiQrPayloadBuilder.unexportableReason(complete), isNull);
      expect(() => SsiQrPayloadBuilder.build(complete), returnsNormally);

      for (final dive in [noDepth, noDuration]) {
        final reason = SsiQrPayloadBuilder.unexportableReason(dive);
        expect(reason, isNotNull);
        // The list and the builder must not disagree about which dives can
        // be exported, so both read the same answer.
        expect(
          () => SsiQrPayloadBuilder.build(dive),
          throwsA(
            isA<ArgumentError>().having((e) => e.message, 'message', reason),
          ),
        );
      }
    });
  });

  group('DiveExportSelectionScreen', () {
    testWidgets('groups dives by day and counts them', (tester) async {
      await _pumpSelection(tester, [
        _dive('a', DateTime(2025, 11, 8, 9)),
        _dive('b', DateTime(2025, 11, 8, 13)),
        _dive('c', DateTime(2025, 11, 7, 10)),
      ]);

      expect(find.text('Sa, 08.11.2025 · 2 TG'), findsOneWidget);
      expect(find.text('Fr, 07.11.2025 · 1 TG'), findsOneWidget);
    });

    testWidgets('the button stays disabled until something is picked', (
      tester,
    ) async {
      await _pumpSelection(tester, [_dive('a', DateTime(2025, 11, 8, 9))]);

      expect(find.text('Tauchgänge auswählen'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('1 Tauchgang als QR-Code'), findsOneWidget);
    });

    testWidgets('a whole dive day is one tap', (tester) async {
      await _pumpSelection(tester, [
        _dive('a', DateTime(2025, 11, 8, 9)),
        _dive('b', DateTime(2025, 11, 8, 13)),
        _dive('c', DateTime(2025, 11, 8, 16)),
        _dive('d', DateTime(2025, 11, 7, 10)),
      ]);

      await tester.tap(find.text('Ganzer Tauchtag').first);
      await tester.pumpAndSettle();

      // Only that day - the day before stays untouched.
      expect(find.text('3 Tauchgänge als QR-Codes'), findsOneWidget);
      expect(find.text('Keinen'), findsOneWidget);

      await tester.tap(find.text('Keinen'));
      await tester.pumpAndSettle();

      expect(find.text('Tauchgänge auswählen'), findsOneWidget);
    });

    testWidgets('a dive without a depth is shown but cannot be picked', (
      tester,
    ) async {
      await _pumpSelection(tester, [
        _dive('a', DateTime(2025, 11, 8, 9)),
        _dive('b', DateTime(2025, 11, 8, 13), depth: null),
      ]);

      // Listed rather than hidden: a dive missing from the list looks like
      // one that was already exported.
      expect(find.textContaining('keine maximale Tiefe'), findsOneWidget);

      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.where((b) => b.onChanged == null), hasLength(1));

      // "Ganzer Tauchtag" must not pick it up either.
      await tester.tap(find.text('Ganzer Tauchtag'));
      await tester.pumpAndSettle();
      expect(find.text('1 Tauchgang als QR-Code'), findsOneWidget);
    });

    testWidgets('hands the dives on oldest first', (tester) async {
      // The picking list runs newest first; the scanning order has to be
      // the order they were dived, or the SSI logbook ends up reversed.
      await _pumpSelection(tester, [
        _dive('neu', DateTime(2025, 11, 8, 9)),
        _dive('alt', DateTime(2025, 11, 6, 9)),
      ]);

      for (final box in find.byType(Checkbox).evaluate()) {
        await tester.tap(find.byWidget(box.widget));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final batch = tester.widget<DiveQrBatchScreen>(
        find.byType(DiveQrBatchScreen),
      );
      expect(batch.dives.map((d) => d.id), ['alt', 'neu']);
    });
  });

  group('DiveQrBatchScreen', () {
    Future<void> pump(WidgetTester tester, List<Dive> dives) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DiveQrBatchScreen(dives: dives),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('counts the codes and steps through them', (tester) async {
      await pump(tester, [
        _dive('a', DateTime(2025, 11, 6, 9)),
        _dive('b', DateTime(2025, 11, 7, 9)),
      ]);

      expect(find.text('1 von 2'), findsOneWidget);
      // Nowhere to go back to on the first code.
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );

      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      expect(find.text('2 von 2'), findsOneWidget);
      // The last code ends the run instead of dead-ending.
      expect(find.text('Weiter'), findsNothing);
      expect(find.text('Fertig'), findsOneWidget);

      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();
      expect(find.text('1 von 2'), findsOneWidget);
    });

    testWidgets('names the dive above each code', (tester) async {
      await pump(
        tester,
        assignDiveNumbersOfDay([_dive('a', DateTime(2025, 11, 8, 9))]),
      );

      // So the person scanning can tell which dive is on screen.
      expect(
        find.textContaining('Sa, 08.11.2025 · 1. TG · 28,0 m · 54 min'),
        findsOneWidget,
      );
    });
  });
}
