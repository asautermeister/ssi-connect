import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';

void main() {
  group('SsiBuddyCode.tryParse', () {
    test('parses a real payload from the SSI app', () {
      final code = SsiBuddyCode.tryParse(
        'buddy;3902893;firstName:Andreas;lastName:Sautermeister;'
        'email:asautermeister@gmail.com',
      );

      expect(code, isNotNull);
      expect(code!.memberId, '3902893');
      expect(code.firstName, 'Andreas');
      expect(code.lastName, 'Sautermeister');
      expect(code.email, 'asautermeister@gmail.com');
      expect(code.fullName, 'Andreas Sautermeister');
    });

    test('accepts a code carrying only the member id', () {
      final code = SsiBuddyCode.tryParse('buddy;123456');

      expect(code, isNotNull);
      expect(code!.memberId, '123456');
      expect(code.fullName, isNull);
      expect(code.email, isNull);
    });

    test('is tolerant of casing, spacing and unknown fields', () {
      final code = SsiBuddyCode.tryParse(
        ' BUDDY ; 42 ; FirstName: Ada ; nickname:Ace ',
      );

      expect(code, isNotNull);
      expect(code!.memberId, '42');
      expect(code.firstName, 'Ada');
      expect(code.lastName, isNull);
    });

    test('keeps an email intact despite its own separator character', () {
      // The colon split has to take only the first colon, or a value
      // containing one would be truncated.
      final code = SsiBuddyCode.tryParse('buddy;7;email:a:b@example.com');

      expect(code!.email, 'a:b@example.com');
    });

    test('rejects payloads that are not buddy codes', () {
      // A dive payload - same separator style, different marker.
      expect(
        SsiBuddyCode.tryParse('dive;noid;dive_type:0;depth_m:28.0'),
        isNull,
      );
      expect(SsiBuddyCode.tryParse('https://example.com'), isNull);
      expect(SsiBuddyCode.tryParse('buddy'), isNull);
      expect(SsiBuddyCode.tryParse(''), isNull);
    });

    test('rejects a code whose id slot is missing', () {
      expect(SsiBuddyCode.tryParse('buddy;;firstName:Ada'), isNull);
      // Second segment is a key:value pair, so the id is absent.
      expect(SsiBuddyCode.tryParse('buddy;firstName:Ada'), isNull);
    });

    test('treats empty field values as absent', () {
      final code = SsiBuddyCode.tryParse('buddy;9;firstName:;email:');

      expect(code!.firstName, isNull);
      expect(code.email, isNull);
    });
  });
}
