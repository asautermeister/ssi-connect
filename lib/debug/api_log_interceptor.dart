import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_log.dart';

/// Records Garmin API traffic into [ApiLog] for on-device debugging.
///
/// Everything logged here passes through [_redact] first: this traffic
/// carries the account password and access tokens, and the whole point of
/// the log is that it gets read off a screen and shared, so secrets must
/// never reach it in the first place.
class ApiLogInterceptor extends Interceptor {
  const ApiLogInterceptor();

  /// Keys whose values are secrets, matched case-insensitively.
  ///
  /// `p` and `token` are SSI's names for the account password and the
  /// session token in its app API - short, but exactly as sensitive as
  /// Garmin's spelled-out ones.
  static const _secretKeys = {
    'password',
    'p',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'jwt',
    'service_ticket',
    'serviceticketid',
    'authorization',
    'cookie',
    'set-cookie',
    'mfaverificationcode',
    'csrf',
    '_csrf',
  };

  /// Below this length a key is only matched as a whole map key, never
  /// inside free text. Scrubbing `p` textually would redact the value of
  /// anything ending in "p" - `"temp":26` among them.
  static const _minTextScrubKeyLength = 3;

  static const _maxBodyChars = 1200;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ApiLog.instance.add(
      ApiLogEntry(
        timestamp: DateTime.now(),
        method: response.requestOptions.method,
        url: _fullUrl(response.requestOptions),
        statusCode: response.statusCode,
        requestBody: _redact(response.requestOptions.data),
        responseBody: _redact(response.data),
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiLog.instance.add(
      ApiLogEntry(
        timestamp: DateTime.now(),
        method: err.requestOptions.method,
        url: _fullUrl(err.requestOptions),
        statusCode: err.response?.statusCode,
        requestBody: _redact(err.requestOptions.data),
        responseBody: _redact(err.response?.data),
        error: '${err.type.name}: ${err.message ?? ''}',
      ),
    );
    handler.next(err);
  }

  String _fullUrl(RequestOptions options) {
    final query = options.queryParameters.isEmpty
        ? ''
        : '?${options.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return '${options.uri.origin}${options.uri.path}$query';
  }

  @visibleForTesting
  String? redactForTest(Object? body) => _redact(body);

  String? _redact(Object? body) {
    if (body == null) return null;
    final sanitized = _sanitize(body);
    var text = sanitized is String ? sanitized : jsonEncode(sanitized);
    if (text.length > _maxBodyChars) {
      text = '${text.substring(0, _maxBodyChars)}… (gekürzt)';
    }
    return text;
  }

  Object? _sanitize(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _isSecret(entry.key.toString())
              ? '***'
              : _sanitize(entry.value),
      };
    }
    if (value is List) return value.map(_sanitize).toList();
    if (value is String) return _sanitizeString(value);
    return value;
  }

  /// Bodies are not always structured - Garmin returns HTML challenge pages
  /// and form-encoded payloads too, so scrub those textually as well.
  String _sanitizeString(String value) {
    var result = value;
    for (final key in _secretKeys) {
      if (key.length < _minTextScrubKeyLength) continue;
      result = result.replaceAllMapped(
        RegExp('($key"?\\s*[:=]\\s*"?)[^",&}\\s]+', caseSensitive: false),
        (match) => '${match.group(1)}***',
      );
    }
    return result;
  }

  bool _isSecret(String key) => _secretKeys.contains(key.toLowerCase());
}
