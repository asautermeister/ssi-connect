import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/settings/settings_controller.dart';
import 'package:ssi_connect/settings/settings_repository.dart';
import 'package:ssi_connect/ui/settings_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
class _InMemoryRepository extends SettingsRepository {
  _InMemoryRepository([this.stored]);

  ThemeMode? stored;

  @override
  Future<ThemeMode?> loadThemeMode() async => stored;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async => stored = mode;
}

Future<SettingsController> _pump(
  WidgetTester tester, {
  ThemeMode? stored,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = SettingsController(
    repository: _InMemoryRepository(stored),
  );
  await controller.loadFromStorage();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
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
        repository: _InMemoryRepository(ThemeMode.dark),
      );
      await controller.loadFromStorage();

      expect(controller.themeMode, ThemeMode.dark);
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

      for (final label in const ['Wie das Gerät', 'Hell', 'Dunkel']) {
        expect(find.text(label), findsOneWidget);
      }
      // Exactly one tick, on the default.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('picking a mode stores it', (tester) async {
      final controller = await _pump(tester);

      await tester.tap(find.text('Dunkel'));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('says why the QR code stays light', (tester) async {
      // Otherwise a dark-mode user would reasonably expect the code to
      // follow along, and wonder whether the light one is a bug.
      await _pump(tester, stored: ThemeMode.dark);

      expect(find.textContaining('QR-Code bleibt immer hell'), findsOneWidget);
    });
  });
}
