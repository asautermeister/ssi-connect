import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/garmin_account.dart';

/// Persists Garmin accounts (including their session tokens) in the
/// platform-encrypted keystore/keychain via [FlutterSecureStorage].
///
/// Dive data itself is intentionally never written here - only account
/// metadata and auth tokens, which is the one thing that needs to survive
/// an app restart so the user isn't asked to log in every time.
class AccountRepository {
  AccountRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _indexKey = 'ssi_connect.account_ids';
  static const _accountKeyPrefix = 'ssi_connect.account.';

  final FlutterSecureStorage _storage;

  Future<List<GarminAccount>> loadAll() async {
    final ids = await _loadIndex();
    final accounts = <GarminAccount>[];
    for (final id in ids) {
      final raw = await _storage.read(key: _accountKeyPrefix + id);
      if (raw == null) continue;
      accounts.add(
        GarminAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    }
    return accounts;
  }

  Future<void> save(GarminAccount account) async {
    final ids = await _loadIndex();
    if (!ids.contains(account.id)) {
      ids.add(account.id);
      await _saveIndex(ids);
    }
    await _storage.write(
      key: _accountKeyPrefix + account.id,
      value: jsonEncode(account.toJson()),
    );
  }

  Future<void> remove(String accountId) async {
    final ids = await _loadIndex();
    ids.remove(accountId);
    await _saveIndex(ids);
    await _storage.delete(key: _accountKeyPrefix + accountId);
  }

  Future<List<String>> _loadIndex() async {
    final raw = await _storage.read(key: _indexKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> _saveIndex(List<String> ids) async {
    await _storage.write(key: _indexKey, value: jsonEncode(ids));
  }
}
