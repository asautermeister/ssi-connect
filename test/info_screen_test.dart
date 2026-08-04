import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/app_info.dart';
import 'package:ssi_connect/ui/developer_mode.dart';
import 'package:ssi_connect/ui/info_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => DeveloperMode(),
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
        home: const InfoScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeveloperMode', () {
    test('unlocks on the third tap, not before', () {
      final mode = DeveloperMode();

      expect(mode.registerVersionTap(), isFalse);
      expect(mode.enabled, isFalse);
      expect(mode.registerVersionTap(), isFalse);
      expect(mode.enabled, isFalse);

      expect(mode.registerVersionTap(), isTrue);
      expect(mode.enabled, isTrue);
    });

    test('counts down only once tapping has started', () {
      final mode = DeveloperMode();

      // Nothing tapped: no hint, so the version doesn't advertise itself.
      expect(mode.tapsRemaining, 0);
      mode.registerVersionTap();
      expect(mode.tapsRemaining, 2);
      mode.registerVersionTap();
      expect(mode.tapsRemaining, 1);
    });

    test('further taps do nothing once unlocked', () {
      final mode = DeveloperMode()
        ..registerVersionTap()
        ..registerVersionTap()
        ..registerVersionTap();

      expect(mode.registerVersionTap(), isFalse);
      expect(mode.enabled, isTrue);
      expect(mode.tapsRemaining, 0);
    });
  });

  group('InfoScreen', () {
    testWidgets('shows the version and the repository', (tester) async {
      await _pump(tester);

      expect(find.text('Version ${AppInfo.version}'), findsOneWidget);
      expect(find.text(AppInfo.repositoryUrl), findsOneWidget);
      expect(find.text('Open-Source-Lizenzen'), findsOneWidget);
    });

    testWidgets('states what it is not affiliated with', (tester) async {
      await _pump(tester);

      expect(
        find.textContaining('keiner Verbindung zu Garmin'),
        findsOneWidget,
      );
      expect(find.textContaining('kein Tauchcomputer'), findsOneWidget);
    });

    testWidgets('hides the diagnostic tools until the version is tapped', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('API-Protokoll'), findsNothing);
      expect(find.text('SSI-Code analysieren'), findsNothing);

      await tester.tap(find.text('SSI Connect'));
      await tester.pump();
      expect(find.text('API-Protokoll'), findsNothing);
      // The countdown appears only after the first tap, so an accidental
      // tap doesn't reveal that anything is hidden.
      expect(find.text('Noch 2× tippen'), findsOneWidget);

      await tester.tap(find.text('SSI Connect'));
      await tester.pump();
      await tester.tap(find.text('SSI Connect'));
      await tester.pumpAndSettle();

      expect(find.text('API-Protokoll'), findsOneWidget);
      expect(find.text('SSI-Code analysieren'), findsOneWidget);
    });
  });
}
