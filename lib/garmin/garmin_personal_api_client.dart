import 'dart:convert';

import 'package:dio/dio.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import 'garmin_auth_exceptions.dart';
import 'models/garmin_session.dart';

/// Talks to Garmin's official Personal API: turns a member's own API key
/// into an access token, and says whose key it is.
///
/// ## Why this exists next to [GarminAuthClient]
///
/// Garmin opened a Personal tier of its Connect Developer Program on
/// 2026-10-21: free, read-only, one's own data, pull. It replaces nothing
/// by itself - the activity endpoints behind it are the very same paths the
/// SSO login reaches, confirmed field by field against a real account - but
/// it removes the reason to reverse-engineer a login at all.
///
/// What a key buys over a password:
///
/// - Nobody types their Garmin password into somebody else's tablet. Each
///   diver creates their own key, read-only and revocable, in their own
///   account.
/// - No SSO form, no MFA dance, no Cloudflare challenge - the whole class
///   of failure [GarminAuthClient] warns about disappears.
///
/// What it costs: the key expires after a year at most and has to be
/// replaced by hand, and the answer carries no running dive number (checked
/// - it is in neither the list nor the detail response).
class GarminPersonalApiClient {
  /// [domain] is public, unlike its counterpart on [GarminActivityClient]:
  /// a private named parameter cannot be passed from another library, so
  /// that one cannot actually be pointed at a test host.
  GarminPersonalApiClient({Dio? dio, this.domain = 'garmin.com'})
    : _dio = dio ?? Dio() {
    _dio.interceptors.add(const ApiLogInterceptor());
  }

  final Dio _dio;

  /// The Garmin domain to talk to. Public so a test can point it
  /// elsewhere.
  final String domain;

  String get _base => 'https://${GarminApi.personal.subdomain}.$domain';

  static const _tokenPath =
      '/personalapitoken-service/personal-api/personal-api-key/token';
  static const _profilePath = '/userprofile-service/userprofile/settings';

  /// A new access token for [key].
  ///
  /// The answer is the raw JWT as **text**, not JSON - asking for
  /// `application/json` here is answered with 406. Its `exp` claim carries
  /// the expiry, which is how [GarminSession.tokenExpiresAt] is filled;
  /// there is no refresh token, so a stale token means asking again with
  /// the same key.
  Future<GarminSession> exchange(String key) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_base$_tokenPath',
        options: Options(
          headers: {'Accept': '*/*', 'Authorization': 'ApiKey $key'},
          responseType: ResponseType.plain,
        ),
      );
    } on DioException catch (e) {
      throw _mapError(e, 'Schlüssel');
    }

    final token = (response.data as Object?)?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Garmin hat kein Token zum Schlüssel geliefert.',
      );
    }

    return GarminSession.personal(
      accessToken: token,
      key: key,
      tokenExpiresAt: _expiryOf(token),
    );
  }

  /// The display name and mail address of whoever the key belongs to.
  ///
  /// Used to name the account and - more to the point - to catch a key
  /// pasted into the wrong person's entry before it silently starts
  /// loading a stranger's dives.
  Future<({String? displayName, String? email})> profile(
    GarminSession session,
  ) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '$_base$_profilePath',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );
    } on DioException catch (e) {
      throw _mapError(e, 'Profil');
    }

    final data = response.data;
    if (data is! Map) {
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Unerwartete Antwort beim Laden des Garmin-Profils.',
      );
    }
    final map = data.cast<String, dynamic>();
    String? text(String key) {
      final value = map[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return (
      displayName: text('displayName') ?? text('fullName'),
      email: text('userName') ?? text('emailAddress'),
    );
  }

  /// The `exp` claim of a JWT, or null if it cannot be read.
  ///
  /// Null rather than a guess: without an expiry the session simply relies
  /// on the retry that already follows a rejected token, which is one
  /// wasted request rather than a wrong assumption.
  static DateTime? _expiryOf(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = base64Url.decode(base64Url.normalize(parts[1]));
      final claims = jsonDecode(utf8.decode(payload));
      if (claims is! Map) return null;
      final exp = claims['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    } on Object {
      return null;
    }
  }

  GarminAuthException _mapError(DioException e, String what) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return GarminAuthException(
        GarminAuthErrorType.invalidCredentials,
        'Garmin hat den Personal API Key abgelehnt. Er ist vermutlich '
        'abgelaufen oder wurde gelöscht - bitte einen neuen hinterlegen.',
      );
    }
    if (status == 429) {
      return GarminAuthException(
        GarminAuthErrorType.rateLimited,
        'Zu viele Anfragen an Garmin, bitte später erneut versuchen.',
      );
    }
    if (isOfflineDioError(e)) {
      return GarminAuthException(
        GarminAuthErrorType.offline,
        'Keine Internetverbindung.',
      );
    }
    return GarminAuthException(
      GarminAuthErrorType.connectionError,
      '$what konnte nicht geladen werden'
      '${status != null ? ' (HTTP $status)' : ''}.',
      details: ApiLog.instance.enabled ? '${e.type.name}: ${e.message}' : null,
    );
  }
}

/// What a Personal API key looks like, so a paste can be checked before it
/// is sent anywhere.
///
/// Deliberately lenient: two real keys have been seen, both
/// `GCDC_<uuid>.<uuid>.<base64>.<digits>`. Requiring more than the prefix
/// and four dot-separated parts would be a rule invented from two samples -
/// and a key this rejects wrongly cannot be used at all.
abstract final class GarminPersonalKey {
  static const prefix = 'GCDC_';

  /// The key with surrounding whitespace removed, or null if it is not one.
  static String? tryParse(String raw) {
    final key = raw.trim();
    if (!key.startsWith(prefix)) return null;
    final parts = key.split('.');
    if (parts.length != 4) return null;
    if (parts.any((p) => p.isEmpty)) return null;
    return key;
  }
}
