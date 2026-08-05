import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ssi/ssi_logged_dive.dart';

/// Remembers what has already been carried over into SSI: the ticks set by
/// hand, and what each connected SSI logbook says.
///
/// Only dive ids and timestamps, nothing about the dives themselves - but a
/// list of them still says when this person was diving, so it goes into the
/// encrypted keystore next to everything else rather than a plain file.
class ExportedDivesRepository {
  ExportedDivesRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _marksKey = 'ssi_connect.exported_dives';
  static const _logbookKey = 'ssi_connect.ssi_logbook_dives';

  final FlutterSecureStorage _storage;

  /// The ticks the user set or cleared by hand, by dive id.
  ///
  /// A stored `false` is not the same as a missing entry: it means "I say
  /// this one has *not* gone across", which overrules the logbook.
  Future<Map<String, bool>> loadMarks() async {
    final raw = await _storage.read(key: _marksKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      // The first version stored a bare list of ticked ids. Read as all
      // ticked, so an upgrade does not lose them.
      if (decoded is List) {
        return {for (final id in decoded) id as String: true};
      }
      return {
        for (final entry in (decoded as Map).entries)
          entry.key as String: entry.value == true,
      };
    } catch (_) {
      // Half-written, or from a newer version. Losing the ticks costs a few
      // taps; crashing on startup costs more.
      await _storage.delete(key: _marksKey);
      return {};
    }
  }

  Future<void> saveMarks(Map<String, bool> marks) =>
      _storage.write(key: _marksKey, value: jsonEncode(marks));

  /// The dives each connected SSI account has in its logbook, by account id.
  Future<Map<String, List<SsiLoggedDive>>> loadLogbooks() async {
    final raw = await _storage.read(key: _logbookKey);
    if (raw == null) return {};
    try {
      return {
        for (final entry in (jsonDecode(raw) as Map).entries)
          entry.key as String: [
            for (final dive in entry.value as List)
              SsiLoggedDive.fromJson((dive as Map).cast<String, dynamic>()),
          ],
      };
    } catch (_) {
      await _storage.delete(key: _logbookKey);
      return {};
    }
  }

  Future<void> saveLogbooks(Map<String, List<SsiLoggedDive>> logbooks) =>
      _storage.write(
        key: _logbookKey,
        value: jsonEncode({
          for (final entry in logbooks.entries)
            entry.key: [for (final dive in entry.value) dive.toJson()],
        }),
      );
}
