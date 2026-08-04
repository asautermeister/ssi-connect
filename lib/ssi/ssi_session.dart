/// A logged-in SSI account, as far as this app needs to know it.
///
/// Deliberately does NOT hold the password. SSI's app API answers a login
/// with a token, and the token is all the later calls need - so the
/// password is used once, in memory, and then forgotten. If the token
/// stops working the user logs in again; that is a worse day than storing
/// the password, and a much better one than leaking it.
class SsiSession {
  const SsiSession({
    required this.email,
    required this.token,
    this.memberId,
    this.imperial = false,
  });

  /// The address SSI confirmed for this account (`authenticated_email`),
  /// shown so the user can tell which account is connected.
  final String email;

  /// The session token from `what=authenticate`. The secret here.
  final String token;

  /// SSI's member number for this account (`mid`) - the same number that a
  /// buddy QR code carries. Kept because it identifies the account, not
  /// because anything uses it yet.
  final int? memberId;

  /// Whether the account is set to feet/Fahrenheit on SSI's side. Recorded
  /// for later; this app formats metric throughout.
  final bool imperial;

  Map<String, dynamic> toJson() => {
    'email': email,
    'token': token,
    'memberId': memberId,
    'imperial': imperial,
  };

  factory SsiSession.fromJson(Map<String, dynamic> json) => SsiSession(
    email: json['email'] as String,
    token: json['token'] as String,
    memberId: (json['memberId'] as num?)?.toInt(),
    imperial: json['imperial'] as bool? ?? false,
  );
}
