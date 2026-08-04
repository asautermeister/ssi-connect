import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_strings.dart';

/// Persists the user's app settings.
///
/// Uses the same encrypted keystore as everything else, even though a
/// theme preference is not a secret. Adding a second storage plugin for it
/// would mean another platform dependency - and this project has already
/// been bitten twice by those. One store, one place to look.
class SettingsRepository {
  SettingsRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _themeModeKey = 'ssi_connect.settings.theme_mode';
  static const _languageKey = 'ssi_connect.settings.language';

  final FlutterSecureStorage _storage;

  /// The chosen language, or null for "whatever the device says".
  Future<Locale?> loadLocale() async {
    final raw = await _storage.read(key: _languageKey);
    if (raw == null || raw.isEmpty) return null;
    // Guards against a language stored by a newer version that this one
    // cannot render - falling back to the device is better than showing
    // half a translation.
    final known = AppStrings.supportedLocales.any((l) => l.languageCode == raw);
    return known ? Locale(raw) : null;
  }

  /// [locale] null means "follow the device"; stored as an empty value so
  /// there is no difference between "never chose" and "chose the device".
  Future<void> saveLocale(Locale? locale) =>
      _storage.write(key: _languageKey, value: locale?.languageCode ?? '');

  /// The stored preference, or null when the user never chose one.
  Future<ThemeMode?> loadThemeMode() async {
    final raw = await _storage.read(key: _themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // Unknown value from a newer version, or nothing stored at all.
      _ => null,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _storage.write(key: _themeModeKey, value: mode.name);
}
