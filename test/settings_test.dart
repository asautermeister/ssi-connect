import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/settings/settings_controller.dart';
import 'package:ssi_connect/settings/settings_repository.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_account_controller.dart';
import 'package:ssi_connect/ssi/ssi_account_repository.dart';
import 'package:ssi_connect/ssi/ssi_session.dart';
import 'package:ssi_connect/ui/settings_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
class _InMemoryRepository extends SettingsRepository {
  _InMemoryRepository([this.stored, this.storedLocale]);

  ThemeMode? stored;
  Locale? storedLocale;

  @override
  Future<ThemeMode?> loadThemeMode() async => stored;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async => stored = mode;

  @override
  Future<Locale?> loadLocale() async => storedLocale;

  @override
  Future<void> saveLocale(Locale? locale) async => storedLocale = locale;
}

/// The settings screen now also carries the SSI section, so the pump needs
/// those two controllers. Both get in-memory repositories: a real one calls
/// the keystore plugin, which has no platform under a widget test and hangs
/// the test rather than failing it.
class _NoSsiAccount extends SsiAccountRepository {
  @override
  Future<SsiSession?> load() async => null;

  @override
  Future<void> save(SsiSession session) async {}

  @override
  Future<void> clear() async {}
}

class _NoDiveSites extends DiveSiteRepository {
  @override
  Future<List<DiveSite>> loadAll() async => const [];

  @override
  Future<void> saveAll(List<DiveSite> sites) async {}
}

Future<SettingsController> _pump(
  WidgetTester tester, {
  ThemeMode? stored,
  Locale? storedLocale,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = SettingsController(
    repository: _InMemoryRepository(stored, storedLocale),
  );
  await controller.loadFromStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider(
          create: (_) => SsiAccountController(repository: _NoSsiAccount()),
        ),
        ChangeNotifierProvider(
          create: (_) => DiveSitesController(repository: _NoDiveSites()),
        ),
      ],
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
        darkTheme: AppTheme.dark(),
        themeMode: controller.themeMode,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('SettingsController', () {
    test('follows the device until the user says otherwise', () async {
      final controller = SettingsController(repository: _InMemoryRepository());

      expect(controller.themeMode, ThemeMode.system);
      await controller.loadFromStorage();

      expect(controller.themeMode, ThemeMode.system);
      expect(controller.loaded, isTrue);
    });

    test('restores a stored choice', () async {
      final controller = SettingsController(
        repository: _InMemoryRepository(ThemeMode.dark, const Locale('en')),
      );
      await controller.loadFromStorage();

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.locale?.languageCode, 'en');
    });

    test('follows the device when no language was chosen', () async {
      final controller = SettingsController(repository: _InMemoryRepository());
      await controller.loadFromStorage();

      // null, not a resolved language - so the app keeps following along
      // when the device language changes.
      expect(controller.locale, isNull);
    });

    test('writes a new choice through to storage', () async {
      final repository = _InMemoryRepository();
      final controller = SettingsController(repository: repository);
      await controller.loadFromStorage();

      await controller.setThemeMode(ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);
      expect(repository.stored, ThemeMode.light);
    });

    test('notifies once per actual change', () async {
      final controller = SettingsController(repository: _InMemoryRepository());
      await controller.loadFromStorage();

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setThemeMode(ThemeMode.dark);
      // Picking what is already picked is not a change.
      await controller.setThemeMode(ThemeMode.dark);

      expect(notifications, 1);
    });
  });

  group('SettingsScreen', () {
    testWidgets('offers all three modes and marks the current one', (
      tester,
    ) async {
      await _pump(tester);

      for (final label in const ['Hell', 'Dunkel']) {
        expect(find.text(label), findsOneWidget);
      }
      // "Wie das Gerät" is offered for both the theme and the language.
      expect(find.text('Wie das Gerät'), findsNWidgets(2));
      // One tick per section, both on the default.
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets('picking a mode stores it', (tester) async {
      final controller = await _pump(tester);

      await tester.tap(find.text('Dunkel'));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets('offers both languages, each named in itself', (tester) async {
      await _pump(tester);

      // Never translated: someone who set the app to a language they
      // cannot read still has to find their way back.
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('picking a language stores it', (tester) async {
      final controller = await _pump(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(controller.locale?.languageCode, 'en');
    });

    testWidgets('following the device is the default and is reachable', (
      tester,
    ) async {
      final controller = await _pump(tester, storedLocale: const Locale('en'));
      expect(controller.locale?.languageCode, 'en');

      // The second "Wie das Gerät" is the language one.
      await tester.tap(find.text('Wie das Gerät').last);
      await tester.pumpAndSettle();

      expect(controller.locale, isNull);
    });

    testWidgets('says why the QR code stays light', (tester) async {
      // Otherwise a dark-mode user would reasonably expect the code to
      // follow along, and wonder whether the light one is a bug.
      await _pump(tester, stored: ThemeMode.dark);

      expect(find.textContaining('QR-Code bleibt immer hell'), findsOneWidget);
    });
  });
}
