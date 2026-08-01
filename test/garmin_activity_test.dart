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
}
