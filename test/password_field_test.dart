import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';
import 'package:ssi_connect/ui/widgets/password_field.dart';

Future<TextEditingController> _pump(WidgetTester tester) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      theme: AppTheme.light(),
      home: Scaffold(
        body: PasswordField(controller: controller, label: 'Passwort'),
      ),
    ),
  );
  // The localisation delegate resolves asynchronously, so after a single
  // frame the tree is still empty.
  await tester.pumpAndSettle();
  return controller;
}

bool _isObscured(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).obscureText;

void main() {
  group('PasswordField', () {
    testWidgets('starts hidden', (tester) async {
      await _pump(tester);

      expect(_isObscured(tester), isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('the eye reveals what was typed, and hides it again', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await tester.enterText(find.byType(TextField), 'geheim');

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(_isObscured(tester), isFalse);
      // The text itself is unchanged by any of this - only its rendering.
      expect(controller.text, 'geheim');

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(_isObscured(tester), isTrue);
      expect(controller.text, 'geheim');
    });

    testWidgets('the tooltip says what pressing it does', (tester) async {
      // Not what the state is: "verborgen" would leave open what the
      // button changes, which is what a screen reader reads out.
      await _pump(tester);

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).tooltip,
        'Passwort anzeigen',
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).tooltip,
        'Passwort verbergen',
      );
    });

    testWidgets('submitting from the keyboard still reaches the caller', (
      tester,
    ) async {
      var submitted = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppStrings.supportedLocales,
          theme: AppTheme.light(),
          home: Scaffold(
            body: PasswordField(
              controller: controller,
              label: 'Passwort',
              onSubmitted: () => submitted++,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'geheim');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, 1);
    });
  });
}
