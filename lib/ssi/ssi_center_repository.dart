import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ssi_center_code.dart';

/// Persists the dive centres the user has scanned in.
///
/// Kept under its own key rather than mixed into the buddy list: the two
/// carry different fields, and a stored centre read back as a member would
/// lose its name. Stored in the encrypted keystore like everything else -
/// nothing here is secret, but the device knows where its owner dives.
class SsiCenterRepository {
  SsiCenterRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.ssi_centers';

  final FlutterSecureStorage _storage;

  Future<List<SsiCenterCode>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final entry in decoded)
        SsiCenterCode.fromJson(entry as Map<String, dynamic>),
    ];
  }

  Future<void> saveAll(List<SsiCenterCode> centers) async {
    await _storage.write(
      key: _key,
      value: jsonEncode([for (final center in centers) center.toJson()]),
    );
  }
}
