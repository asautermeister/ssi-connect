import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ui/qr_display_screen.dart';
import 'package:ssi_connect/ui/qr_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';
import 'support/exported_dives.dart';
import 'package:provider/provider.dart';

Dive _dive({double? maxDepthMeters = 28, Duration? duration}) => Dive(
  id: 'a',
  dateTime: DateTime(2025, 11, 7, 10, 50),
  maxDepthMeters: maxDepthMeters,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: duration ?? const Duration(minutes: 54),
  locationName: null,
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  // Roomy viewport: the QR code alone is 380 logical pixels.
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QrScreen', () {
    testWidgets('shows the dive as a code with its values above it', (
      tester,
    ) async {
      await _pump(tester, QrScreen(dive: _dive()));

      expect(find.text('Mit SSI-App scannen'), findsOneWidget);
      // The weekday is spelled out here too, so the caption reads the
      // same way as the dive list it was opened from.
      expect(find.text('Fr, 07.11.2025 · 28,0 m · 54 min'), findsOneWidget);
      expect(find.byType(QrDisplayScreen), findsOneWidget);
    });

    testWidgets('offers no buddy picker - the format has no field for it', (
      tester,
    ) async {
      await _pump(
        tester,
        QrScreen(
          dive: _dive(),
          diver: const SsiBuddyCode(memberId: '3902893'),
        ),
      );

      // A control that looks like it does something it cannot do is worse
      // than no control; buddies live in their own list instead.
      expect(find.text('Buddies'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('says what is missing when a dive cannot be exported', (
      tester,
    ) async {
      await _pump(tester, QrScreen(dive: _dive(maxDepthMeters: null)));

      expect(find.textContaining('keine maximale Tiefe'), findsOneWidget);
      expect(find.byType(QrDisplayScreen), findsNothing);
    });
  });
}
