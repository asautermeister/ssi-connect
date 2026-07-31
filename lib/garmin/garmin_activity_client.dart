import 'package:dio/dio.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import 'garmin_auth_exceptions.dart';
import 'models/garmin_activity.dart';
import 'models/garmin_session.dart';

/// Activity types Garmin uses for the various dive computer modes
/// (`activity_types.properties`, key without the `activity_type_` prefix).
/// Not all of these are necessarily accepted by the search endpoint - an
/// unknown key makes it answer 400 - so [GarminActivityClient] queries them
/// individually and tolerates rejections rather than failing outright.
const garminDiveActivityTypes = [
  'diving',
  'apnea_diving',
  'apnea_hunting',
  'ccr_diving',
];

/// Reads the (already authenticated) Garmin Connect activity list/detail
/// endpoints. Field names in the returned [GarminActivity] objects are
/// best-effort guesses - see that class's doc comment.
class GarminActivityClient {
  GarminActivityClient({Dio? dio, this._domain = 'garmin.com'})
    : _dio = dio ?? Dio() {
    _dio.interceptors.add(const ApiLogInterceptor());
  }

  final Dio _dio;
  final String _domain;

  String get _connectApiBase => 'https://connectapi.$_domain';

  /// Queries each dive activity type separately and merges the results.
  ///
  /// A type the endpoint doesn't recognise answers 400; that must not take
  /// the whole fetch down, since the other types may well return dives. So
  /// per-type failures are collected and only rethrown if *every* type
  /// failed.
  Future<List<GarminActivity>> getDiveActivities(
    GarminSession session, {
    int limit = 50,
  }) async {
    final results = <GarminActivity>[];
    final failures = <String, GarminAuthException>{};

    for (final activityType in garminDiveActivityTypes) {
      final Response<dynamic> response;
      try {
        response = await _get(
          session,
          '/activitylist-service/activities/search/activities',
          queryParameters: {
            'activityType': activityType,
            'limit': limit,
            'start': 0,
          },
        );
      } on GarminAuthException catch (e) {
        // An expired session or a rate limit applies to every type, so
        // there is nothing to be gained by trying the rest.
        if (e.type != GarminAuthErrorType.connectionError) rethrow;
        failures[activityType] = e;
        continue;
      }

      final list = response.data;
      if (list is List) {
        results.addAll(
          list.whereType<Map>().map(
            (e) => GarminActivity(e.cast<String, dynamic>()),
          ),
        );
      }
    }

    if (failures.length == garminDiveActivityTypes.length) {
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Tauchgänge konnten nicht geladen werden. '
        '${failures.values.first.message}',
      );
    }

    results.sort((a, b) {
      final aTime = a.startTimeLocal;
      final bTime = b.startTimeLocal;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return results;
  }

  Future<GarminActivity> getActivityDetail(
    GarminSession session,
    String activityId,
  ) async {
    final response = await _get(
      session,
      '/activity-service/activity/$activityId',
    );
    final data = response.data;
    if (data is! Map) {
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Unerwartete Antwort beim Laden der Tauchgangs-Details.',
      );
    }
    return GarminActivity(data.cast<String, dynamic>());
  }

  Future<Response<dynamic>> _get(
    GarminSession session,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<dynamic>(
        '$_connectApiBase$path',
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Accept': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw GarminAuthException(
          GarminAuthErrorType.invalidCredentials,
          'Sitzung abgelaufen - bitte Account neu verbinden.',
        );
      }
      if (status == 429) {
        throw GarminAuthException(
          GarminAuthErrorType.rateLimited,
          'Zu viele Anfragen an Garmin, bitte später erneut versuchen.',
        );
      }
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Abfrage fehlgeschlagen${status != null ? ' (HTTP $status)' : ''}.',
        details: ApiLog.instance.enabled ? _describe(e) : null,
      );
    }
  }

  /// Raw request/response summary, shown in the UI only while API logging
  /// is switched on.
  String _describe(DioException e) {
    final buffer = StringBuffer()
      ..writeln('${e.requestOptions.method} ${e.requestOptions.uri}');
    final data = e.response?.data;
    if (data != null) buffer.writeln('Antwort: $data');
    if (e.message != null) buffer.writeln('Dio: ${e.message}');
    return buffer.toString();
  }
}
