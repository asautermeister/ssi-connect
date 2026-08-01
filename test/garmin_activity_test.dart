import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/garmin/models/garmin_activity.dart';
import 'package:ssi_connect/models/dive.dart';

void main() {
  group('GarminActivity depth conversion', () {
    test('reads the list endpoint depth as centimetres', () {
      // Real case: this dive was ~11 m and first showed up as 1149.3.
      final activity = GarminActivity({'maxDepth': 1149.3});

      expect(activity.maxDepthMeters, 11.5);
    });

    test('rounds to one decimal', () {
      expect(GarminActivity({'maxDepth': 2806.0}).maxDepthMeters, 28.1);
      expect(GarminActivity({'maxDepth': 4400.0}).maxDepthMeters, 44.0);
      expect(GarminActivity({'averageDepth': 3124.0}).avgDepthMeters, 31.2);
    });

    test('leaves a missing depth as null rather than zero', () {
      expect(GarminActivity({'activityId': 1}).maxDepthMeters, isNull);
      expect(GarminActivity({'activityId': 1}).avgDepthMeters, isNull);
    });

    test('converts depth on the way into the Dive model', () {
      final dive = Dive.fromGarminActivity(
        GarminActivity({
          'activityId': 1,
          'startTimeLocal': '2026-06-07 09:16:29',
          'maxDepth': 1149.3,
          'duration': 1153.6,
        }),
      );

      expect(dive!.maxDepthMeters, 11.5);
    });
  });

  group('GarminActivity.diveNumber', () {
    test('reads a running dive number when one is present', () {
      expect(GarminActivity({'diveNumber': 142}).diveNumber, 142);
      expect(
        GarminActivity({
          'summaryDTO': {'diveNumber': 7},
        }).diveNumber,
        7,
      );
    });

    test('is null when the payload has none, so the UI can hide it', () {
      // Shape of a real activity-list entry, which in the response we have
      // seen carries no dive number at all.
      expect(
        GarminActivity({
          'activityId': 23159324330,
          'startTimeLocal': '2026-06-07 09:16:29',
          'duration': 1153.6,
          'maxDepth': 1149.3,
        }).diveNumber,
        isNull,
      );
    });

    test('treats a zero or negative counter as absent', () {
      expect(GarminActivity({'diveNumber': 0}).diveNumber, isNull);
      expect(GarminActivity({'diveNumber': -1}).diveNumber, isNull);
    });

    test('the probe surfaces dive-number candidates for diagnosis', () {
      final fields = GarminActivity({
        'diveNumber': 142,
        'distance': 19.04,
      }).probeMeasurementFields();

      expect(fields['diveNumber'], 142);
      expect(fields.containsKey('distance'), isFalse);
    });
  });
}
