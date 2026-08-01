import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/water_type.dart';

void main() {
  group('DiveWaterType.ssiVarId', () {
    test('matches the codes read off real SSI exports', () {
      // A lake dive exported var_watertype_id:4, three sea dives from the
      // same logbook exported 5.
      expect(DiveWaterType.fresh.ssiVarId, 4);
      expect(DiveWaterType.salt.ssiVarId, 5);
    });
  });

  group('DiveWaterType.fromDensity', () {
    test('reads the two densities a dive computer actually reports', () {
      expect(DiveWaterType.fromDensity(1000), DiveWaterType.fresh);
      expect(DiveWaterType.fromDensity(1025), DiveWaterType.salt);
    });

    test('puts brackish water on the side it is closer to', () {
      expect(DiveWaterType.fromDensity(1005), DiveWaterType.fresh);
      expect(DiveWaterType.fromDensity(1018), DiveWaterType.salt);
    });

    test('rejects values that cannot be a water density', () {
      // Guards against a field that turns out to hold something else - a
      // percentage, a code, grams per litre. Better unset than wrong.
      expect(DiveWaterType.fromDensity(null), isNull);
      expect(DiveWaterType.fromDensity(0), isNull);
      expect(DiveWaterType.fromDensity(1), isNull);
      expect(DiveWaterType.fromDensity(1.025), isNull);
      expect(DiveWaterType.fromDensity(9999), isNull);
    });
  });

  group('DiveWaterType.fromName', () {
    test('accepts the spellings a JSON field might use', () {
      expect(DiveWaterType.fromName('fresh'), DiveWaterType.fresh);
      expect(DiveWaterType.fromName('FRESH_WATER'), DiveWaterType.fresh);
      expect(DiveWaterType.fromName(' salt '), DiveWaterType.salt);
      expect(DiveWaterType.fromName('saltwater'), DiveWaterType.salt);
    });

    test('rejects anything it does not recognise', () {
      expect(DiveWaterType.fromName(null), isNull);
      expect(DiveWaterType.fromName(''), isNull);
      // A numeric code would need a code table we have not verified.
      expect(DiveWaterType.fromName('1'), isNull);
      expect(DiveWaterType.fromName('en13319'), isNull);
    });
  });
}
