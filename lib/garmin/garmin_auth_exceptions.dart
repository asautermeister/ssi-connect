/// Error categories a caller needs to react to differently
/// (e.g. show a retry hint vs. prompt for new credentials).
enum GarminAuthErrorType { invalidCredentials, rateLimited, connectionError }

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
