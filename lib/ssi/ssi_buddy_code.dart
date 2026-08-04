import '../l10n/app_strings.dart';

/// A diver's identity as encoded in the QR code the SSI app shows under
/// "Dein QR-Code".
///
/// Observed payloads, from real SSI app screens:
/// `buddy;3902893;firstName:Andreas;lastName:Sautermeister;email:a@b.de`
/// `buddy;3154225;firstName:...;lastName:...;email:...;leaderNr:110890`
///
/// So: the literal marker `buddy`, then the member id, then `key:value`
/// pairs - all semicolon-separated, same shape as the dive payload SSI
/// scans on import. That member id is the same number that appears as
/// `user_master_id` in an SSI-exported dive QR code.
///
/// The second example is a divemaster's code: professionals carry an
/// extra `leaderNr`. Whether that number or the member id is what belongs
/// in a dive's `user_leader_id` is still open - see
/// [SsiQrPayloadBuilder].
class SsiBuddyCode {
  const SsiBuddyCode({
    required this.memberId,
    this.firstName,
    this.lastName,
    this.email,
    this.leaderNumber,
  });

  /// SSI member number. The one field that must be present.
  final String memberId;
  final String? firstName;
  final String? lastName;
  final String? email;

  /// The number SSI gives a professional - divemasters and instructors -
  /// which ordinary members' codes don't carry. Kept even though nothing
  /// consumes it yet: dropping a field on the way through would mean this
  /// app hands out a poorer code than it was given.
  ///
  /// Named after SSI's own wire key `leaderNr` so the parser reads
  /// straight; on screen it is the official term, "SSI Professional Nr.".
  final String? leaderNumber;

  /// True when the scanned code identifies an SSI professional.
  bool get isProfessional => leaderNumber != null;

  /// "First Last", or null when neither name was in the code.
  String? get fullName {
    final parts = [
      firstName,
      lastName,
    ].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// What to put on screen for this person: their name if the code carried
  /// one, otherwise the member number, which is all we know about them.
  String displayName(AppStrings s) => fullName ?? s.ssiNumber(memberId);

  /// A language-independent key for sorting, so the list does not
  /// reshuffle when the app language changes.
  String get sortKey => fullName ?? memberId;

  /// The member number as a secondary line - null when [displayName] is
  /// already that number, so a nameless buddy isn't labelled twice with the
  /// same digits.
  String? memberIdLine(AppStrings s) =>
      fullName == null ? null : s.ssiNumber(memberId);

  /// The professional number as a secondary line, or null for a code
  /// without one.
  String? professionalNumberLine(AppStrings s) =>
      leaderNumber == null ? null : s.professionalNumber(leaderNumber!);

  /// The payload as SSI writes it, so this member can be shown as a QR
  /// code for someone else's app to scan.
  ///
  /// Field names match the ones [tryParse] reads, in the order the real
  /// SSI code uses. Empty fields are left out rather than emitted blank -
  /// a parser that trims values would read them as empty strings.
  String toPayload() {
    final fields = <String>[
      if (firstName != null) 'firstName:$firstName',
      if (lastName != null) 'lastName:$lastName',
      if (email != null) 'email:$email',
      if (leaderNumber != null) 'leaderNr:$leaderNumber',
    ];
    return ['buddy', memberId, ...fields].join(';');
  }

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (email != null) 'email': email,
    if (leaderNumber != null) 'leaderNumber': leaderNumber,
  };

  factory SsiBuddyCode.fromJson(Map<String, dynamic> json) => SsiBuddyCode(
    memberId: json['memberId'] as String,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    email: json['email'] as String?,
    leaderNumber: json['leaderNumber'] as String?,
  );

  /// Two codes are the same person when the member number matches - that
  /// number is SSI's identity for them, names and mail addresses aren't.
  @override
  bool operator ==(Object other) =>
      other is SsiBuddyCode && other.memberId == memberId;

  @override
  int get hashCode => memberId.hashCode;

  /// Parses a scanned payload, or returns null if it isn't an SSI buddy
  /// code. Returning null rather than throwing because the camera hands
  /// us whatever it happens to see - most scans of the wrong thing are
  /// simply not this format.
  static SsiBuddyCode? tryParse(String raw) {
    final segments = raw.trim().split(';');
    if (segments.length < 2) return null;
    if (segments.first.trim().toLowerCase() != 'buddy') return null;

    final memberId = segments[1].trim();
    // The id sits in a fixed position rather than a key:value pair, so
    // guard against a payload whose second segment is already a pair.
    if (memberId.isEmpty || memberId.contains(':')) return null;

    final fields = <String, String>{};
    for (final segment in segments.skip(2)) {
      final separator = segment.indexOf(':');
      if (separator <= 0) continue;
      final key = segment.substring(0, separator).trim().toLowerCase();
      fields[key] = segment.substring(separator + 1).trim();
    }

    String? valueOf(String key) {
      final value = fields[key];
      return (value == null || value.isEmpty) ? null : value;
    }

    return SsiBuddyCode(
      memberId: memberId,
      firstName: valueOf('firstname'),
      lastName: valueOf('lastname'),
      email: valueOf('email'),
      leaderNumber: valueOf('leadernr'),
    );
  }
}
