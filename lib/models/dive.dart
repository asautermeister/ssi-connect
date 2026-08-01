import '../garmin/models/garmin_activity.dart';
import 'dive_type.dart';
import 'water_type.dart';

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
    this.diveNumber,
    this.descentCount,
    this.waterType,
    this.isDecoDive,
    this.type = DiveType.scuba,
    this.diveNumberOfDay = 1,
  });

  final String id;
  final DateTime dateTime;
  final double? maxDepthMeters;
  final double? avgDepthMeters;
  final double? waterTemperatureCelsius;
  final Duration? duration;
  final String? locationName;

  /// The diver's running dive number, when the source provides one. Null
  /// means "not reported" - it is never invented, since a made-up number
  /// would look identical to a real one.
  final int? diveNumber;

  /// Number of individual descents inside this activity, when there was
  /// more than one - a freediving session is many descents under one
  /// activity. Null for an ordinary single dive.
  final int? descentCount;

  /// Fresh or salt water, when the source reported it. Null means "not
  /// reported", and the SSI payload then leaves the field out.
  final DiveWaterType? waterType;

  /// Whether the dive went into decompression. Null is "not reported",
  /// which is not the same as "no deco" - so the payload stays silent
  /// rather than asserting the safer-sounding of the two.
  final bool? isDecoDive;

  final DiveType type;
  final int diveNumberOfDay;

  Dive copyWith({int? diveNumberOfDay}) => Dive(
    id: id,
    dateTime: dateTime,
    maxDepthMeters: maxDepthMeters,
    avgDepthMeters: avgDepthMeters,
    waterTemperatureCelsius: waterTemperatureCelsius,
    duration: duration,
    locationName: locationName,
    diveNumber: diveNumber,
    descentCount: descentCount,
    waterType: waterType,
    isDecoDive: isDecoDive,
    type: type,
    diveNumberOfDay: diveNumberOfDay ?? this.diveNumberOfDay,
  );

  /// For the on-device cache. Enums are written as names rather than
  /// indices so reordering them later can't silently turn every cached
  /// freedive into a rebreather dive.
  Map<String, dynamic> toJson() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'maxDepthMeters': maxDepthMeters,
    'avgDepthMeters': avgDepthMeters,
    'waterTemperatureCelsius': waterTemperatureCelsius,
    'durationSeconds': duration?.inSeconds,
    'locationName': locationName,
    'diveNumber': diveNumber,
    'descentCount': descentCount,
    'waterType': waterType?.name,
    'isDecoDive': isDecoDive,
    'type': type.name,
    'diveNumberOfDay': diveNumberOfDay,
  };

  /// Tolerant of missing and unknown values: a cache written by an older
  /// version must not crash the app, it should just be a little poorer.
  factory Dive.fromJson(Map<String, dynamic> json) {
    final durationSeconds = json['durationSeconds'] as int?;
    return Dive(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      maxDepthMeters: (json['maxDepthMeters'] as num?)?.toDouble(),
      avgDepthMeters: (json['avgDepthMeters'] as num?)?.toDouble(),
      waterTemperatureCelsius: (json['waterTemperatureCelsius'] as num?)
          ?.toDouble(),
      duration: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds),
      locationName: json['locationName'] as String?,
      diveNumber: json['diveNumber'] as int?,
      descentCount: json['descentCount'] as int?,
      waterType: _enumByName(DiveWaterType.values, json['waterType']),
      isDecoDive: json['isDecoDive'] as bool?,
      type: _enumByName(DiveType.values, json['type']) ?? DiveType.scuba,
      diveNumberOfDay: json['diveNumberOfDay'] as int? ?? 1,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

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
      diveNumber: activity.diveNumber,
      descentCount: activity.descentCount,
      waterType: activity.waterType,
      isDecoDive: activity.isDecoDive,
      type: DiveType.fromGarminTypeKey(activity.typeKey),
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
