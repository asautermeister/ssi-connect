import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
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
        'dive;noid;dive_type:0;datetime:201907211000;divetime:38.0;depth_m:12.8',
      );
    });

    test(
      'matches a real SSI-exported QR payload (values only, our field set)',
      () {
        // From an actual QR code exported by the SSI app for a real dive:
        // dive;noid;dive_type:2;divetime:92.0;datetime:202511080856;depth_m:44.0;
        // site:1074;var_watertype_id:5;var_divetype_id:24;user_master_id:...
        final payload = SsiQrPayloadBuilder.build(
          _dive(
            dateTime: DateTime(2025, 11, 8, 8, 56),
            maxDepthMeters: 44.0,
            duration: const Duration(minutes: 92),
          ),
        );

        expect(payload, contains('datetime:202511080856'));
        expect(payload, contains('divetime:92.0'));
        expect(payload, contains('depth_m:44.0'));
      },
    );

    test(
      'matches a second real SSI-exported payload (normal recreational scuba dive)',
      () {
        // From a second real QR export, this time an ordinary scuba dive (not
        // extended range), confirming dive_type:0 is the right default here:
        // dive;noid;dive_type:0;divetime:54.0;datetime:202511071050;
        // depth_m:28.0;site:303948;var_watertype_id:5;var_divetype_id:24;...
        final payload = SsiQrPayloadBuilder.build(
          _dive(
            dateTime: DateTime(2025, 11, 7, 10, 50),
            maxDepthMeters: 28.0,
            duration: const Duration(minutes: 54),
          ),
        );

        expect(
          payload,
          'dive;noid;dive_type:0;datetime:202511071050;divetime:54.0;depth_m:28.0',
        );
      },
    );

    test('keeps one decimal place for whole-number depth and duration', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 18, duration: const Duration(minutes: 53)),
      );

      expect(payload, contains('depth_m:18.0'));
      expect(payload, contains('divetime:53.0'));
    });

    test('formats fractional dive duration in minutes', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          maxDepthMeters: 20,
          duration: const Duration(minutes: 92, seconds: 30),
        ),
      );

      expect(payload, contains('divetime:92.5'));
    });

    test('appends watertemp_c when available', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          maxDepthMeters: 20,
          duration: const Duration(minutes: 40),
          waterTemperatureCelsius: 26,
        ),
      );

      expect(payload, endsWith('watertemp_c:26.0'));
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

    test('attributes the dive to a scanned SSI member', () {
      // Field names and values as SSI writes them in its own export.
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 28, duration: const Duration(minutes: 54)),
        diver: const SsiBuddyCode(
          memberId: '3902893',
          firstName: 'Andreas',
          lastName: 'Sautermeister',
          email: 'andreas@example.com',
        ),
      );

      expect(payload, contains('user_master_id:3902893'));
      expect(payload, contains('user_firstname:Andreas'));
      expect(payload, contains('user_lastname:Sautermeister'));
      // The email is part of the buddy code but not of a dive record.
      expect(payload, isNot(contains('andreas@example.com')));
    });

    test('emits only the member id when no name was scanned', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 28, duration: const Duration(minutes: 54)),
        diver: const SsiBuddyCode(memberId: '3902893'),
      );

      expect(payload, contains('user_master_id:3902893'));
      expect(payload, isNot(contains('user_firstname')));
      expect(payload, isNot(contains('user_lastname')));
    });

    test('without a diver the payload is unchanged', () {
      // The no-identity case has to stay byte-identical to what was
      // verified against real SSI imports.
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2025, 11, 7, 10, 50),
          maxDepthMeters: 28,
          duration: const Duration(minutes: 54),
        ),
      );

      expect(
        payload,
        'dive;noid;dive_type:0;datetime:202511071050;divetime:54.0;depth_m:28.0',
      );
    });

    test('never emits fields whose SSI code tables are unknown', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          maxDepthMeters: 28,
          duration: const Duration(minutes: 54),
          waterTemperatureCelsius: 22,
        ),
        diver: const SsiBuddyCode(memberId: '3902893'),
      );

      for (final guessed in const [
        'site:',
        'var_weather_id',
        'var_entry_id',
        'var_water_body_id',
        'var_watertype_id',
        'var_current_id',
        'var_surface_id',
        'var_divetype_id',
        'airtemp_c',
        'vis_m',
        'user_leader_id',
      ]) {
        expect(
          payload,
          isNot(contains(guessed)),
          reason:
              '$guessed would have to be invented, and a wrong value '
              'lands silently in the logbook',
        );
      }
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
