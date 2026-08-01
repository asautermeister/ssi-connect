/// A diver's identity as encoded in the QR code the SSI app shows under
/// "Dein QR-Code".
///
/// Observed payload, from a real SSI app screen:
/// `buddy;3902893;firstName:Andreas;lastName:Sautermeister;email:a@b.de`
///
/// So: the literal marker `buddy`, then the member id, then `key:value`
/// pairs - all semicolon-separated, same shape as the dive payload SSI
/// scans on import. That member id is the same number that appears as
/// `user_master_id` in an SSI-exported dive QR code.
class SsiBuddyCode {
  const SsiBuddyCode({
    required this.memberId,
    this.firstName,
    this.lastName,
    this.email,
  });

  /// SSI member number. The one field that must be present.
  final String memberId;
  final String? firstName;
  final String? lastName;
  final String? email;

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
  String get displayName => fullName ?? 'SSI-Nr. $memberId';

  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (email != null) 'email': email,
  };

  factory SsiBuddyCode.fromJson(Map<String, dynamic> json) => SsiBuddyCode(
    memberId: json['memberId'] as String,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    email: json['email'] as String?,
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
    );
  }
}
