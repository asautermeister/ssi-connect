import 'package:dio/dio.dart';

import 'garmin_auth_exceptions.dart';
import 'models/garmin_activity.dart';
import 'models/garmin_session.dart';

/// Activity types Garmin uses for the various dive computer modes
/// (`activity_types.properties`, key without the `activity_type_` prefix).
/// May need extending once we see what a real Descent account actually
/// reports.
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
    : _dio = dio ?? Dio();

  final Dio _dio;
  final String _domain;

  String get _connectApiBase => 'https://connectapi.$_domain';

  Future<List<GarminActivity>> getDiveActivities(
    GarminSession session, {
    int limit = 50,
  }) async {
    final results = <GarminActivity>[];
    for (final activityType in garminDiveActivityTypes) {
      final response = await _get(
        session,
        '/activitylist-service/activities/search/activities',
        queryParameters: {
          'activityType': activityType,
          'limit': limit,
          'start': 0,
        },
      );
      final list = response.data;
      if (list is List) {
        results.addAll(
          list.whereType<Map>().map(
            (e) => GarminActivity(e.cast<String, dynamic>()),
          ),
        );
      }
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
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw GarminAuthException(
          GarminAuthErrorType.invalidCredentials,
          'Sitzung abgelaufen - bitte Account neu verbinden.',
        );
      }
      if (e.response?.statusCode == 429) {
        throw GarminAuthException(
          GarminAuthErrorType.rateLimited,
          'Zu viele Anfragen an Garmin, bitte später erneut versuchen.',
        );
      }
      throw GarminAuthException(
        GarminAuthErrorType.connectionError,
        'Tauchgänge konnten nicht geladen werden: ${e.message}',
      );
    }
  }
}
