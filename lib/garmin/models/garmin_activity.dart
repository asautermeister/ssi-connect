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

  /// Max depth in metres.
  ///
  /// The activity-list endpoint reports depth in **centimetres**, which is
  /// why an 11 m dive first showed up as 1149.3: the raw value is 1149.3 cm
  /// (11.493 m). Confirmed against several real dives before the divisor
  /// was added. Rounded to one decimal, which is the precision the SSI
  /// import format carries anyway.
  double? get maxDepthMeters => _metresFromCentimetres(
    _numAny(['maxDepth', 'maxDepthInMeters', 'summaryDTO.maxDepth']),
  );

  double? get avgDepthMeters => _metresFromCentimetres(
    _numAny(['averageDepth', 'avgDepth', 'summaryDTO.averageDepth']),
  );

  /// Water temperature in °C.
  ///
  /// The list endpoint reports `minTemperature` / `maxTemperature` (no
  /// "water" in the name), already in °C - a real dive came back as 22.0 /
  /// 25.0. The minimum is used: it is the reading from depth, which is what
  /// a dive log means by water temperature, whereas the maximum tends to be
  /// the warmer surface value.
  ///
  /// The `water*` keys are kept ahead of it in case the per-activity detail
  /// endpoint names them that way.
  double? get waterTemperatureCelsius => _numAny([
    'waterTemperature',
    'minWaterTemperature',
    'summaryDTO.waterTemperature',
    'minTemperature',
  ]);

  /// How many individual descents this activity contains.
  ///
  /// Garmin sends this as `diveCount`. It is emphatically *not* a lifetime
  /// dive number: a 19-minute freediving session came back with 31, one per
  /// descent. Only meaningful above 1, so a single scuba dive doesn't get a
  /// pointless "1 descent" line.
  int? get descentCount {
    final value = _numAny(['diveCount', 'summaryDTO.diveCount']);
    if (value == null) return null;
    final rounded = value.round();
    return rounded > 1 ? rounded : null;
  }

  /// The diver's running dive number, if Garmin ships one.
  ///
  /// The Descent watches keep a lifetime counter and the FIT dive_summary
  /// carries it, but whether the activity-list endpoint passes it through -
  /// and under which name - is unconfirmed. So this reads only keys that
  /// unambiguously mean "dive number" and returns null otherwise: the UI
  /// then hides the field rather than showing a number that might be
  /// something else. The PROBE log entry lists the real candidates.
  int? get diveNumber {
    final value = _numAny([
      'diveNumber',
      'diveNum',
      'summaryDTO.diveNumber',
      'summaryDTO.diveNum',
    ]);
    if (value == null) return null;
    final rounded = value.round();
    return rounded > 0 ? rounded : null;
  }

  static double? _metresFromCentimetres(double? centimetres) {
    if (centimetres == null) return null;
    return double.parse((centimetres / 100).toStringAsFixed(1));
  }

  String? get locationName =>
      raw['locationName'] as String? ?? raw['startLocationName'] as String?;

  /// Every numeric field whose name mentions depth, temperature, a dive or
  /// a number, with the value Garmin actually sent.
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
          if (lower.contains('depth') ||
              lower.contains('temperature') ||
              lower.contains('dive') ||
              lower.contains('number')) {
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
