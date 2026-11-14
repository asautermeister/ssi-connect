import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_loader.dart';
import 'package:ssi_connect/garmin/garmin_activity_client.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';

void main() {
  test('a signed-out account sends nothing and asks for a sign-in', () async {
    // What is left after a key is removed. An empty bearer token sent to
    // Garmin would only come back 401 - and a refresh attempt has nothing
    // to refresh from.
    var requests = 0;
    var refreshes = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final loader = GarminDiveLoader(
      client: GarminActivityClient(dio: dio),
      refreshSession: (_) async {
        refreshes++;
        return const GarminSession.none();
      },
    );

    final account = GarminAccount(
      id: 'a',
      email: 'a@example.com',
      displayName: 'Andreas',
      session: const GarminSession.none(),
    );

    await expectLater(
      loader.load(account),
      throwsA(
        isA<GarminAuthException>().having(
          (e) => e.type,
          'type',
          GarminAuthErrorType.invalidCredentials,
        ),
      ),
    );
    expect(requests, 0);
    expect(refreshes, 0);
  });
}
