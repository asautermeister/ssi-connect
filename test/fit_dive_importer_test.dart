import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/fit/fit_dive_importer.dart';
import 'package:ssi_connect/fit/fit_import_exception.dart';

/// Round-trips a synthetic FIT file through fit_tool's own encoder so the
/// importer can be tested without a real device export.
Uint8List _buildFitBytes({
  required int sessionStartMillis,
  required double totalElapsedSeconds,
  required int avgTemperature,
  required int diveSummaryTimestampMillis,
  required double maxDepth,
  required double avgDepth,
  required double bottomTimeSeconds,
  required int diveNumber,
}) {
  final builder = FitFileBuilder();

  final session = SessionMessage()
    ..startTime = sessionStartMillis
    ..timestamp = sessionStartMillis
    ..totalElapsedTime = totalElapsedSeconds
    ..avgTemperature = avgTemperature;
  builder.add(session);

  final diveSummary = DiveSummaryMessage()
    ..timestamp = diveSummaryTimestampMillis
    ..maxDepth = maxDepth
    ..avgDepth = avgDepth
    ..bottomTime = bottomTimeSeconds
    ..diveNumber = diveNumber;
  builder.add(diveSummary);

  return builder.build().toBytes();
}

void main() {
  group('FitDiveImporter', () {
    test('maps a single dive_summary + session into one Dive', () {
      final startMillis = DateTime(
        2024,
        6,
        1,
        9,
        30,
      ).toUtc().millisecondsSinceEpoch;
      final bytes = _buildFitBytes(
        sessionStartMillis: startMillis,
        totalElapsedSeconds: 2400,
        avgTemperature: 24,
        diveSummaryTimestampMillis: startMillis,
        maxDepth: 18.5,
        avgDepth: 12.3,
        bottomTimeSeconds: 2300,
        diveNumber: 1,
      );

      final dives = FitDiveImporter.parse(bytes);

      expect(dives, hasLength(1));
      final dive = dives.single;
      expect(dive.maxDepthMeters, closeTo(18.5, 0.01));
      expect(dive.avgDepthMeters, closeTo(12.3, 0.01));
      expect(dive.waterTemperatureCelsius, 24);
      expect(dive.duration, const Duration(seconds: 2400));
      expect(dive.diveNumberOfDay, 1);
    });

    test('throws FitImportException for a file without dive_summary', () {
      final builder = FitFileBuilder();
      final startMillis = DateTime(
        2024,
        6,
        1,
        9,
        30,
      ).toUtc().millisecondsSinceEpoch;
      builder.add(
        SessionMessage()
          ..startTime = startMillis
          ..timestamp = startMillis
          ..totalElapsedTime = 1000,
      );
      final bytes = builder.build().toBytes();

      expect(
        () => FitDiveImporter.parse(bytes),
        throwsA(isA<FitImportException>()),
      );
    });

    test('throws FitImportException for garbage bytes', () {
      expect(
        () => FitDiveImporter.parse(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<FitImportException>()),
      );
    });
  });
}
