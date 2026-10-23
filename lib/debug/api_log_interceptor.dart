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

  /// Other people's personal data, matched as whole map keys only.
  ///
  /// These are not secrets - nothing breaks if they leak - but the log
  /// exists to be copied out of the app and pasted into a chat or an
  /// issue, and SSI's `logbook_buddies` answers with the name, member
  /// number, mail address, date of birth, city, telephone number and photo
  /// of every diver in the logbook.
  ///
  /// That would undo a decision the import already took: it keeps four
  /// fields and drops date of birth, address, telephone and photo on
  /// purpose, because a family tablet is no place to accumulate them. The
  /// log must not be the way they leave the device instead.
  ///
  /// Keys only, never a textual scrub: these appear in JSON answers, and
  /// scrubbing "city" or "image" through free text would mangle prose and
  /// URLs that have nothing to do with a person.
  static const _personalKeys = {
    'firstname',
    'lastname',
    'email',
    'authenticated_email',
    'dob',
    'city',
    'phone',
    'image',
    // Garmin names the account holder on every activity it returns, and
    // links three sizes of their profile photo. Their own data rather
    // than a stranger's, but the log is still something that gets pasted
    // into a chat.
    'ownerdisplayname',
    'ownerfullname',
    'ownerprofileimageurlsmall',
    'ownerprofileimageurlmedium',
    'ownerprofileimageurllarge',
  };

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

  bool _isSecret(String key) {
    final lower = key.toLowerCase();
    return _secretKeys.contains(lower) || _personalKeys.contains(lower);
  }
}
