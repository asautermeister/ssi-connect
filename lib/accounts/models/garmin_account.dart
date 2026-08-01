import '../../garmin/models/garmin_session.dart';
import '../../ssi/ssi_buddy_code.dart';
import 'account_color.dart';

/// One logged-in Garmin account stored on this tablet (one per family
/// member), together with the SSI identity its dives belong to.
///
/// The SSI fields come from scanning the member's QR code in the SSI app
/// ("Dein QR-Code"). [ssiMemberId] is the same number SSI writes as
/// `user_master_id` into an exported dive, so storing it here is what will
/// let a generated dive be attributed to the right diver later.
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

  /// Marks this person's dives with a bar on the left edge, so a shared
  /// tablet's mixed list can be read at a glance. Null means no bar.
  final AccountColor? color;

  bool get hasSsiIdentity => ssiMemberId != null;

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
    color: color,
  );

  /// Drops the stored SSI identity. Separate from [copyWith] because that
  /// treats null as "leave unchanged", so it cannot clear a field.
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
    color: AccountColor.byName(json['color'] as String?),
  );
}
