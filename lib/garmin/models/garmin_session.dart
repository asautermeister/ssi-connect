/// Bearer credentials for talking to the Garmin Connect activity API.
///
/// [refreshToken] lets [GarminAuthClient.refresh] obtain a new [accessToken]
/// without asking the user for their password again. How long it stays
/// valid is not publicly documented and has changed before when Garmin
/// altered their auth flow — treat expiry as "unknown, handle gracefully"
/// rather than relying on a fixed lifetime.
class GarminSession {
  const GarminSession({
    required this.accessToken,
    required this.refreshToken,
    required this.diClientId,
  });

  final String accessToken;
  final String? refreshToken;
  final String diClientId;

  GarminSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? diClientId,
  }) {
    return GarminSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      diClientId: diClientId ?? this.diClientId,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'diClientId': diClientId,
  };

  factory GarminSession.fromJson(Map<String, dynamic> json) => GarminSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    diClientId: json['diClientId'] as String,
  );
}

/// Everything [GarminAuthClient.completeMfa] needs to finish a login that
/// was interrupted by an MFA challenge. Opaque to callers — just hold on to
/// it and pass it back with the code the user entered.
class GarminMfaContext {
  const GarminMfaContext({
    required this.mfaMethod,
    required this.clientId,
    required this.serviceUrl,
  });

  final String mfaMethod;
  final String clientId;
  final String serviceUrl;
}

/// Result of [GarminAuthClient.login]: either a ready-to-use session, or a
/// signal that the caller must collect an MFA code and call
/// [GarminAuthClient.completeMfa].
sealed class GarminLoginResult {}

class GarminLoginSuccess extends GarminLoginResult {
  GarminLoginSuccess(this.session);
  final GarminSession session;
}

class GarminLoginMfaRequired extends GarminLoginResult {
  GarminLoginMfaRequired(this.mfaContext);
  final GarminMfaContext mfaContext;
}
