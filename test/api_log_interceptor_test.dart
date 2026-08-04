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
  });
}
