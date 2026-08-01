import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ssi_buddy_code.dart';

/// Persists the SSI buddies the user has scanned in - divers who have no
/// Garmin account here, but who should be selectable when exporting a dive.
///
/// Stored in the encrypted keystore like the accounts are. These are other
/// people's names, mail addresses and member numbers; the fact that they
/// are not login credentials doesn't make them less personal.
class SsiBuddyRepository {
  SsiBuddyRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.ssi_buddies';

  final FlutterSecureStorage _storage;

  Future<List<SsiBuddyCode>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final entry in decoded)
        SsiBuddyCode.fromJson(entry as Map<String, dynamic>),
    ];
  }

  Future<void> saveAll(List<SsiBuddyCode> buddies) async {
    await _storage.write(
      key: _key,
      value: jsonEncode([for (final buddy in buddies) buddy.toJson()]),
    );
  }
}
