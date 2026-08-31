import 'dart:convert';

import 'package:dio/dio.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import '../net/dio_errors.dart';
import 'dive_site.dart';
import 'ssi_api_exceptions.dart';
import 'ssi_buddy_code.dart';
import 'ssi_logged_dive.dart';
import 'ssi_session.dart';

/// What one `get_divelog` call yields that this app has a use for.
typedef SsiLogbook = ({
  List<DiveSite> sites,
  List<SsiBuddyCode> buddies,
  List<SsiLoggedDive> dives,
});

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
///   the account has logged a dive at), `logbook_details` (the dives),
///   `logbook_buddies` (the divers on file) and `logbook_history` (totals).
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

  /// The account's logbook, reduced to the three things this app can use:
  /// the dive sites it has been to, the buddies on file, and the dives
  /// themselves.
  ///
  /// The sites are the point of the integration - those numbers are exactly
  /// what the QR code's `site:` field wants, and they cannot be derived
  /// from coordinates. The buddies come along in the same answer and carry
  /// the same fields a scanned buddy QR code does. The dives are kept only
  /// as date, time and depth, which is enough to recognise which of this
  /// device's dives have already arrived here.
  Future<SsiLogbook> loadLogbook(SsiSession session) async {
    final data = await _post({
      'what': 'get_divelog',
      'token': session.token,
      'ssiapp': _clientApp,
    }, context: 'SSI-Logbuch');

    if (!data.containsKey('logbook_sites')) {
      // The token is the only thing that can go stale here, and SSI does
      // not answer that with an HTTP status.
      throw SsiApiException(
        SsiApiErrorType.invalidCredentials,
        'SSI hat kein Logbuch geliefert. Die Sitzung ist vermutlich '
        'abgelaufen - bitte erneut anmelden.',
      );
    }

    final sites = <DiveSite>[];
    for (final entry in _entriesOf(data['logbook_sites'])) {
      final site = _siteFromLogbookEntry(entry);
      if (site != null) sites.add(site);
    }

    final buddies = <SsiBuddyCode>[];
    for (final entry in _entriesOf(data['logbook_buddies'])) {
      final buddy = _buddyFromLogbookEntry(entry);
      if (buddy != null) buddies.add(buddy);
    }

    final dives = <SsiLoggedDive>[];
    for (final entry in _entriesOf(data['logbook_details'])) {
      final logged = _loggedDiveFromEntry(entry);
      if (logged != null) dives.add(logged);
    }

    return (sites: sites, buddies: buddies, dives: dives);
  }

  /// SSI hands these back as a list, but has been seen keying them by id
  /// elsewhere; both read the same from here.
  static Iterable<Map<String, dynamic>> _entriesOf(Object? raw) {
    final entries = switch (raw) {
      List list => list,
      Map map => map.values.toList(),
      _ => const [],
    };
    return entries.whereType<Map>().map((e) => e.cast<String, dynamic>());
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
///   "bow": "salt",
///   "myloggedDives": 1
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
///
/// `odin_dive_sites_regions_name` is kept for grouping the list, and
/// nothing else - see [DiveSite.region]. `bow` ("salt") is still unused.
///
/// `myloggedDives` is dropped on purpose, and not for lack of a use: this
/// device merges the sites of every logbook into one list, so a count
/// shown there would silently belong to whichever account imported the
/// site first. "12 dives" without saying whose is worse than no number.
/// It could only come back together with per-account provenance.
DiveSite? _siteFromLogbookEntry(Map<String, dynamic> entry) {
  final siteId = _idOf(entry['odin_dive_sites_id']);
  if (siteId == null) return null;

  final latitude = (entry['odin_dive_sites_lat'] as num?)?.toDouble();
  final longitude = (entry['odin_dive_sites_lon'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  // Exactly zero on both axes is the Atlantic off Ghana, and in practice
  // always means "no position recorded" - the same rule the Garmin side
  // applies.
  if (latitude == 0 && longitude == 0) return null;

  final name = (entry['odin_dive_sites_name'] as String?)?.trim() ?? '';
  final region = (entry['odin_dive_sites_regions_name'] as String?)?.trim();
  return DiveSite(
    // Named by its number when SSI has no name, the same way a buddy
    // without a name is.
    name: name.isEmpty ? 'site:$siteId' : name,
    siteId: siteId,
    latitude: latitude,
    longitude: longitude,
    region: region == null || region.isEmpty ? null : region,
  );
}

/// Turns one `logbook_buddies` entry into an [SsiBuddyCode], or null when
/// it can't be used.
///
/// A real entry, again recorded because these names are documented
/// nowhere:
///
/// ```json
/// {
///   "master_id": 3902893,
///   "buddy_master_id": 3902893,
///   "firstname": "Andreas",
///   "lastname": "Sautermeister",
///   "email": "...",
///   "leader_nr": "",
///   "dob": "1984-04-10",
///   "city": "Oberhaching",
///   "phone": "    ",
///   "image": "https://my.divessi.com/.../3902893.png",
///   "deleted": 0
/// }
/// ```
///
/// Only the four fields a scanned buddy QR code also carries are taken,
/// plus `leader_nr` - which is that code's `leaderNr`, the SSI Professional
/// Nr. Date of birth, address, telephone number and photo are deliberately
/// dropped: they are personal data about third parties, this app has no use
/// for them, and a family tablet is no place to accumulate them.
SsiBuddyCode? _buddyFromLogbookEntry(Map<String, dynamic> entry) {
  // Both id fields held the buddy's own number in the observed data. The
  // named one is the more specific of the two, so it wins.
  final memberId = _idOf(entry['buddy_master_id']) ?? _idOf(entry['master_id']);
  if (memberId == null) return null;
  // SSI keeps deleted buddies in the answer with a flag.
  if (entry['deleted'] == 1 || entry['deleted'] == true) return null;

  return SsiBuddyCode(
    memberId: memberId,
    firstName: _textOf(entry['firstname']),
    lastName: _textOf(entry['lastname']),
    email: _textOf(entry['email']),
    leaderNumber: _textOf(entry['leader_nr']),
  );
}

/// A numeric SSI id as a string, or null when there is no usable number.
String? _idOf(Object? raw) {
  final id = switch (raw) {
    final num value => value.toInt().toString(),
    final String value => value.trim(),
    _ => null,
  };
  if (id == null || !RegExp(r'^\d+$').hasMatch(id)) return null;
  return id;
}

/// A trimmed string, or null when the field is absent or blank.
///
/// SSI writes blank fields as empty strings and, in at least one case, as
/// four spaces - both mean "not filled in", and neither should reach a QR
/// code as an empty value.
String? _textOf(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  return text.isEmpty ? null : text;
}

/// Turns one `logbook_details` entry into an [SsiLoggedDive], or null when
/// it cannot be placed in time.
///
/// `odin_user_log_datetime` ("2023-08-12 12:54") is the entry SSI itself
/// composes; the separate `_date` and `_entry_time` fields are the fallback
/// for an answer that omits it. Neither carries a timezone - this is the
/// local entry time, which is what makes it comparable with Garmin's
/// `startTimeLocal`.
SsiLoggedDive? _loggedDiveFromEntry(Map<String, dynamic> entry) {
  if (entry['odin_user_log_deleted'] == 1) return null;

  final dateTime =
      _parseLocal(entry['odin_user_log_datetime']) ??
      _parseLocal(
        '${entry['odin_user_log_date']} ${entry['odin_user_log_entry_time']}',
      );
  if (dateTime == null) return null;

  return SsiLoggedDive(
    dateTime: dateTime,
    depthMeters: (entry['odin_user_log_depth_m'] as num?)?.toDouble(),
  );
}

/// "2023-08-12 12:54" as a local DateTime, or null.
///
/// [DateTime.parse] wants seconds, and SSI writes minutes; padding is
/// cheaper than a second date library.
DateTime? _parseLocal(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})',
  ).firstMatch(text);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}
