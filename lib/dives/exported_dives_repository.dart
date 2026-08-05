import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which dives have already been carried over into SSI.
///
/// Only the dive ids, nothing about the dives themselves - but a list of
/// them still says when this person was diving, so it goes into the
/// encrypted keystore next to everything else rather than a plain file.
class ExportedDivesRepository {
  ExportedDivesRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.exported_dives';

  final FlutterSecureStorage _storage;

  Future<Set<String>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    try {
      return {for (final id in jsonDecode(raw) as List) id as String};
    } catch (_) {
      // Written by an older version, or half-written. Losing the ticks
      // costs a few taps; crashing on startup costs more.
      await _storage.delete(key: _key);
      return {};
    }
  }

  Future<void> save(Set<String> diveIds) =>
      _storage.write(key: _key, value: jsonEncode(diveIds.toList()));
}
