import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import 'garmin_auth_exceptions.dart';
import 'models/garmin_session.dart';

/// Logs in to Garmin Connect using the same unofficial (reverse-engineered)
/// SSO flow that community tools like `python-garminconnect` use, since
/// Garmin does not offer a public consumer API.
///
/// Deliberately NOT implemented here, unlike some of those reference tools:
/// TLS-fingerprint spoofing, headers that impersonate a specific installed
/// copy of Garmin's own app, and randomised anti-bot-detection delays. That
/// makes this client less resilient to Cloudflare/WAF challenges - login
/// can fail even with correct credentials. Treat [GarminAuthException] as
/// "try again later, or use the manual FIT-file import instead", not as a
/// bug to silently retry around.
///
/// The exact request/response shapes were taken from the current
/// `python-garminconnect` source (mobile-login strategy). Field names and
/// endpoints are not officially documented and may need adjusting once
/// tested against a real account.
class GarminAuthClient {
  GarminAuthClient({Dio? dio, this._domain = 'garmin.com'})
    : _dio = dio ?? Dio() {
    // Garmin ties an MFA challenge to the session that started the login:
    // /mobile/api/mfa/verifyCode only accepts the code when the SSO cookies
    // set during /mobile/api/login are sent back with it, otherwise it
    // answers 409. So every request from this client shares one cookie jar,
    // and login + completeMfa must run on the *same* client instance.
    _dio.interceptors.add(CookieManager(CookieJar()));
    _dio.interceptors.add(const ApiLogInterceptor());
  }

  final Dio _dio;
  final String _domain;

  String get _ssoBase => 'https://sso.$_domain';
  String get _iosServiceUrl => 'https://mobile.integration.$_domain/gcm/ios';
  String get _diTokenUrl =>
      'https://diauth.$_domain/di-oauth2-service/oauth/token';
  String get _diGrantType =>
      'https://connectapi.$_domain/di-oauth2-service/oauth/grant/service_ticket';

  static const _iosClientId = 'GCM_IOS_DARK';

  // Garmin's DI token endpoint accepts a fixed set of known client IDs; an
  // invented one is simply rejected, so this is an API parameter (like an
  // API key) rather than a spoofed device identity.
  static const _diClientIds = [
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4',
    'GARMIN_CONNECT_MOBILE_ANDROID_DI',
    'GARMIN_CONNECT_MOBILE_IOS_DI',
  ];

  // Generic mobile-Safari UA for the SSO login page - identifies us as "some
  // mobile browser", not as a specific device/app the way the reference
  // implementation's X-Garmin-User-Agent header does.
  static const _mobileLoginUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  // Our own, honest identification for calls we make directly (not through
  // a browser-shaped endpoint).
  static const _appUserAgent = 'ssi-connect/1.0 (+personal dive log tool)';

  Future<GarminLoginResult> login({
    required String email,
    required String password,
  }) async {
    final params = {
      'clientId': _iosClientId,
      'locale': 'en-US',
      'service': _iosServiceUrl,
    };

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_ssoBase/mobile/api/login',
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent': _mobileLoginUserAgent,
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Origin': _ssoBase,
          },
        ),
        data: {
          'username': email,
          'password': password,
          'rememberMe': true,
          'captchaToken': '',
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e, context: 'Login');
    }

    return _handleLoginResponse(
      response,
      clientId: _iosClientId,
      serviceUrl: _iosServiceUrl,
    );
  }

  Future<GarminSession> completeMfa({
    required GarminMfaContext context,
    required String code,
  }) async {
    final params = {
      'clientId': context.clientId,
      'locale': 'en-US',
      'service': context.serviceUrl,
    };

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_ssoBase/mobile/api/mfa/verifyCode',
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent': _mobileLoginUserAgent,
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Origin': _ssoBase,
          },
        ),
        data: {
          'mfaMethod': context.mfaMethod,
          'mfaVerificationCode': code,
          'rememberMyBrowser': true,
          'reconsentList': <String>[],
          'mfaSetup': false,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e, context: 'MFA-Bestätigung');
    }

    final result = await _handleLoginResponse(
      response,
      clientId: context.clientId,
      serviceUrl: context.serviceUrl,
    );
    if (result is GarminLoginSuccess) {
      return result.session;
    }
    // The mobile login flow doesn't ask for MFA twice in a row.
    throw GarminAuthException(
      GarminAuthErrorType.connectionError,
      'Unerwartete Antwort nach MFA-Bestätigung.',
    );
  }

  Future<GarminSession> refresh(GarminSession session) async {
    if (session.refreshToken == null) {
      throw GarminAuthException(
        GarminAuthErrorType.invalidCredentials,
        'Keine Refresh-Information vorhanden - bitte erneut einloggen.',
      );
    }
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        _diTokenUrl,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _nativeHeaders({
            'Authorization': _basicAuth(session.diClientId),
            'Accept': 'application/json',
          }),
        ),
        data: {
          'grant_type': 'refresh_token',
          'client_id': session.diClientId,
          'refresh_token': session.refreshToken,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e, context: 'Token-Refresh');
    }

    final data = response.data as Map<String, dynamic>;
    return GarminSession(
      accessToken: data['access_token'] as String,
      refreshToken: (data['refresh_token'] as String?) ?? session.refreshToken,
      diClientId: session.diClientId,
    );
  }

  Future<GarminLoginResult> _handleLoginResponse(
    Response<dynamic> response, {
    required String clientId,
    required String serviceUrl,
  }) async {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Unerwartete Antwort von Garmin (HTTP ${response.statusCode}).',
      );
    }

    final type = (data['responseStatus'] as Map?)?['type'] as String?;

    switch (type) {
      case 'SUCCESSFUL':
        final ticket = data['serviceTicketId'] as String;
        final session = await _exchangeServiceTicket(ticket, serviceUrl);
        return GarminLoginSuccess(session);
      case 'MFA_REQUIRED':
        final mfaMethod =
            ((data['customerMfaInfo'] as Map?)?['mfaLastMethodUsed']
                as String?) ??
            'email';
        return GarminLoginMfaRequired(
          GarminMfaContext(
            mfaMethod: mfaMethod,
            clientId: clientId,
            serviceUrl: serviceUrl,
          ),
        );
      case 'INVALID_USERNAME_PASSWORD':
        throw GarminAuthException(
          GarminAuthErrorType.invalidCredentials,
          'Benutzername oder Passwort falsch.',
        );
      case 'CAPTCHA_REQUIRED':
        throw GarminAuthException(
          GarminAuthErrorType.connectionError,
          'Garmin verlangt ein CAPTCHA - Login von diesem Gerät/dieser '
          'Netzwerkumgebung aus gerade nicht möglich. Bitte die Tauchgänge '
          'stattdessen als FIT-Datei importieren.',
        );
      default:
        throw GarminAuthException(
          GarminAuthErrorType.connectionError,
          'Login fehlgeschlagen: unerwartete Antwort "$type".',
        );
    }
  }

  Future<GarminSession> _exchangeServiceTicket(
    String ticket,
    String serviceUrl,
  ) async {
    Object? lastError;
    for (final clientId in _diClientIds) {
      try {
        final response = await _dio.post<dynamic>(
          _diTokenUrl,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: _nativeHeaders({
              'Authorization': _basicAuth(clientId),
              'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
            }),
          ),
          data: {
            'client_id': clientId,
            'service_ticket': ticket,
            'grant_type': _diGrantType,
            'service_url': serviceUrl,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return GarminSession(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String?,
          diClientId: clientId,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          throw GarminAuthException(
            GarminAuthErrorType.rateLimited,
            'Garmin blockt gerade zu viele Login-Versuche (429). '
            'Bitte später erneut versuchen.',
          );
        }
        lastError = e;
        continue;
      }
    }
    throw GarminAuthException(
      GarminAuthErrorType.connectionError,
      'Konnte kein Zugriffs-Token von Garmin erhalten. ($lastError)',
    );
  }

  Map<String, String> _nativeHeaders(Map<String, String> extra) => {
    'User-Agent': _appUserAgent,
    'Cache-Control': 'no-cache',
    ...extra,
  };

  String _basicAuth(String clientId) {
    // Trailing colon: Garmin's endpoint expects the client id as
    // "username" with an empty password in HTTP Basic auth.
    return 'Basic ${base64Encode(utf8.encode('$clientId:'))}';
  }

  /// Turns Dio's raw transport errors into something a user can act on -
  /// the default message is a wall of HTTP-spec text that says nothing
  /// about what to do next.
  GarminAuthException _mapDioError(DioException e, {required String context}) {
    final status = e.response?.statusCode;

    if (status == 429) {
      return GarminAuthException(
        GarminAuthErrorType.rateLimited,
        '$context: Garmin hat zu viele Versuche registriert. Bitte einige '
        'Minuten warten und erneut versuchen.',
      );
    }
    if (status == 401 || status == 400) {
      return GarminAuthException(
        GarminAuthErrorType.invalidCredentials,
        '$context: Von Garmin abgelehnt - Eingabe prüfen.',
      );
    }
    if (status == 409) {
      // Garmin uses 409 here for "this code doesn't belong to a login I'm
      // currently tracking": wrong/expired code, or a login session that
      // was lost between the two steps.
      return GarminAuthException(
        GarminAuthErrorType.invalidCredentials,
        '$context: Der Code wurde nicht akzeptiert. Er ist möglicherweise '
        'abgelaufen oder gehört zu einem älteren Login-Versuch. Bitte den '
        'Login neu starten und den neuesten Code verwenden.',
      );
    }
    if (status == 403) {
      return GarminAuthException(
        GarminAuthErrorType.connectionError,
        '$context: Garmin hat die Anfrage blockiert (Bot-Schutz). Bitte '
        'später erneut versuchen oder die FIT-Datei importieren.',
      );
    }
    if (isOfflineDioError(e)) {
      return GarminAuthException(
        GarminAuthErrorType.offline,
        '$context: Keine Verbindung zu Garmin. Internetverbindung prüfen.',
      );
    }
    return GarminAuthException(
      GarminAuthErrorType.connectionError,
      '$context fehlgeschlagen'
      '${status != null ? ' (HTTP $status)' : ''}.',
      details: ApiLog.instance.enabled
          ? '${e.requestOptions.method} ${e.requestOptions.uri}\n'
                'Antwort: ${e.response?.data}'
          : null,
    );
  }
}
