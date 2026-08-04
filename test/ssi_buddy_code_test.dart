import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings_de.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';

const _s = AppStringsDe();

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

    test('reads the leader number from a professional\'s code', () {
      // Real code from an SSI divemaster: same shape as any other member,
      // plus one field.
      final code = SsiBuddyCode.tryParse(
        'buddy;3154225;firstName:Thomas;lastName:Burger;'
        'email:burgerthomas2507@gmail.com;leaderNr:110890',
      );

      expect(code!.memberId, '3154225');
      expect(code.leaderNumber, '110890');
      expect(code.isProfessional, isTrue);
    });

    test('an ordinary member has no leader number', () {
      final code = SsiBuddyCode.tryParse('buddy;3902893;firstName:Andreas');

      expect(code!.leaderNumber, isNull);
      expect(code.isProfessional, isFalse);
    });

    test('treats empty field values as absent', () {
      final code = SsiBuddyCode.tryParse('buddy;9;firstName:;email:');

      expect(code!.firstName, isNull);
      expect(code.email, isNull);
    });
  });

  group('SsiBuddyCode.toPayload', () {
    test('writes the code SSI itself shows, so it can be scanned back', () {
      const code = SsiBuddyCode(
        memberId: '3902893',
        firstName: 'Andreas',
        lastName: 'Sautermeister',
        email: 'a@example.com',
      );

      expect(
        code.toPayload(),
        'buddy;3902893;firstName:Andreas;lastName:Sautermeister;'
        'email:a@example.com',
      );
    });

    test('round-trips through its own parser', () {
      for (final code in const [
        SsiBuddyCode(memberId: '1', firstName: 'Ada'),
        SsiBuddyCode(memberId: '2', lastName: 'Lovelace'),
        SsiBuddyCode(memberId: '3', email: 'a:b@example.com'),
        SsiBuddyCode(memberId: '4'),
        SsiBuddyCode(memberId: '5', firstName: 'Cy', leaderNumber: '110890'),
      ]) {
        final parsed = SsiBuddyCode.tryParse(code.toPayload());

        expect(parsed, isNotNull, reason: code.toPayload());
        expect(parsed!.memberId, code.memberId);
        expect(parsed.firstName, code.firstName);
        expect(parsed.lastName, code.lastName);
        expect(parsed.email, code.email);
        expect(parsed.leaderNumber, code.leaderNumber);
      }
    });

    test('hands a divemaster on exactly as scanned', () {
      // Showing a scanned code again must not quietly drop a field - the
      // next device would then store a poorer copy than we were given.
      const original =
          'buddy;3154225;firstName:Thomas;lastName:Burger;'
          'email:burgerthomas2507@gmail.com;leaderNr:110890';

      expect(SsiBuddyCode.tryParse(original)!.toPayload(), original);
    });

    test('leaves absent fields out instead of writing them empty', () {
      // `firstName:` with nothing after it parses back as an empty string
      // on a stricter reader.
      expect(const SsiBuddyCode(memberId: '9').toPayload(), 'buddy;9');
    });
  });

  group('SsiBuddyCode storage', () {
    test('survives a JSON round trip with every field', () {
      const original = SsiBuddyCode(
        memberId: '3902893',
        firstName: 'Andreas',
        lastName: 'Sautermeister',
        email: 'a@example.com',
      );

      final restored = SsiBuddyCode.fromJson(original.toJson());

      expect(restored.memberId, original.memberId);
      expect(restored.firstName, original.firstName);
      expect(restored.lastName, original.lastName);
      expect(restored.email, original.email);
    });

    test('keeps the leader number across a JSON round trip', () {
      final restored = SsiBuddyCode.fromJson(
        const SsiBuddyCode(
          memberId: '3154225',
          leaderNumber: '110890',
        ).toJson(),
      );

      expect(restored.leaderNumber, '110890');
    });

    test('survives a JSON round trip with only the member number', () {
      final restored = SsiBuddyCode.fromJson(
        const SsiBuddyCode(memberId: '42').toJson(),
      );

      expect(restored.memberId, '42');
      expect(restored.fullName, isNull);
      expect(restored.email, isNull);
    });

    test('identifies a member by their number, not by their name', () {
      // Rescanning someone whose name is spelled differently has to update
      // the existing entry rather than add a second one.
      expect(
        const SsiBuddyCode(memberId: '1', firstName: 'Ada'),
        const SsiBuddyCode(memberId: '1', firstName: 'A.'),
      );
      expect(
        const SsiBuddyCode(memberId: '1', firstName: 'Ada'),
        isNot(const SsiBuddyCode(memberId: '2', firstName: 'Ada')),
      );
    });

    test('names someone by their number when no name is known', () {
      expect(const SsiBuddyCode(memberId: '42').displayName(_s), 'SSI-Nr. 42');
      expect(
        const SsiBuddyCode(memberId: '42', firstName: 'Ada').displayName(_s),
        'Ada',
      );
    });

    test('does not repeat the number as a second line under itself', () {
      // Titled "SSI-Nr. 42" already - a subtitle saying the same is noise.
      expect(const SsiBuddyCode(memberId: '42').memberIdLine(_s), isNull);
      expect(
        const SsiBuddyCode(memberId: '42', firstName: 'Ada').memberIdLine(_s),
        'SSI-Nr. 42',
      );
    });

    test('labels a professional with SSI\'s own term', () {
      // "SSI Professional" is what SSI calls the rank; the wire key
      // `leaderNr` is not what a diver sees printed on their card.
      expect(
        const SsiBuddyCode(
          memberId: '3154225',
          leaderNumber: '110890',
        ).professionalNumberLine(_s),
        'SSI Professional Nr. 110890',
      );
      expect(
        const SsiBuddyCode(memberId: '42').professionalNumberLine(_s),
        isNull,
      );
    });
  });
}
