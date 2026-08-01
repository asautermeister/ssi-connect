import 'package:dio/dio.dart';

import '../debug/api_log.dart';
import '../debug/api_log_interceptor.dart';
import 'garmin_auth_exceptions.dart';
import 'models/garmin_activity.dart';
import 'models/garmin_session.dart';

/// The activity types to query for.
///
/// Only the parent type. The search endpoint rejects sub-types outright -
/// asking for `apnea_diving` answers 400 with "Activity type cannot be an
/// activity sub type" - and it is unnecessary anyway: every dive sub-type
/// (apnea_diving, ccr_diving, single/multi gas, ...) hangs off `diving` as
/// its parent and comes back in that one query. Each result still carries
/// its own sub-type in `activityType.typeKey`, which is what drives the
/// badge in the list.
const garminDiveActivityTypes = ['diving'];

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
        final activities = list
            .whereType<Map>()
            .map((e) => GarminActivity(e.cast<String, dynamic>()))
            .toList();
        results.addAll(activities);
        _logMeasurementProbe(activityType, activities);
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

  /// Writes the depth/temperature fields of the first activity of a type
  /// into the API log.
  ///
  /// The list response is tens of thousands of characters, so the log's
  /// truncation hides exactly the fields whose names and units we still
  /// need to confirm. This pulls just those out, one line per activity
  /// type, so a misread value can be traced to a specific key.
  void _logMeasurementProbe(String activityType, List<GarminActivity> items) {
    if (!ApiLog.instance.enabled || items.isEmpty) return;
    final sample = items.first;
    final fields = sample.probeMeasurementFields();
    ApiLog.instance.add(
      ApiLogEntry(
        timestamp: DateTime.now(),
        method: 'PROBE',
        url: 'Messfelder · $activityType',
        statusCode: 200,
        responseBody: [
          'startTimeLocal=${sample.raw['startTimeLocal']}',
          'gelesene max. Tiefe=${sample.maxDepthMeters}',
          if (fields.isEmpty)
            'Keine Felder mit "depth"/"temperature" gefunden'
          else
            ...fields.entries.map((e) => '${e.key}=${e.value}'),
        ].join('\n'),
      ),
    );
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
