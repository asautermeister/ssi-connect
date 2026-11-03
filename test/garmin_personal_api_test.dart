import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/garmin_personal_api_client.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';

/// Answers whatever the test says, and records what was asked.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.reply);

  final ({int status, String body, String? contentType}) Function(
    RequestOptions options,
  )
  reply;

  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final answer = reply(options);
    return ResponseBody.fromString(
      answer.body,
      answer.status,
      headers: {
        Headers.contentTypeHeader: [answer.contentType ?? 'text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(GarminPersonalApiClient, _FakeAdapter) _clientAnswering(
  ({int status, String body, String? contentType}) Function(RequestOptions)
  reply,
) {
  final adapter = _FakeAdapter(reply);
  final dio = Dio()..httpClientAdapter = adapter;
  return (GarminPersonalApiClient(dio: dio, domain: 'example.test'), adapter);
}

/// A JWT whose payload carries [exp]. Only the middle part is ever read.
String _jwt({required int exp}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.signature';
}

void main() {
  group('GarminPersonalKey', () {
    test('accepts a key in the shape Garmin issues', () {
      // The two real keys seen so far: GCDC_, then four dot-separated
      // parts. Nothing beyond that is required - the rule would be
      // invented from two samples, and a key wrongly rejected here cannot
      // be used at all.
      const key = 'GCDC_39f38091-fa09.b75c260f-5f65.poIqF07CApIq.1754132331';
      expect(GarminPersonalKey.tryParse(key), key);
      expect(GarminPersonalKey.tryParse('  $key \n'), key);
    });

    test('rejects what is clearly not one', () {
      expect(GarminPersonalKey.tryParse(''), isNull);
      expect(GarminPersonalKey.tryParse('hunter2'), isNull);
      // Right shape, wrong prefix.
      expect(GarminPersonalKey.tryParse('ABCD_a.b.c.d'), isNull);
      // Right prefix, too few parts.
      expect(GarminPersonalKey.tryParse('GCDC_a.b.c'), isNull);
      // An empty part means something was cut off in copying.
      expect(GarminPersonalKey.tryParse('GCDC_a..c.d'), isNull);
    });
  });

  group('GarminPersonalApiClient.exchange', () {
    test('asks for anything, because the answer is not JSON', () async {
      // Sending Accept: application/json here is answered with 406 - the
      // token comes back as plain text, not as an object.
      final token = _jwt(exp: 1792875369);
      final (client, adapter) = _clientAnswering(
        (_) => (status: 200, body: token, contentType: 'text/plain'),
      );

      await client.exchange('GCDC_a.b.c.d');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.headers['Accept'], '*/*');
      expect(request.headers['Authorization'], 'ApiKey GCDC_a.b.c.d');
      expect(request.uri.host, 'personal.connectapi.example.test');
      expect(
        request.uri.path,
        '/personalapitoken-service/personal-api/personal-api-key/token',
      );
    });

    test('keeps the key and reads the expiry out of the token', () async {
      final token = _jwt(exp: 1792875369);
      final (client, _) = _clientAnswering(
        (_) => (status: 200, body: token, contentType: 'text/plain'),
      );

      final session = await client.exchange('GCDC_a.b.c.d');

      expect(session.accessToken, token);
      expect(session.personalApiKey, 'GCDC_a.b.c.d');
      expect(session.isPersonal, isTrue);
      expect(session.api, GarminApi.personal);
      expect(
        session.tokenExpiresAt,
        DateTime.fromMillisecondsSinceEpoch(1792875369 * 1000, isUtc: true),
      );
      // There is no refresh token on this side; a stale token is replaced
      // by asking again with the same key.
      expect(session.refreshToken, isNull);
    });

    test('a token it cannot read has no expiry rather than a guessed one', () {
      // Without one the session falls back on the retry that already
      // follows a rejected token: one wasted request, not a wrong
      // assumption.
      final (client, _) = _clientAnswering(
        (_) => (status: 200, body: 'not-a-jwt', contentType: 'text/plain'),
      );

      expect(
        client.exchange('GCDC_a.b.c.d').then((s) => s.tokenExpiresAt),
        completion(isNull),
      );
    });

    test('a refused key reads as credentials, not as a connection fault', () {
      // It is what makes the account card offer a new key instead of
      // telling someone to check their internet.
      final (client, _) = _clientAnswering(
        (_) => (status: 401, body: 'nope', contentType: 'text/plain'),
      );

      expect(
        client.exchange('GCDC_a.b.c.d'),
        throwsA(
          isA<GarminAuthException>().having(
            (e) => e.type,
            'type',
            GarminAuthErrorType.invalidCredentials,
          ),
        ),
      );
    });

    test('an empty answer is reported, not stored as a token', () {
      final (client, _) = _clientAnswering(
        (_) => (status: 200, body: '   ', contentType: 'text/plain'),
      );

      expect(
        client.exchange('GCDC_a.b.c.d'),
        throwsA(isA<GarminAuthException>()),
      );
    });
  });

  group('GarminPersonalApiClient.profile', () {
    test('names the member the key belongs to', () async {
      final (client, adapter) = _clientAnswering(
        (_) => (
          status: 200,
          body: jsonEncode({
            'displayName': 'Andreas',
            'userName': 'andreas@example.com',
          }),
          contentType: Headers.jsonContentType,
        ),
      );

      final profile = await client.profile(
        const GarminSession.personal(accessToken: 'tok', key: 'GCDC_a.b.c.d'),
      );

      expect(profile.displayName, 'Andreas');
      expect(profile.email, 'andreas@example.com');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
      expect(
        adapter.requests.single.uri.path,
        '/userprofile-service/userprofile/settings',
      );
    });
  });

  group('GarminSession storage', () {
    test('a personal session survives a round trip', () {
      final session = GarminSession.personal(
        accessToken: 'tok',
        key: 'GCDC_a.b.c.d',
        tokenExpiresAt: DateTime.utc(2026, 11, 3, 12),
      );

      final restored = GarminSession.fromJson(session.toJson());

      expect(restored.personalApiKey, 'GCDC_a.b.c.d');
      expect(restored.accessToken, 'tok');
      expect(restored.tokenExpiresAt, DateTime.utc(2026, 11, 3, 12));
      expect(restored.isPersonal, isTrue);
    });

    test('an SSO session reads back exactly as before', () {
      // Accounts stored by an older version must not change meaning: no
      // key, so the internal interface, so a refresh token to renew with.
      const session = GarminSession(
        accessToken: 'a',
        refreshToken: 'r',
        diClientId: 'c',
      );

      final restored = GarminSession.fromJson(session.toJson());

      expect(restored.isPersonal, isFalse);
      expect(restored.api, GarminApi.internal);
      expect(restored.refreshToken, 'r');
      expect(restored.diClientId, 'c');
      expect(session.toJson().containsKey('personalApiKey'), isFalse);
    });
  });
}
