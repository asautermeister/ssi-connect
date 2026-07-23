import '../garmin/models/garmin_activity.dart';

/// Our own domain model for a dive, mapped from Garmin's raw activity JSON.
/// [diveNumberOfDay] is not something Garmin provides - it's computed
/// locally by [assignDiveNumbersOfDay] from same-day start times.
class Dive {
  const Dive({
    required this.id,
    required this.dateTime,
    required this.maxDepthMeters,
    required this.avgDepthMeters,
    required this.waterTemperatureCelsius,
    required this.duration,
    required this.locationName,
    this.diveNumberOfDay = 1,
  });

  final String id;
  final DateTime dateTime;
  final double? maxDepthMeters;
  final double? avgDepthMeters;
  final double? waterTemperatureCelsius;
  final Duration? duration;
  final String? locationName;
  final int diveNumberOfDay;

  Dive copyWith({int? diveNumberOfDay}) => Dive(
    id: id,
    dateTime: dateTime,
    maxDepthMeters: maxDepthMeters,
    avgDepthMeters: avgDepthMeters,
    waterTemperatureCelsius: waterTemperatureCelsius,
    duration: duration,
    locationName: locationName,
    diveNumberOfDay: diveNumberOfDay ?? this.diveNumberOfDay,
  );

  /// Returns null if the activity is missing the one field (start time) we
  /// can't sensibly show a dive without.
  static Dive? fromGarminActivity(GarminActivity activity) {
    final dateTime = activity.startTimeLocal;
    final id = activity.activityId;
    if (dateTime == null || id == null) return null;
    final durationSeconds = activity.durationSeconds;
    return Dive(
      id: id,
      dateTime: dateTime,
      maxDepthMeters: activity.maxDepthMeters,
      avgDepthMeters: activity.avgDepthMeters,
      waterTemperatureCelsius: activity.waterTemperatureCelsius,
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds.round()),
      locationName: activity.locationName,
    );
  }
}

/// Groups [dives] by calendar day (using [Dive.dateTime]) and assigns each
/// one a 1-based [Dive.diveNumberOfDay] in chronological order within that
/// day. Input order is preserved in the returned list - only the
/// [Dive.diveNumberOfDay] field changes.
List<Dive> assignDiveNumbersOfDay(List<Dive> dives) {
  final byDay = <DateTime, List<Dive>>{};
  for (final dive in dives) {
    final day = DateTime(
      dive.dateTime.year,
      dive.dateTime.month,
      dive.dateTime.day,
    );
    byDay.putIfAbsent(day, () => []).add(dive);
  }

  final numberById = <String, int>{};
  for (final dayDives in byDay.values) {
    final sorted = [...dayDives]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (var i = 0; i < sorted.length; i++) {
      numberById[sorted[i].id] = i + 1;
    }
  }

  return [
    for (final dive in dives)
      dive.copyWith(diveNumberOfDay: numberById[dive.id]),
  ];
}
