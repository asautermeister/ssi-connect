import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ui/dive_list_tile.dart';
import 'package:ssi_connect/ui/qr_display_screen.dart';
import 'package:ssi_connect/ui/qr_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

import 'support/exported_dives.dart';

Dive _dive(String id) => Dive(
  id: id,
  dateTime: DateTime(2025, 11, 8, 9),
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
);

Future<ExportedDivesController> _pump(
  WidgetTester tester,
  Widget child, {
  Map<String, bool> exported = const {},
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = ExportedDivesController(
    repository: InMemoryExportedDives(exported),
  );
  await controller.loadFromStorage();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
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
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('ExportedDivesController', () {
    test('remembers a tick and writes it through', () async {
      final repository = InMemoryExportedDives();
      final controller = ExportedDivesController(repository: repository);
      await controller.loadFromStorage();

      await controller.setTransferred('a1', true);

      expect(controller.isTransferred(_dive('a1')), isTrue);
      expect(repository.stored, {'a1': true});
    });

    test('can be taken back', () async {
      // Ticking the wrong dive must not need a trip through the settings to
      // undo.
      final repository = InMemoryExportedDives({'a1': true});
      final controller = ExportedDivesController(repository: repository);
      await controller.loadFromStorage();

      await controller.setTransferred('a1', false);

      expect(controller.isTransferred(_dive('a1')), isFalse);
      expect(repository.stored, {'a1': false});
    });

    test('setting what is already set changes nothing', () async {
      final controller = ExportedDivesController(
        repository: InMemoryExportedDives({'a1': true}),
      );
      await controller.loadFromStorage();

      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.setTransferred('a1', true);

      expect(notifications, 0);
    });

    test('survives a restart', () async {
      final repository = InMemoryExportedDives();
      final first = ExportedDivesController(repository: repository);
      await first.loadFromStorage();
      await first.setTransferred('a1', true);

      final second = ExportedDivesController(repository: repository);
      await second.loadFromStorage();

      expect(second.isTransferred(_dive('a1')), isTrue);
    });
  });

  group('the tick on the QR screen', () {
    testWidgets('is off until it is set, and sticks', (tester) async {
      final controller = await _pump(tester, QrScreen(dive: _dive('a1')));

      expect(controller.isTransferred(_dive('a1')), isFalse);

      await tester.tap(find.text('In SSI übernommen'));
      await tester.pumpAndSettle();

      expect(controller.isTransferred(_dive('a1')), isTrue);
    });

    testWidgets('showing a code does not tick it', (tester) async {
      // A displayed QR code is no proof that anyone scanned it, and a dive
      // that ticks itself is exactly the one that would then be skipped.
      final controller = await _pump(tester, QrScreen(dive: _dive('a1')));

      expect(controller.isTransferred(_dive('a1')), isFalse);
      expect(find.byType(DiveTransferredCheckbox), findsOneWidget);
    });
  });

  group('the tick in the dive list', () {
    testWidgets('appears only for a dive that went across', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            DiveListTile(dive: _dive('a1')),
            DiveListTile(dive: _dive('a2')),
          ],
        ),
        exported: const {'a1': true},
      );

      expect(find.byType(DiveTransferredMark), findsOneWidget);
    });

    testWidgets('follows the tick without a reload', (tester) async {
      final controller = await _pump(tester, DiveListTile(dive: _dive('a1')));

      expect(find.byType(DiveTransferredMark), findsNothing);

      await controller.setTransferred('a1', true);
      await tester.pumpAndSettle();

      expect(find.byType(DiveTransferredMark), findsOneWidget);
    });
  });
}
