import '../l10n/app_strings.dart';

/// A dive centre as encoded in the QR code the SSI app shows for it.
///
/// Observed payload:
/// `center;718019;name:Nero-Sport Diving Center, Zakynthos`
///
/// Same shape as the member code - a marker, then an id at a fixed second
/// position, then `key:value` pairs - but a different marker and different
/// fields, so it is its own type rather than a member with a flag. A centre
/// has no first name and no mail address, and a diver has no centre number.
///
/// Note the name may contain commas; only the semicolon separates fields.
class SsiCenterCode {
  const SsiCenterCode({required this.centerId, this.name});

  /// SSI's number for the centre. The one field that must be present.
  final String centerId;
  final String? name;

  /// What to put on screen: the name if the code carried one, otherwise
  /// the number, which is all we know about it.
  String displayName(AppStrings s) => name ?? s.centreNumberLine(centerId);

  /// Language-independent sort key, see [SsiBuddyCode.sortKey].
  String get sortKey => name ?? centerId;

  /// The number as a secondary line - null when [displayName] is already
  /// that number, so a nameless centre isn't labelled twice.
  String? centerIdLine(AppStrings s) =>
      name == null ? null : s.centreNumberLine(centerId);

  /// The payload as SSI writes it, so the centre can be shown as a QR code
  /// for someone else's app to scan.
  String toPayload() =>
      ['center', centerId, if (name != null) 'name:$name'].join(';');

  Map<String, dynamic> toJson() => {
    'centerId': centerId,
    if (name != null) 'name': name,
  };

  factory SsiCenterCode.fromJson(Map<String, dynamic> json) => SsiCenterCode(
    centerId: json['centerId'] as String,
    name: json['name'] as String?,
  );

  /// Two codes are the same centre when the number matches; the name is
  /// how it is written, not what it is.
  @override
  bool operator ==(Object other) =>
      other is SsiCenterCode && other.centerId == centerId;

  @override
  int get hashCode => centerId.hashCode;

  /// Parses a scanned payload, or returns null if it isn't a centre code -
  /// the camera hands us whatever it happens to see.
  static SsiCenterCode? tryParse(String raw) {
    final segments = raw.trim().split(';');
    if (segments.length < 2) return null;
    if (segments.first.trim().toLowerCase() != 'center') return null;

    final centerId = segments[1].trim();
    // The id sits at a fixed position rather than in a pair, so a payload
    // whose second segment is already a pair has no id.
    if (centerId.isEmpty || centerId.contains(':')) return null;

    String? name;
    for (final segment in segments.skip(2)) {
      final separator = segment.indexOf(':');
      if (separator <= 0) continue;
      final key = segment.substring(0, separator).trim().toLowerCase();
      if (key != 'name') continue;
      final value = segment.substring(separator + 1).trim();
      if (value.isNotEmpty) name = value;
    }

    return SsiCenterCode(centerId: centerId, name: name);
  }
}
