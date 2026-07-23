import '../../garmin/models/garmin_session.dart';

/// One logged-in Garmin account stored on this tablet (one per family
/// member). [ssiBuddyId]/[ssiBuddyName] are captured now so the data is
/// there when buddy-tagging in the QR payload gets built later - they are
/// not read anywhere yet.
class GarminAccount {
  const GarminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.session,
    this.ssiBuddyId,
    this.ssiBuddyName,
  });

  /// Stable local id (not a Garmin id) used as the secure-storage key.
  final String id;
  final String email;
  final String displayName;
  final GarminSession session;
  final String? ssiBuddyId;
  final String? ssiBuddyName;

  GarminAccount copyWith({
    GarminSession? session,
    String? displayName,
    String? ssiBuddyId,
    String? ssiBuddyName,
  }) {
    return GarminAccount(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      session: session ?? this.session,
      ssiBuddyId: ssiBuddyId ?? this.ssiBuddyId,
      ssiBuddyName: ssiBuddyName ?? this.ssiBuddyName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'session': session.toJson(),
    'ssiBuddyId': ssiBuddyId,
    'ssiBuddyName': ssiBuddyName,
  };

  factory GarminAccount.fromJson(Map<String, dynamic> json) => GarminAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    session: GarminSession.fromJson(json['session'] as Map<String, dynamic>),
    ssiBuddyId: json['ssiBuddyId'] as String?,
    ssiBuddyName: json['ssiBuddyName'] as String?,
  );
}
