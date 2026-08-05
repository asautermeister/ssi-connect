import '../../garmin/models/garmin_session.dart';
import '../../ssi/ssi_buddy_code.dart';
import '../../ssi/ssi_session.dart';
import 'account_color.dart';

/// One logged-in Garmin account stored on this tablet (one per family
/// member), together with the SSI identity its dives belong to.
///
/// [ssiMemberId] is the same number SSI writes as `user_master_id` into an
/// exported dive, so storing it here is what lets a generated dive be
/// attributed to the right diver.
///
/// It can arrive three ways: signing in to SSI ([ssiSession], which reports
/// the number as `mid` and is the least error-prone), scanning the member's
/// QR code in the SSI app, or typing the number. The last two stay because
/// not everyone with a dive watch has an SSI login - a guest or a child may
/// have nothing but the number.
class GarminAccount {
  const GarminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.session,
    this.ssiMemberId,
    this.ssiFirstName,
    this.ssiLastName,
    this.ssiEmail,
    this.ssiSession,
    this.color,
  });

  /// Stable local id (not a Garmin id) used as the secure-storage key.
  final String id;
  final String email;
  final String displayName;
  final GarminSession session;

  final String? ssiMemberId;
  final String? ssiFirstName;
  final String? ssiLastName;
  final String? ssiEmail;

  /// The SSI login belonging to this person, when they have connected one.
  ///
  /// Holds a session token, never a password. Its one job is fetching the
  /// dive sites out of this person's SSI logbook - which land in the
  /// device-wide site list, not on the account: a dive site is a place,
  /// and the family shares those.
  final SsiSession? ssiSession;

  /// Marks this person's dives with a bar on the left edge, so a shared
  /// tablet's mixed list can be read at a glance. Null means no bar.
  final AccountColor? color;

  bool get hasSsiIdentity => ssiMemberId != null;
  bool get hasSsiLogin => ssiSession != null;

  /// The stored identity in the shape the QR payload builder wants, or
  /// null when none has been scanned yet.
  SsiBuddyCode? get ssiIdentity {
    final memberId = ssiMemberId;
    if (memberId == null) return null;
    return SsiBuddyCode(
      memberId: memberId,
      firstName: ssiFirstName,
      lastName: ssiLastName,
      email: ssiEmail,
    );
  }

  String? get ssiFullName {
    final parts = [
      ssiFirstName,
      ssiLastName,
    ].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  GarminAccount copyWith({
    GarminSession? session,
    String? displayName,
    String? ssiMemberId,
    String? ssiFirstName,
    String? ssiLastName,
    String? ssiEmail,
    SsiSession? ssiSession,
  }) {
    return GarminAccount(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      session: session ?? this.session,
      ssiMemberId: ssiMemberId ?? this.ssiMemberId,
      ssiFirstName: ssiFirstName ?? this.ssiFirstName,
      ssiLastName: ssiLastName ?? this.ssiLastName,
      ssiEmail: ssiEmail ?? this.ssiEmail,
      ssiSession: ssiSession ?? this.ssiSession,
      color: color,
    );
  }

  /// Separate from [copyWith] for the same reason [withoutSsiIdentity] is:
  /// null there means "leave unchanged", so it cannot clear the colour.
  GarminAccount withColor(AccountColor? color) => GarminAccount(
    id: id,
    email: email,
    displayName: displayName,
    session: session,
    ssiMemberId: ssiMemberId,
    ssiFirstName: ssiFirstName,
    ssiLastName: ssiLastName,
    ssiEmail: ssiEmail,
    ssiSession: ssiSession,
    color: color,
  );

  /// Signs out of SSI but keeps the member number and name.
  ///
  /// The number is what a QR export needs, and it does not stop being
  /// yours because the token was dropped.
  GarminAccount withoutSsiSession() => GarminAccount(
    id: id,
    email: email,
    displayName: displayName,
    session: session,
    ssiMemberId: ssiMemberId,
    ssiFirstName: ssiFirstName,
    ssiLastName: ssiLastName,
    ssiEmail: ssiEmail,
    color: color,
  );

  /// Drops the stored SSI identity, the login included - the login is what
  /// vouches for the number, so keeping it while removing the number would
  /// leave a token behind for no one's benefit.
  ///
  /// Separate from [copyWith] because that treats null as "leave
  /// unchanged", so it cannot clear a field.
  GarminAccount withoutSsiIdentity() => GarminAccount(
    id: id,
    email: email,
    displayName: displayName,
    session: session,
    color: color,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'session': session.toJson(),
    'ssiMemberId': ssiMemberId,
    'ssiFirstName': ssiFirstName,
    'ssiLastName': ssiLastName,
    'ssiEmail': ssiEmail,
    'ssiSession': ssiSession?.toJson(),
    'color': color?.name,
  };

  factory GarminAccount.fromJson(Map<String, dynamic> json) => GarminAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    session: GarminSession.fromJson(json['session'] as Map<String, dynamic>),
    ssiMemberId: json['ssiMemberId'] as String?,
    ssiFirstName: json['ssiFirstName'] as String?,
    ssiLastName: json['ssiLastName'] as String?,
    ssiEmail: json['ssiEmail'] as String?,
    ssiSession: switch (json['ssiSession']) {
      final Map<String, dynamic> stored => SsiSession.fromJson(stored),
      _ => null,
    },
    color: AccountColor.byName(json['color'] as String?),
  );
}
