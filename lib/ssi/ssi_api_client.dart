import 'dart:convert';

import 'package:dio/dio.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import '../net/dio_errors.dart';
import 'dive_site.dart';
import 'ssi_api_exceptions.dart';
import 'ssi_session.dart';

/// Reads the user's own SSI logbook through the API that SSI's mobile app
/// uses.
///
/// ## Why this endpoint and not the website
///
/// SSI's web search (`rest.divessi.com/scubago-www/find`) can look up dive
/// sites by radius, which would be the richer source. It was tried and
/// rejected: it sits behind a WAF that rejects non-browser clients, its
/// `X-Ssi-Auth` key is bound to a browser session rather than to the
/// application, and it answers with rendered HTML instead of data. Using it
/// would mean impersonating a browser on three levels at once and parsing
/// markup - fragile in a way that breaks for every user at the same moment.
///
/// `api.divessi.com/app/a21.php` is the interface SSI's own app talks to.
/// It expects non-browser clients, answers JSON, and needs nothing but a
/// token. Verified against a real account.
///
/// ## Shape, as observed
///
/// Both calls are form-encoded POSTs to the same URL, distinguished by
/// `what`:
///
/// - `what=authenticate` with `l` (email) and `p` (password) answers
///   `{"authenticated": true, "token": "...", "mid": 3837926,
///     "imperial": false, "authenticated_email": "..."}`.
/// - `what=get_divelog` with `token` answers `logbook_sites` (every site
///   the account has logged a dive at) and `logbook_details` (the dives).
///
/// POST rather than GET, even though the API accepts both: a GET would put
/// the password in the URL, where it lands in server logs and in this app's
/// own diagnostic log as part of the request line.
class SsiApiClient {
  SsiApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.interceptors.add(const ApiLogInterceptor());
  }

  static const _endpoint = 'https://api.divessi.com/app/a21.php';

  /// The client identifier SSI's API expects. Taken from the reference
  /// implementation (`gerardpuig/divessi-export`) rather than invented,
  /// because an unknown value may simply be refused.
  static const _clientApp = '0815_ADR';

  final Dio _dio;

  /// Exchanges email and password for a session token.
  ///
  /// The password is used here and nowhere else - nothing stores it.
  Future<SsiSession> authenticate({
    required String email,
    required String password,
  }) async {
    final data = await _post({
      'l': email,
      'p': password,
      'what': 'authenticate',
      'ssiapp': _clientApp,
    }, context: 'SSI-Login');

    if (data['authenticated'] != true) {
      throw SsiApiException(
        SsiApiErrorType.invalidCredentials,
        'SSI hat die Anmeldung abgelehnt. E-Mail und Passwort prüfen.',
      );
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw SsiApiException(
        SsiApiErrorType.connectionError,
        'SSI hat die Anmeldung bestätigt, aber keinen Token geliefert.',
      );
    }

    return SsiSession(
      email: data['authenticated_email'] as String? ?? email,
      token: token,
      memberId: (data['mid'] as num?)?.toInt(),
      imperial: data['imperial'] == true,
    );
  }

  /// Every dive site the account has logged a dive at, with SSI's own site
  /// number and position.
  ///
  /// This is the whole point of the integration: those numbers are exactly
  /// what the QR code's `site:` field wants, and they cannot be derived
  /// from coordinates.
  Future<List<DiveSite>> loadLogbookSites(SsiSession session) async {
    final data = await _post({
      'what': 'get_divelog',
      'token': session.token,
      'ssiapp': _clientApp,
    }, context: 'SSI-Tauchplätze');

    final raw = data['logbook_sites'];
    if (raw == null) {
      // The token is the only thing that can go stale here, and SSI does
      // not answer that with an HTTP status.
      throw SsiApiException(
        SsiApiErrorType.invalidCredentials,
        'SSI hat keine Tauchplätze geliefert. Die Sitzung ist vermutlich '
        'abgelaufen - bitte erneut anmelden.',
      );
    }

    final entries = switch (raw) {
      List list => list,
      Map map => map.values.toList(),
      _ => const [],
    };

    final sites = <DiveSite>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final site = _siteFromLogbookEntry(entry.cast<String, dynamic>());
      if (site != null) sites.add(site);
    }
    return sites;
  }

  Future<Map<String, dynamic>> _post(
    Map<String, String> form, {
    required String context,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        _endpoint,
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // The API has been seen answering JSON without saying so in the
          // content type, which would leave Dio holding a String.
          responseType: ResponseType.plain,
        ),
      );
      return _decode(response.data, context: context);
    } on DioException catch (e) {
      throw _mapDioError(e, context: context);
    }
  }

  Map<String, dynamic> _decode(Object? body, {required String context}) {
    final text = body is String ? body : jsonEncode(body);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      // Falls through to the same error as a non-object answer: either way
      // this is not the API we expected to be talking to.
    }
    throw SsiApiException(
      SsiApiErrorType.connectionError,
      '$context: Unerwartete Antwort von SSI.',
      details: ApiLog.instance.enabled ? text : null,
    );
  }

  SsiApiException _mapDioError(DioException e, {required String context}) {
    final status = e.response?.statusCode;

    if (status == 401 || status == 403) {
      return SsiApiException(
        SsiApiErrorType.invalidCredentials,
        '$context: Von SSI abgelehnt. Bitte erneut anmelden.',
      );
    }
    if (isOfflineDioError(e)) {
      return SsiApiException(
        SsiApiErrorType.offline,
        '$context: Keine Verbindung zu SSI. Internetverbindung prüfen.',
      );
    }
    return SsiApiException(
      SsiApiErrorType.connectionError,
      '$context fehlgeschlagen${status != null ? ' (HTTP $status)' : ''}.',
      details: ApiLog.instance.enabled
          ? '${e.requestOptions.method} ${e.requestOptions.uri}\n'
                'Antwort: ${e.response?.data}'
          : null,
    );
  }
}

/// Turns one `logbook_sites` entry into a [DiveSite], or null when it can't
/// be trusted.
///
/// A real entry, kept here because these field names are not documented
/// anywhere and this is the only record of where they came from:
///
/// ```json
/// {
///   "odin_dive_sites_id": 2595,
///   "odin_dive_sites_name": "Ras il-Hobz",
///   "odin_dive_sites_lat": 36.0166,
///   "odin_dive_sites_lon": 14.2798,
///   "country_lalo": "35.946153,14.384604",
///   "odin_dive_sites_address": "Horgenweg, 8037 Zurich, Switzerland",
///   "odin_dive_sites_regions_name": "Gozo",
///   "bow": "salt"
/// }
/// ```
///
/// That the id is the same number the QR code's `site:` field wants was
/// confirmed against SSI's own site: the page for this entry is
/// `divessi.com/en/mydiveguide/divesite/ras-il-hobz-hobs-gozo-rad-malta-2595`.
/// Four digits, so short ids are real - not every site number has six.
///
/// Two fields in there are traps and are deliberately ignored:
/// `country_lalo` is the centre of the *country*, roughly 10 km off, and
/// `odin_dive_sites_address` held SSI's own office address rather than the
/// site's. Only `odin_dive_sites_lat`/`_lon` describe the place.
DiveSite? _siteFromLogbookEntry(Map<String, dynamic> entry) {
  final siteId = switch (entry['odin_dive_sites_id']) {
    final num id => id.toInt().toString(),
    final String id => id.trim(),
    _ => null,
  };
  if (siteId == null || !RegExp(r'^\d+$').hasMatch(siteId)) return null;

  final latitude = (entry['odin_dive_sites_lat'] as num?)?.toDouble();
  final longitude = (entry['odin_dive_sites_lon'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  // Exactly zero on both axes is the Atlantic off Ghana, and in practice
  // always means "no position recorded" - the same rule the Garmin side
  // applies.
  if (latitude == 0 && longitude == 0) return null;

  final name = (entry['odin_dive_sites_name'] as String?)?.trim() ?? '';
  return DiveSite(
    // Named by its number when SSI has no name, the same way a buddy
    // without a name is.
    name: name.isEmpty ? 'site:$siteId' : name,
    siteId: siteId,
    latitude: latitude,
    longitude: longitude,
  );
}
