import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_center_code.dart';

void main() {
  group('SsiCenterCode.tryParse', () {
    test('parses a real payload from the SSI app', () {
      final code = SsiCenterCode.tryParse(
        'center;718019;name:Nero-Sport Diving Center, Zakynthos',
      );

      expect(code, isNotNull);
      expect(code!.centerId, '718019');
      // The comma belongs to the name - only the semicolon separates
      // fields, so splitting any further would truncate the base.
      expect(code.name, 'Nero-Sport Diving Center, Zakynthos');
      expect(code.displayName, 'Nero-Sport Diving Center, Zakynthos');
    });

    test('accepts a code carrying only the centre number', () {
      final code = SsiCenterCode.tryParse('center;718019');

      expect(code, isNotNull);
      expect(code!.centerId, '718019');
      expect(code.name, isNull);
      expect(code.displayName, 'Basis-Nr. 718019');
    });

    test('is tolerant of casing, spacing and unknown fields', () {
      final code = SsiCenterCode.tryParse(
        ' CENTER ; 42 ; Name: Blue Hole ; x:1',
      );

      expect(code, isNotNull);
      expect(code!.centerId, '42');
      expect(code.name, 'Blue Hole');
    });

    test('rejects payloads that are not centre codes', () {
      // A member code and a dive - same separator style, other markers.
      expect(SsiCenterCode.tryParse('buddy;3902893;firstName:Andreas'), isNull);
      expect(SsiCenterCode.tryParse('dive;noid;dive_type:0'), isNull);
      expect(SsiCenterCode.tryParse('https://example.com'), isNull);
      expect(SsiCenterCode.tryParse('center'), isNull);
      expect(SsiCenterCode.tryParse(''), isNull);
    });

    test('rejects a code whose number slot is missing', () {
      expect(SsiCenterCode.tryParse('center;;name:Blue Hole'), isNull);
      // Second segment is a key:value pair, so the number is absent.
      expect(SsiCenterCode.tryParse('center;name:Blue Hole'), isNull);
    });

    test('the two code types do not accept each other', () {
      const center = 'center;718019;name:Nero-Sport';
      const buddy = 'buddy;3902893;firstName:Andreas';

      expect(SsiBuddyCode.tryParse(center), isNull);
      expect(SsiCenterCode.tryParse(buddy), isNull);
      expect(SsiCenterCode.tryParse(center), isNotNull);
      expect(SsiBuddyCode.tryParse(buddy), isNotNull);
    });
  });

  group('SsiCenterCode.toPayload', () {
    test('hands a centre on exactly as scanned', () {
      // Showing a scanned code again must not alter it - the next device
      // would then store something SSI never wrote.
      const original = 'center;718019;name:Nero-Sport Diving Center, Zakynthos';

      expect(SsiCenterCode.tryParse(original)!.toPayload(), original);
    });

    test('leaves an absent name out instead of writing it empty', () {
      expect(
        const SsiCenterCode(centerId: '718019').toPayload(),
        'center;718019',
      );
    });
  });

  group('SsiCenterCode storage', () {
    test('survives a JSON round trip', () {
      const original = SsiCenterCode(centerId: '718019', name: 'Nero-Sport');
      final restored = SsiCenterCode.fromJson(original.toJson());

      expect(restored.centerId, '718019');
      expect(restored.name, 'Nero-Sport');
    });

    test('survives a JSON round trip without a name', () {
      final restored = SsiCenterCode.fromJson(
        const SsiCenterCode(centerId: '42').toJson(),
      );

      expect(restored.centerId, '42');
      expect(restored.name, isNull);
    });

    test('identifies a centre by its number, not by its name', () {
      // Rescanning a base whose name is written differently has to update
      // the existing entry rather than add a second one.
      expect(
        const SsiCenterCode(centerId: '1', name: 'Nero-Sport'),
        const SsiCenterCode(centerId: '1', name: 'Nero Sport'),
      );
      expect(
        const SsiCenterCode(centerId: '1', name: 'Nero-Sport'),
        isNot(const SsiCenterCode(centerId: '2', name: 'Nero-Sport')),
      );
    });

    test('does not repeat the number as a second line under itself', () {
      expect(const SsiCenterCode(centerId: '42').centerIdLine, isNull);
      expect(
        const SsiCenterCode(centerId: '42', name: 'Blue Hole').centerIdLine,
        'Basis-Nr. 42',
      );
    });
  });
}
