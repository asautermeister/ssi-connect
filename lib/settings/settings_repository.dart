import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final FlutterSecureStorage _storage;

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
