import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_qr_payload_builder.dart';

Dive _dive({
  DateTime? dateTime,
  double? maxDepthMeters,
  Duration? duration,
  double? waterTemperatureCelsius,
}) {
  return Dive(
    id: '1',
    dateTime: dateTime ?? DateTime(2019, 7, 21, 10, 0),
    maxDepthMeters: maxDepthMeters,
    avgDepthMeters: null,
    waterTemperatureCelsius: waterTemperatureCelsius,
    duration: duration,
    locationName: null,
  );
}

void main() {
  group('SsiQrPayloadBuilder', () {
    test('builds the required fields with fractional depth', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2019, 7, 21, 10, 0),
          maxDepthMeters: 12.8,
          duration: const Duration(minutes: 38),
        ),
      );

      expect(
        payload,
        'dive;noid;dive_type:0;datetime:201907211000;divetime:38;depth_m:12.8',
      );
    });

    test('formats whole-number depth without a decimal point', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 18, duration: const Duration(minutes: 53)),
      );

      expect(payload, contains('depth_m:18'));
      expect(payload, isNot(contains('depth_m:18.0')));
    });

    test('appends watertemp_c when available', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          maxDepthMeters: 20,
          duration: const Duration(minutes: 40),
          waterTemperatureCelsius: 26,
        ),
      );

      expect(payload, endsWith('watertemp_c:26'));
    });

    test('omits watertemp_c when not available', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 20, duration: const Duration(minutes: 40)),
      );

      expect(payload, isNot(contains('watertemp_c')));
    });

    test('throws when max depth is missing', () {
      expect(
        () => SsiQrPayloadBuilder.build(
          _dive(duration: const Duration(minutes: 10)),
        ),
        throwsArgumentError,
      );
    });

    test('throws when duration is missing', () {
      expect(
        () => SsiQrPayloadBuilder.build(_dive(maxDepthMeters: 10)),
        throwsArgumentError,
      );
    });

    test('pads single-digit month/day/hour/minute in datetime', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2024, 1, 5, 7, 3),
          maxDepthMeters: 10,
          duration: const Duration(minutes: 5),
        ),
      );

      expect(payload, contains('datetime:202401050703'));
    });
  });
}
