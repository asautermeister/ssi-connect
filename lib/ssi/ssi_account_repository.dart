import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ssi_session.dart';

/// Persists the connected SSI account.
///
/// What is stored is the session token, never the password - see
/// [SsiSession]. The token still opens somebody's dive logbook, so this
/// goes into the encrypted keystore like the Garmin credentials do.
class SsiAccountRepository {
  SsiAccountRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.ssi_account';

  final FlutterSecureStorage _storage;

  Future<SsiSession?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SsiSession.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      // Written by an older version, or half-written. Costs one login.
      await _storage.delete(key: _key);
      return null;
    }
  }

  Future<void> save(SsiSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
