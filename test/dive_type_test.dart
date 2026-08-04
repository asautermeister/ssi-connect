import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings_de.dart';
import 'package:ssi_connect/garmin/models/garmin_activity.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';

const _s = AppStringsDe();

void main() {
  group('DiveType.fromGarminTypeKey', () {
    test('maps the freediving keys to apnea', () {
      expect(DiveType.fromGarminTypeKey('apnea_diving'), DiveType.apnea);
      expect(DiveType.fromGarminTypeKey('apnea_hunting'), DiveType.apnea);
    });

    test('maps the gas configurations', () {
      expect(
        DiveType.fromGarminTypeKey('single_gas_diving'),
        DiveType.singleGas,
      );
      expect(DiveType.fromGarminTypeKey('multi_gas_diving'), DiveType.multiGas);
      expect(DiveType.fromGarminTypeKey('ccr_diving'), DiveType.rebreather);
    });

    test('falls back to scuba for the generic and for unknown keys', () {
      expect(DiveType.fromGarminTypeKey('diving'), DiveType.scuba);
      expect(DiveType.fromGarminTypeKey('gauge_diving'), DiveType.scuba);
      expect(DiveType.fromGarminTypeKey('something_new'), DiveType.scuba);
      expect(DiveType.fromGarminTypeKey(null), DiveType.scuba);
    });

    test('every type has a label, so an icon never stands alone', () {
      for (final type in DiveType.values) {
        expect(type.label(_s), isNotEmpty);
      }
    });
  });

  group('Dive.fromGarminActivity', () {
    test('picks up the activity type from the Garmin payload', () {
      // Shape taken from a real activitylist-service response.
      final activity = GarminActivity({
        'activityId': 23159324330,
        'startTimeLocal': '2026-06-07 09:16:29',
        'activityType': {
          'typeId': 148,
          'typeKey': 'apnea_diving',
          'parentTypeId': 144,
        },
        'duration': 1153.6240234375,
      });

      final dive = Dive.fromGarminActivity(activity);

      expect(dive, isNotNull);
      expect(dive!.type, DiveType.apnea);
      expect(dive.duration, const Duration(seconds: 1154));
    });
  });

  group('GarminActivity.probeMeasurementFields', () {
    test('collects depth and temperature fields including nested ones', () {
      final activity = GarminActivity({
        'activityId': 1,
        'maxDepth': 1149.3,
        'averageDepth': 640.2,
        'minWaterTemperature': 21.0,
        'distance': 19.04,
        'summaryDTO': {'maxDepth': 11.493},
      });

      final fields = activity.probeMeasurementFields();

      expect(fields['maxDepth'], 1149.3);
      expect(fields['averageDepth'], 640.2);
      expect(fields['minWaterTemperature'], 21.0);
      expect(fields['summaryDTO.maxDepth'], 11.493);
      // Unrelated numbers stay out, so the probe stays readable.
      expect(fields.containsKey('distance'), isFalse);
      expect(fields.containsKey('activityId'), isFalse);
    });

    test('returns empty when the payload has no such fields', () {
      expect(
        GarminActivity({'activityId': 1}).probeMeasurementFields(),
        isEmpty,
      );
    });
  });
}
