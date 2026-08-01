import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/dive.dart';

/// One account's cached dives, with the moment they were fetched.
class CachedDives {
  const CachedDives({required this.dives, required this.fetchedAt});

  final List<Dive> dives;
  final DateTime fetchedAt;
}

/// Keeps the last fetched dives on the device, so the app shows something
/// useful before the network answers - and still does when there is no
/// network at all, which on a boat or in a quarry car park is the normal
/// case rather than the exception.
///
/// Written to the encrypted keystore, not to a plain file: these are dive
/// profiles, which are health data. The same reasoning that put the tokens
/// there applies to what the tokens give access to.
///
/// Only the most recent [maxDivesPerAccount] dives are kept. The keystore
/// is meant for small values, and the app only ever shows recent dives -
/// an unbounded cache would grow into it for no benefit.
class DiveCacheRepository {
  DiveCacheRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'ssi_connect.dives.';
  static const maxDivesPerAccount = 50;

  final FlutterSecureStorage _storage;

  Future<CachedDives?> load(String accountId) async {
    final raw = await _storage.read(key: _keyPrefix + accountId);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CachedDives(
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        dives: [
          for (final entry in json['dives'] as List)
            Dive.fromJson((entry as Map).cast<String, dynamic>()),
        ],
      );
    } catch (_) {
      // A cache written by an older version, or a half-written one. It is
      // a cache: dropping it costs a refresh, whereas crashing on startup
      // would cost the whole app.
      await clear(accountId);
      return null;
    }
  }

  Future<void> save(String accountId, List<Dive> dives) async {
    final kept = dives.take(maxDivesPerAccount).toList();
    await _storage.write(
      key: _keyPrefix + accountId,
      value: jsonEncode({
        'fetchedAt': DateTime.now().toIso8601String(),
        'dives': [for (final dive in kept) dive.toJson()],
      }),
    );
  }

  Future<void> clear(String accountId) =>
      _storage.delete(key: _keyPrefix + accountId);
}
