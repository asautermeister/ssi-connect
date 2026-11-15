import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:ssi_connect/ui/garmin_key_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

class _NoAccounts extends AccountRepository {
  @override
  Future<List<GarminAccount>> loadAll() async => const [];

  @override
  Future<void> save(GarminAccount account) async {}

  @override
  Future<void> remove(String accountId) async {}
}

const _key = 'GCDC_39f38091-fa09.b75c260f-5f65.poIqF07CApIq.1754132331';

Future<void> _pump(WidgetTester tester, GarminKeyScreen screen) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AccountsController(repository: _NoAccounts()),
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

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  group('GarminKeyScreen', () {
    testWidgets('a new account brings the name typed on the sign-in screen', (
      tester,
    ) async {
      // Seen on a device: the name was dropped on the way to the key, and
      // the entry was called by Garmin's internal handle instead.
      await _pump(tester, const GarminKeyScreen(initialName: 'Andreas'));

      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        'Andreas',
      );
    });

    testWidgets('a new account is not made without a name', (tester) async {
      await _pump(tester, const GarminKeyScreen());

      await tester.enterText(_field('Schlüssel'), _key);
      await tester.ensureVisible(find.text('Prüfen und speichern'));
      await tester.tap(find.text('Prüfen und speichern'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bitte einen Namen eingeben'), findsOneWidget);
    });

    testWidgets('an existing account keeps its name and is not asked', (
      tester,
    ) async {
      await _pump(
        tester,
        const GarminKeyScreen(
          account: GarminAccount(
            id: 'a',
            email: 'a@example.com',
            displayName: 'Andreas',
            session: GarminSession.none(),
          ),
        ),
      );

      expect(_field('Name'), findsNothing);
    });
  });
}
