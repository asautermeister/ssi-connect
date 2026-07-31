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
