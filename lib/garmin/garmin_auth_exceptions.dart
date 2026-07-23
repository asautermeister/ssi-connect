/// Error categories a caller needs to react to differently
/// (e.g. show a retry hint vs. prompt for new credentials).
enum GarminAuthErrorType { invalidCredentials, rateLimited, connectionError }

/// Thrown by [GarminAuthClient] whenever the login/refresh flow can't
/// complete. The unofficial Garmin login API can fail for reasons outside
/// our control (bot detection, temporary outages), so [message] always
/// carries a human-readable explanation to show the user.
class GarminAuthException implements Exception {
  GarminAuthException(this.type, this.message);

  final GarminAuthErrorType type;
  final String message;

  @override
  String toString() => 'GarminAuthException($type): $message';
}
