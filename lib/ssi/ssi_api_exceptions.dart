/// Error categories the SSI screens need to react to differently.
enum SsiApiErrorType {
  /// Wrong email/password, or a stored token SSI no longer accepts.
  invalidCredentials,

  /// The request never reached SSI: no network, DNS failure, timeout.
  offline,

  /// Reached SSI, but the answer was unusable - a server error, a block,
  /// an unexpected response shape.
  connectionError,
}

/// Thrown by [SsiApiClient] when a call can't complete.
///
/// Like the Garmin side, this talks to an interface that is not officially
/// documented, so [message] always carries something a user can act on
/// rather than an HTTP status.
class SsiApiException implements Exception {
  SsiApiException(this.type, this.message, {this.details});

  final SsiApiErrorType type;
  final String message;

  /// Raw request/response summary, only filled while API logging is on.
  final String? details;

  @override
  String toString() =>
      'SsiApiException($type): $message${details != null ? '\n$details' : ''}';
}
