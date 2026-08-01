import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import '../models/dive.dart';
import '../models/water_type.dart';
import 'fit_import_exception.dart';

/// Reads dives out of a Garmin-exported .fit file, as a fallback for when
/// the automatic Garmin login isn't available.
///
/// Depth/duration come from the FIT `dive_summary` message (one per dive -
/// a "dive day" export with several sequential dives merged into one
/// activity, like Garmin's own multi-dive log, produces several of these in
/// a single file, and each becomes its own [Dive]). Start time and water
/// temperature come from the matching `session` message. `dive_summary`
/// doesn't carry its own timezone-safe start time, so this reads it from
/// whichever `session` message is closest in time - exact for the common
/// case of one dive per file, best-effort for multi-dive files.
class FitDiveImporter {
  const FitDiveImporter._();

  static List<Dive> parse(Uint8List bytes) {
    final FitFile fitFile;
    try {
      fitFile = FitFile.fromBytes(bytes);
    } catch (e) {
      throw FitImportException(
        'Datei konnte nicht gelesen werden - ist es eine FIT-Datei? ($e)',
      );
    }

    final diveSummaries = <DiveSummaryMessage>[];
    final sessions = <SessionMessage>[];
    DiveSettingsMessage? diveSettings;
    for (final record in fitFile.records) {
      final message = record.message;
      if (message is DiveSummaryMessage) diveSummaries.add(message);
      if (message is SessionMessage) sessions.add(message);
      // The computer's settings for this file - they carry the one thing
      // the summary doesn't: whether this was fresh or salt water.
      if (message is DiveSettingsMessage) diveSettings ??= message;
    }

    final waterType = _waterTypeOf(diveSettings);

    if (diveSummaries.isEmpty) {
      throw FitImportException(
        'Diese FIT-Datei enthält keine Tauchgangs-Daten (dive_summary).',
      );
    }

    final dives = <Dive>[];
    for (var i = 0; i < diveSummaries.length; i++) {
      final summary = diveSummaries[i];
      final session = _closestSession(summary, sessions);

      final startMillis = session?.startTime ?? summary.timestamp;
      if (startMillis == null) continue;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        startMillis,
        isUtc: true,
      ).toLocal();

      final durationSeconds = session?.totalElapsedTime ?? summary.bottomTime;

      dives.add(
        Dive(
          id: 'fit-$startMillis-${summary.diveNumber ?? i}',
          dateTime: dateTime,
          maxDepthMeters: summary.maxDepth,
          avgDepthMeters: summary.avgDepth,
          waterTemperatureCelsius: session?.avgTemperature?.toDouble(),
          duration: durationSeconds == null
              ? null
              : Duration(seconds: durationSeconds.round()),
          locationName: null,
          // Unlike the Garmin list endpoint, the FIT dive_summary carries
          // the diver's running dive number outright.
          diveNumber: summary.diveNumber,
          waterType: waterType,
        ),
      );
    }

    if (dives.isEmpty) {
      throw FitImportException(
        'Die Tauchgänge in dieser FIT-Datei haben keinen auswertbaren Zeitstempel.',
      );
    }

    return assignDiveNumbersOfDay(dives);
  }

  /// Fresh or salt water from the dive computer's settings.
  ///
  /// FIT states it outright as an enum, so unlike the Garmin web API there
  /// is nothing to infer here. `en13319` and `custom` mean the diver set a
  /// density by hand, so those fall back to the density value; anything
  /// else leaves the water type unset.
  static DiveWaterType? _waterTypeOf(DiveSettingsMessage? settings) {
    if (settings == null) return null;
    return switch (settings.waterType) {
      WaterType.fresh => DiveWaterType.fresh,
      WaterType.salt => DiveWaterType.salt,
      _ => DiveWaterType.fromDensity(settings.waterDensity),
    };
  }

  /// If there's exactly one session in the file (the common single-dive
  /// export), it applies to every dive_summary. Otherwise, picks whichever
  /// session's start time is numerically closest to the dive_summary's
  /// timestamp - dive_summary doesn't reliably reference its session by
  /// index across the exports we've seen.
  static SessionMessage? _closestSession(
    DiveSummaryMessage summary,
    List<SessionMessage> sessions,
  ) {
    if (sessions.isEmpty) return null;
    if (sessions.length == 1) return sessions.single;
    final summaryTime = summary.timestamp;
    if (summaryTime == null) return sessions.first;

    SessionMessage? closest;
    int? closestDelta;
    for (final session in sessions) {
      final startTime = session.startTime;
      if (startTime == null) continue;
      final delta = (startTime - summaryTime).abs();
      if (closestDelta == null || delta < closestDelta) {
        closest = session;
        closestDelta = delta;
      }
    }
    return closest ?? sessions.first;
  }
}
