import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/garmin/models/garmin_activity.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/water_type.dart';

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

  group('GarminActivity from a real activity-list entry', () {
    /// The measurement fields exactly as a real freediving activity
    /// returned them (captured via the PROBE log entry).
    GarminActivity realApneaActivity() => GarminActivity({
      'activityId': 23159324330,
      'startTimeLocal': '2026-06-07 09:16:29',
      'activityType': {'typeId': 148, 'typeKey': 'apnea_diving'},
      'duration': 1153.6240234375,
      'minTemperature': 22.0,
      'maxTemperature': 25.0,
      'maxDepth': 1149.3000030517578,
      'avgDepth': 274.6000051498413,
      'diveCount': 31,
    });

    test('converts both depths out of centimetres', () {
      final activity = realApneaActivity();

      expect(activity.maxDepthMeters, 11.5);
      expect(activity.avgDepthMeters, 2.7);
    });

    test('takes the minimum temperature as the water temperature', () {
      // The maximum is the warmer surface reading; a dive log means the
      // one from depth.
      expect(realApneaActivity().waterTemperatureCelsius, 22.0);
    });

    test('reads diveCount as descents, not as a running dive number', () {
      final activity = realApneaActivity();

      expect(activity.descentCount, 31);
      // 31 descents in one freediving session is not "dive number 31".
      expect(activity.diveNumber, isNull);
    });

    test('hides a descent count of one, which says nothing', () {
      expect(GarminActivity({'diveCount': 1}).descentCount, isNull);
      expect(GarminActivity({'diveCount': 0}).descentCount, isNull);
    });

    test('carries the values through to the Dive model', () {
      final dive = Dive.fromGarminActivity(realApneaActivity())!;

      expect(dive.maxDepthMeters, 11.5);
      expect(dive.waterTemperatureCelsius, 22.0);
      expect(dive.descentCount, 31);
      expect(dive.diveNumber, isNull);
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

    test('the probe also reports water fields, spelled out or numeric', () {
      // Whether Garmin says fresh or salt at all is still unconfirmed, so
      // the probe has to surface whatever water-related keys exist -
      // including string values, which an earlier numbers-only probe would
      // have missed.
      final fields = GarminActivity({
        'waterDensity': 1025,
        'waterType': 'salt',
        'salinity': 35,
        'elevationGain': 3,
      }).probeMeasurementFields();

      expect(fields['waterDensity'], 1025);
      expect(fields['waterType'], 'salt');
      expect(fields['salinity'], 35);
      expect(fields.containsKey('elevationGain'), isFalse);
    });
  });

  group('GarminActivity.waterType', () {
    test('reads the density, which cannot mean anything else', () {
      expect(
        GarminActivity({'waterDensity': 1025}).waterType,
        DiveWaterType.salt,
      );
      expect(
        GarminActivity({'waterDensity': 1000}).waterType,
        DiveWaterType.fresh,
      );
    });

    test('accepts a spelled-out type when there is no density', () {
      expect(
        GarminActivity({'waterType': 'fresh'}).waterType,
        DiveWaterType.fresh,
      );
    });

    test('ignores a numeric water type rather than assuming its coding', () {
      // FIT codes fresh as 0 and salt as 1, but whether the web API uses
      // that same table is unverified - and a wrong guess would file dives
      // in the wrong water without ever looking wrong.
      expect(GarminActivity({'waterType': 1}).waterType, isNull);
      expect(GarminActivity({'waterType': 0}).waterType, isNull);
    });

    test('is null when the response says nothing about the water', () {
      expect(GarminActivity({'maxDepth': 2800}).waterType, isNull);
    });

    test('carries through to the Dive model', () {
      final dive = Dive.fromGarminActivity(
        GarminActivity({
          'activityId': 1,
          'startTimeLocal': '2025-09-06 13:28:00',
          'maxDepth': 1300,
          'waterDensity': 1000,
        }),
      );

      expect(dive?.waterType, DiveWaterType.fresh);
    });
  });
}
