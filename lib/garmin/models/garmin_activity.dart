/// Thin wrapper around one activity JSON object from Garmin Connect's
/// `activitylist-service` / `activity-service` endpoints.
///
/// Garmin's field names for diving-specific values (max depth, water temp,
/// dive duration, ...) are not publicly documented, and the field-name
/// guesses below have NOT been verified against a real account yet. [raw]
/// is kept around specifically so that, once we can see a real response,
/// the guesses here can be corrected without having to re-plumb the
/// activity client or the UI.
class GarminActivity {
  const GarminActivity(this.raw);

  final Map<String, dynamic> raw;

  String? get activityId => raw['activityId']?.toString();

  String? get typeKey => (raw['activityType'] as Map?)?['typeKey'] as String?;

  /// e.g. "2024-07-21 10:03:00" - Garmin's list endpoint returns this as a
  /// space-separated local-time string, not ISO8601.
  DateTime? get startTimeLocal {
    final localTimeString = raw['startTimeLocal'] as String?;
    if (localTimeString == null) return null;
    return DateTime.tryParse(localTimeString.replaceFirst(' ', 'T'));
  }

  /// Elapsed duration in seconds.
  double? get durationSeconds => _numAny(['duration', 'elapsedDuration']);

  /// Max depth in meters - Garmin generally stores metric internally, but
  /// this key name is a guess; verify against a real dive activity.
  double? get maxDepthMeters =>
      _numAny(['maxDepth', 'maxDepthInMeters', 'summaryDTO.maxDepth']);

  double? get avgDepthMeters =>
      _numAny(['averageDepth', 'avgDepth', 'summaryDTO.averageDepth']);

  double? get waterTemperatureCelsius => _numAny([
    'waterTemperature',
    'minWaterTemperature',
    'summaryDTO.waterTemperature',
  ]);

  String? get locationName =>
      raw['locationName'] as String? ?? raw['startLocationName'] as String?;

  /// Every numeric field whose name mentions depth or temperature, with the
  /// value Garmin actually sent.
  ///
  /// Exists because the response for a single activity is far too large to
  /// read in the API log, and the interesting fields are a handful of keys
  /// buried in it. Written into the log so a wrong reading (a depth of
  /// 1149.3 for an 11 m dive, say) can be traced to the exact key and unit
  /// instead of guessed at.
  Map<String, Object?> probeMeasurementFields() {
    final found = <String, Object?>{};
    void walk(String prefix, Map<dynamic, dynamic> map) {
      for (final entry in map.entries) {
        final key = '$prefix${entry.key}';
        final value = entry.value;
        if (value is Map) {
          walk('$key.', value);
        } else if (value is num) {
          final lower = key.toLowerCase();
          if (lower.contains('depth') || lower.contains('temperature')) {
            found[key] = value;
          }
        }
      }
    }

    walk('', raw);
    return found;
  }

  /// Looks up each candidate key in turn; keys containing "." are read as a
  /// one-level nested path (e.g. "summaryDTO.maxDepth").
  double? _numAny(List<String> candidateKeys) {
    for (final key in candidateKeys) {
      final value = key.contains('.') ? _nested(key) : raw[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  Object? _nested(String dottedKey) {
    final parts = dottedKey.split('.');
    Object? current = raw;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }
}
