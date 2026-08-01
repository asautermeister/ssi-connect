import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/garmin/garmin_activity_client.dart';
import 'package:ssi_connect/models/dive_type.dart';

void main() {
  group('garminDiveActivityTypes', () {
    test('queries only the parent type', () {
      // Garmin's search endpoint answers 400 for sub-types:
      // "Activity type cannot be an activity sub type".
      expect(garminDiveActivityTypes, ['diving']);
    });

    test('does not ask for any known dive sub-type', () {
      const subTypes = [
        'apnea_diving',
        'apnea_hunting',
        'ccr_diving',
        'single_gas_diving',
        'multi_gas_diving',
      ];

      for (final subType in subTypes) {
        expect(
          garminDiveActivityTypes,
          isNot(contains(subType)),
          reason: '$subType is a sub type and would be rejected with 400',
        );
      }

      // They still have to map to a badge, because the parent query
      // returns them and each result carries its own typeKey.
      expect(DiveType.fromGarminTypeKey('apnea_diving'), DiveType.apnea);
      expect(DiveType.fromGarminTypeKey('ccr_diving'), DiveType.rebreather);
    });
  });
}
