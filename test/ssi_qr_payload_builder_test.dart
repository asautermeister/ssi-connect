import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';
import 'package:ssi_connect/models/water_type.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_qr_payload_builder.dart';

Dive _dive({
  DateTime? dateTime,
  double? maxDepthMeters,
  Duration? duration,
  double? waterTemperatureCelsius,
  DiveWaterType? waterType,
  DiveType type = DiveType.scuba,
}) {
  return Dive(
    id: '1',
    dateTime: dateTime ?? DateTime(2019, 7, 21, 10, 0),
    maxDepthMeters: maxDepthMeters,
    avgDepthMeters: null,
    waterTemperatureCelsius: waterTemperatureCelsius,
    duration: duration,
    locationName: null,
    waterType: waterType,
    type: type,
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

    test('reproduces a real recreational SSI export, field for field', () {
      // Real QR export from the SSI app, recreational scuba:
      // dive;noid;dive_type:0;divetime:54.0;datetime:202511071050;
      // depth_m:28.0;site:303948;var_watertype_id:5;var_divetype_id:24;
      // var_divetype_id:24;user_master_id:3902893;user_firstname:Andreas;
      // user_lastname:Sautermeister;user_leader_id:
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2025, 11, 7, 10, 50),
          maxDepthMeters: 28.0,
          duration: const Duration(minutes: 54),
        ),
        diver: const SsiBuddyCode(
          memberId: '3902893',
          firstName: 'Andreas',
          lastName: 'Sautermeister',
        ),
      );

      for (final field in const [
        'dive_type:0',
        'datetime:202511071050',
        'divetime:54.0',
        'depth_m:28.0',
        'user_master_id:3902893',
        'user_firstname:Andreas',
        'user_lastname:Sautermeister',
      ]) {
        expect(payload, contains(field));
      }
    });

    test('reproduces a real XR export, which differs only in dive_type', () {
      // Same logbook, extended-range dive:
      // dive;noid;dive_type:2;divetime:75.0;datetime:202511060853;
      // depth_m:46.4;site:202305;... (same tail)
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2025, 11, 6, 8, 53),
          maxDepthMeters: 46.4,
          duration: const Duration(minutes: 75),
          type: DiveType.multiGas,
        ),
      );

      expect(payload, contains('dive_type:2'));
      expect(payload, contains('datetime:202511060853'));
      expect(payload, contains('divetime:75.0'));
      expect(payload, contains('depth_m:46.4'));
    });

    test('reproduces the fresh-water export, which differs in one field', () {
      // Same logbook again, this time a lake dive - the export that told us
      // what var_watertype_id means:
      // dive;noid;dive_type:0;divetime:38.0;datetime:202509061328;
      // depth_m:13.0;site:214234;var_watertype_id:4;... (same tail)
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          dateTime: DateTime(2025, 9, 6, 13, 28),
          maxDepthMeters: 13.0,
          duration: const Duration(minutes: 38),
          waterType: DiveWaterType.fresh,
        ),
      );

      expect(payload, contains('var_watertype_id:4'));
      expect(payload, contains('datetime:202509061328'));
      expect(payload, contains('depth_m:13.0'));
    });

    test('salt water is the other captured value', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(
          maxDepthMeters: 28,
          duration: const Duration(minutes: 54),
          waterType: DiveWaterType.salt,
        ),
      );

      expect(payload, contains('var_watertype_id:5'));
    });

    test('an unreported water type leaves the field out entirely', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(maxDepthMeters: 28, duration: const Duration(minutes: 54)),
      );

      // Not defaulting to salt: a lake dive filed as a sea dive would be
      // wrong, and an absent field simply isn't imported.
      expect(payload, isNot(contains('var_watertype_id')));
    });

    test('files multi-gas and rebreather dives as XR, the rest as normal', () {
      int diveTypeOf(DiveType type) {
        final payload = SsiQrPayloadBuilder.build(
          _dive(
            maxDepthMeters: 20,
            duration: const Duration(minutes: 40),
            type: type,
          ),
        );
        final match = RegExp(r'dive_type:(\d+)').firstMatch(payload);
        return int.parse(match!.group(1)!);
      }

      // A stage or deco cylinder is what makes a dive technical, and a
      // closed-circuit rebreather is technical by the same measure.
      expect(diveTypeOf(DiveType.multiGas), 2);
      expect(diveTypeOf(DiveType.rebreather), 2);

      expect(diveTypeOf(DiveType.scuba), 0);
      expect(diveTypeOf(DiveType.singleGas), 0);
      // No captured freedive export, so this stays at the value we have
      // seen SSI accept rather than at an invented freediving code.
      expect(diveTypeOf(DiveType.apnea), 0);
    });

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
