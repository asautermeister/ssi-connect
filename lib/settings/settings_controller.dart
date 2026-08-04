import 'package:flutter/material.dart';

import 'settings_repository.dart';

/// The user's app-wide preferences.
///
/// Today that is the theme; the language selection will join it here rather
/// than getting a controller of its own - they share a screen, a store and
/// a lifetime, and splitting them would mean two of everything for two
/// values.
class SettingsController extends ChangeNotifier {
  SettingsController({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository();

  final SettingsRepository _repository;

  /// Follows the device until the user says otherwise. That is the right
  /// default for a tablet that sits on a boat in the sun and in a dim
  /// living room on the same day.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// null means "follow the device". Kept as null rather than resolving it
  /// to a concrete language here, so the app keeps following along when the
  /// device language changes.
  Locale? _locale;
  Locale? get locale => _locale;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _themeMode = await _repository.loadThemeMode() ?? ThemeMode.system;
    _locale = await _repository.loadLocale();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _repository.saveThemeMode(mode);
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale?.languageCode == _locale?.languageCode) return;
    _locale = locale;
    notifyListeners();
    await _repository.saveLocale(locale);
  }
}
