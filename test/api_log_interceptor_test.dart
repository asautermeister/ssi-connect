import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/debug/api_log_interceptor.dart';

/// The API log is meant to be read off a phone screen and pasted into a
/// chat, so credentials must never survive into it.
void main() {
  group('ApiLogInterceptor redaction', () {
    const interceptor = ApiLogInterceptor();

    String redact(Object? body) => interceptor.redactForTest(body) ?? '';

    test('removes the password from a login body', () {
      final text = redact({
        'username': 'diver@example.com',
        'password': 'sehr-geheim',
        'rememberMe': true,
      });

      expect(text, isNot(contains('sehr-geheim')));
      expect(text, contains('diver@example.com'));
      expect(text, contains('***'));
    });

    test('removes tokens from a token response', () {
      final text = redact({
        'access_token': 'eyJhbGciOi.secret.value',
        'refresh_token': 'rt-secret',
        'expires_in': 3600,
      });

      expect(text, isNot(contains('eyJhbGciOi.secret.value')));
      expect(text, isNot(contains('rt-secret')));
      expect(text, contains('3600'));
    });

    test('removes the MFA code', () {
      final text = redact({'mfaVerificationCode': '500231', 'mfaSetup': false});

      expect(text, isNot(contains('500231')));
    });

    test('scrubs secrets inside unstructured text bodies', () {
      final text = redact('username=diver&password=sehr-geheim&embed=true');

      expect(text, isNot(contains('sehr-geheim')));
      expect(text, contains('diver'));
    });

    test("removes SSI's short names for the password and the token", () {
      // SSI's app API calls them `p` and `token`. Short, and exactly as
      // sensitive as Garmin's spelled-out ones.
      final text = redact({
        'l': 'diver@example.com',
        'p': 'sehr-geheim',
        'what': 'authenticate',
      });

      expect(text, isNot(contains('sehr-geheim')));
      expect(text, contains('diver@example.com'));
      expect(redact({'token': 'abc123'}), isNot(contains('abc123')));
    });

    test('a one-letter key does not redact half the response', () {
      // Scrubbing `p` textually would hit anything ending in "p" followed
      // by a colon - `"temp":26` among them, which would quietly gut the
      // dive data the log exists to show.
      final text = redact('{"temp":26,"depth_m":12.8,"bow":"salt"}');

      expect(text, contains('26'));
      expect(text, contains('12.8'));
    });

    test('redacts nested values', () {
      final text = redact({
        'responseStatus': {'type': 'SUCCESSFUL'},
        'data': {'access_token': 'nested-secret'},
      });

      expect(text, isNot(contains('nested-secret')));
      expect(text, contains('SUCCESSFUL'));
    });

    test("a buddy's personal data does not reach the log", () {
      // The real shape of one logbook_buddies entry. The log is built to
      // be copied out and pasted somewhere - the import already drops date
      // of birth, city, phone and photo on purpose, and the log must not
      // become the way they leave the device instead.
      final text = redact({
        'logbook_buddies': [
          {
            'buddy_master_id': 3902893,
            'firstname': 'Andreas',
            'lastname': 'Sautermeister',
            'email': 'andreas@example.com',
            'dob': '1984-04-10',
            'city': 'Oberhaching',
            'phone': '+49 170 1234567',
            'image': 'https://my.divessi.com/img/3902893.png',
            'deleted': 0,
          },
        ],
      });

      for (final personal in const [
        'Andreas',
        'Sautermeister',
        'andreas@example.com',
        '1984-04-10',
        'Oberhaching',
        '1234567',
        '3902893.png',
      ]) {
        expect(text, isNot(contains(personal)), reason: personal);
      }

      // The shape still has to be readable, or the log stops being useful:
      // which fields came back, and the member number that identifies the
      // entry without naming anybody.
      expect(text, contains('firstname'));
      expect(text, contains('buddy_master_id'));
      expect(text, contains('3902893'));
      expect(text, contains('deleted'));
    });

    test('dive values are not mistaken for personal data', () {
      final text = redact({
        'maxDepth': 1149.3,
        'locationName': 'Zakynthos',
        'minTemperature': 22.0,
      });

      expect(text, contains('1149.3'));
      expect(text, contains('Zakynthos'));
      expect(text, contains('22'));
    });
  });
}
