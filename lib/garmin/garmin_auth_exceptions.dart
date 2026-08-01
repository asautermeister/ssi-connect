import 'dart:io';

import 'package:dio/dio.dart';

/// Error categories a caller needs to react to differently
/// (e.g. show a retry hint vs. prompt for new credentials).
enum GarminAuthErrorType {
  invalidCredentials,
  rateLimited,

  /// The request never reached Garmin: no network, DNS failure, timeout.
  ///
  /// Kept apart from [connectionError] so the app can say "no internet"
  /// only when that is actually true. A blocked request or a server error
  /// reached Garmin just fine, and telling the user to check their
  /// connection would send them looking in the wrong place.
  offline,

  /// Reached Garmin, but the answer was unusable - a server error, a bot
  /// block, an unexpected response shape.
  connectionError,
}

/// Whether a Dio failure means "the request never left the device or never
/// found a server", as opposed to "the server answered something we didn't
/// like".
///
/// [DioExceptionType.connectionError] covers the socket-level failures
/// (no route, DNS, connection refused); the timeouts are here too, because
/// a request that times out on a tablet in a boat's dry bag is offline for
/// every practical purpose.
bool isOfflineDioError(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout ||
    e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout ||
    e.error is SocketException;

/// Thrown by [GarminAuthClient] whenever the login/refresh flow can't
/// complete. The unofficial Garmin login API can fail for reasons outside
/// our control (bot detection, temporary outages), so [message] always
/// carries a human-readable explanation to show the user.
///
/// [details] holds the raw request/response summary and is only populated
/// while API logging is enabled - it is meant for diagnosing a failure, not
/// for everyday users, so the UI shows it separately.
class GarminAuthException implements Exception {
  GarminAuthException(this.type, this.message, {this.details});

  final GarminAuthErrorType type;
  final String message;
  final String? details;

  @override
  String toString() =>
      'GarminAuthException($type): $message${details != null ? '\n$details' : ''}';
}
