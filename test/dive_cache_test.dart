import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';
import 'package:ssi_connect/models/water_type.dart';

void main() {
  group('Dive JSON round trip', () {
    test('carries every field the app shows or exports', () {
      final original = Dive(
        id: 'a1',
        dateTime: DateTime(2025, 11, 7, 10, 50),
        maxDepthMeters: 28.4,
        avgDepthMeters: 17.2,
        waterTemperatureCelsius: 22.0,
        duration: const Duration(minutes: 54, seconds: 30),
        locationName: 'Blaue Grotte',
        diveNumber: 142,
        descentCount: 31,
        waterType: DiveWaterType.fresh,
        type: DiveType.multiGas,
        diveNumberOfDay: 2,
      );

      final restored = Dive.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.dateTime, original.dateTime);
      expect(restored.maxDepthMeters, original.maxDepthMeters);
      expect(restored.avgDepthMeters, original.avgDepthMeters);
      expect(
        restored.waterTemperatureCelsius,
        original.waterTemperatureCelsius,
      );
      expect(restored.duration, original.duration);
      expect(restored.locationName, original.locationName);
      expect(restored.diveNumber, original.diveNumber);
      expect(restored.descentCount, original.descentCount);
      expect(restored.waterType, original.waterType);
      expect(restored.type, original.type);
      expect(restored.diveNumberOfDay, original.diveNumberOfDay);
    });

    test('survives a dive whose optional fields are all missing', () {
      final original = Dive(
        id: 'a2',
        dateTime: DateTime(2025, 11, 7),
        maxDepthMeters: null,
        avgDepthMeters: null,
        waterTemperatureCelsius: null,
        duration: null,
        locationName: null,
      );

      final restored = Dive.fromJson(original.toJson());

      expect(restored.maxDepthMeters, isNull);
      expect(restored.duration, isNull);
      expect(restored.waterType, isNull);
      expect(restored.type, DiveType.scuba);
    });

    test('writes enums by name, not by position', () {
      // Reordering an enum later must not turn every cached freedive into
      // a rebreather dive.
      final json = Dive(
        id: 'a3',
        dateTime: DateTime(2025, 1, 1),
        maxDepthMeters: null,
        avgDepthMeters: null,
        waterTemperatureCelsius: null,
        duration: null,
        locationName: null,
        type: DiveType.apnea,
        waterType: DiveWaterType.salt,
      ).toJson();

      expect(json['type'], 'apnea');
      expect(json['waterType'], 'salt');
    });

    test('falls back rather than throwing on an unknown enum value', () {
      final restored = Dive.fromJson({
        'id': 'a4',
        'dateTime': '2025-11-07T10:50:00.000',
        'type': 'sidemount_something_new',
        'waterType': 'brackish',
      });

      // A cache written by a newer version has to degrade, not crash.
      expect(restored.type, DiveType.scuba);
      expect(restored.waterType, isNull);
      expect(restored.diveNumberOfDay, 1);
    });
  });
}
