/// Which Garmin API a session talks to.
///
/// Two of them, with the same paths behind them: the internal app
/// interface the SSO login reaches, and the official Personal API. That
/// they answer identically was checked field by field against a real
/// account - see `docs/garmin-connect-personal-api.openapi.json`.
enum GarminApi {
  internal('connectapi'),
  personal('personal.connectapi');

  const GarminApi(this.subdomain);

  final String subdomain;
}

/// Bearer credentials for talking to the Garmin Connect activity API.
///
/// Two kinds, told apart by [personalApiKey]:
///
/// - **SSO**, from email and password. [refreshToken] lets
///   [GarminAuthClient.refresh] obtain a new [accessToken] without asking
///   for the password again. How long it stays valid is not publicly
///   documented and has changed before when Garmin altered their auth flow
///   — treat expiry as "unknown, handle gracefully" rather than relying on
///   a fixed lifetime.
/// - **Personal API key**, created by the member in Garmin Connect. The key
///   is the long-lived credential and is kept here; the access token is
///   derived from it and lasts a day at most. There is no refresh token on
///   this side - a new token is simply asked for.
class GarminSession {
  const GarminSession({
    required this.accessToken,
    required this.refreshToken,
    required this.diClientId,
    this.personalApiKey,
    this.tokenExpiresAt,
  });

  /// A session derived from a Personal API key.
  const GarminSession.personal({
    required this.accessToken,
    required String key,
    this.tokenExpiresAt,
  }) : personalApiKey = key,
       refreshToken = null,
       diClientId = null;

  final String accessToken;

  /// SSO only.
  final String? refreshToken;

  /// SSO only: which of Garmin's known client ids the token was issued to.
  final String? diClientId;

  /// Personal API only: the key the access token is minted from.
  final String? personalApiKey;

  /// Personal API only: when [accessToken] stops being accepted, read from
  /// the token's own `exp` claim. Null for an SSO session, whose lifetime
  /// Garmin does not disclose.
  final DateTime? tokenExpiresAt;

  bool get isPersonal => personalApiKey != null;

  GarminApi get api => isPersonal ? GarminApi.personal : GarminApi.internal;

  GarminSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? diClientId,
    String? personalApiKey,
    DateTime? tokenExpiresAt,
  }) {
    return GarminSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      diClientId: diClientId ?? this.diClientId,
      personalApiKey: personalApiKey ?? this.personalApiKey,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'diClientId': diClientId,
    // Left out when absent so a stored SSO session reads back unchanged.
    if (personalApiKey != null) 'personalApiKey': personalApiKey,
    if (tokenExpiresAt != null)
      'tokenExpiresAt': tokenExpiresAt!.toIso8601String(),
  };

  factory GarminSession.fromJson(Map<String, dynamic> json) => GarminSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    diClientId: json['diClientId'] as String?,
    personalApiKey: json['personalApiKey'] as String?,
    tokenExpiresAt: switch (json['tokenExpiresAt']) {
      final String raw => DateTime.tryParse(raw),
      _ => null,
    },
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
