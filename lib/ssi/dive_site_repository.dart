import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dive_site.dart';

/// Persists the dive sites the user has matched to an SSI site number.
///
/// In the encrypted keystore like everything else. A site number is not a
/// secret, but the list of them together with their coordinates says where
/// this person dives, which is not something to leave in a plain file.
class DiveSiteRepository {
  DiveSiteRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.dive_sites';

  final FlutterSecureStorage _storage;

  Future<List<DiveSite>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return [
        for (final entry in decoded)
          DiveSite.fromJson((entry as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      // Written by an older version, or half-written. Losing the list costs
      // the user re-entering a few numbers; crashing on startup costs more.
      await _storage.delete(key: _key);
      return [];
    }
  }

  Future<void> saveAll(List<DiveSite> sites) async {
    await _storage.write(
      key: _key,
      value: jsonEncode([for (final site in sites) site.toJson()]),
    );
  }
}
