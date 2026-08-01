import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_payload_fields.dart';

void main() {
  group('SsiPayloadFields.parse', () {
    test('splits a real SSI dive export into marker, positions and fields', () {
      final payload = SsiPayloadFields.parse(
        'dive;noid;dive_type:2;divetime:92.0;datetime:202511080856;'
        'depth_m:44.0;site:1074;var_watertype_id:5;user_leader_id:',
      );

      expect(payload.marker, 'dive');
      expect(payload.positional, ['noid']);
      expect(payload.fields['dive_type'], '2');
      expect(payload.fields['site'], '1074');
      // An empty value still has to show up - a field SSI writes but leaves
      // blank is exactly the kind of thing worth seeing when diagnosing.
      expect(payload.fields.containsKey('user_leader_id'), isTrue);
      expect(payload.fields['user_leader_id'], '');
    });

    test('splits a member code, whose id is positional', () {
      final payload = SsiPayloadFields.parse(
        'buddy;3902893;firstName:Andreas;lastName:Sautermeister',
      );

      expect(payload.marker, 'buddy');
      expect(payload.positional, ['3902893']);
      expect(payload.fields['firstName'], 'Andreas');
    });

    test('keeps colons inside a value, splitting only at the first one', () {
      final payload = SsiPayloadFields.parse('buddy;7;email:a:b@example.com');

      expect(payload.fields['email'], 'a:b@example.com');
    });

    test('preserves field order for reading a payload top to bottom', () {
      final payload = SsiPayloadFields.parse('dive;noid;b:2;a:1;c:3');

      expect(payload.fields.keys, ['b', 'a', 'c']);
    });

    test('handles a payload that is not an SSI code at all', () {
      final payload = SsiPayloadFields.parse('https://example.com/x');

      expect(payload.marker, 'https://example.com/x');
      expect(payload.positional, isEmpty);
      expect(payload.fields, isEmpty);
    });

    test('ignores the empty segment a trailing semicolon leaves', () {
      final payload = SsiPayloadFields.parse('dive;noid;');

      expect(payload.positional, ['noid']);
    });
  });
}
