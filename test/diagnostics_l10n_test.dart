import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/ui/debug_log_screen.dart';
import 'package:ssi_connect/ui/ssi_payload_inspect_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required String language,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      theme: AppTheme.light(),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The diagnostic screens sit behind three taps on the version, so they
  // are the easiest place for an untranslated string to survive unnoticed.
  // These check the wiring rather than the wording.
  group('DebugLogScreen', () {
    testWidgets('speaks German', (tester) async {
      await _pump(tester, const DebugLogScreen(), language: 'de');

      expect(find.text('API-Protokoll'), findsOneWidget);
      expect(find.text('Aufzeichnung aktiv'), findsOneWidget);
      expect(find.text('Noch keine Aufrufe aufgezeichnet.'), findsOneWidget);
    });

    testWidgets('speaks English', (tester) async {
      await _pump(tester, const DebugLogScreen(), language: 'en');

      expect(find.text('API log'), findsOneWidget);
      expect(find.text('Recording on'), findsOneWidget);
      expect(find.text('No calls recorded yet.'), findsOneWidget);
    });
  });

  group('SsiPayloadInspectScreen', () {
    testWidgets('speaks German', (tester) async {
      await _pump(tester, const SsiPayloadInspectScreen(), language: 'de');

      expect(find.text('SSI-Code analysieren'), findsOneWidget);
      expect(find.text('QR-Code scannen'), findsOneWidget);
    });

    testWidgets('speaks English', (tester) async {
      await _pump(tester, const SsiPayloadInspectScreen(), language: 'en');

      expect(find.text('Inspect SSI code'), findsOneWidget);
      expect(find.text('Scan QR code'), findsOneWidget);
    });
  });
}
