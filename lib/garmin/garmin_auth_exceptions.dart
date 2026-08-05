// Re-exported so the existing `isOfflineDioError` imports from this file
// keep working now that the helper is shared with the SSI client.
export '../net/dio_errors.dart' show isOfflineDioError;

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
