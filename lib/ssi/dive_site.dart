import 'dart:math' as math;

/// A dive site the user has matched to an SSI site number.
///
/// SSI's dive QR code carries `site:303948` - a number from SSI's own site
/// database. Garmin has no idea about it, so the pairing has to come from
/// somewhere else: the number is read off an SSI export, or looked up on
/// SSI's own MyDiveGuide or a site that mirrors the same numbering, and
/// entered once. From then on the position is what recognises the place
/// again.
///
/// That the numbering is real and externally resolvable was confirmed
/// against two of the user's own dives, whose `site:` values resolve to the
/// right places on a public dive-site directory.
class DiveSite {
  const DiveSite({
    required this.siteId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// SSI's number for the site - what ends up in the QR code.
  final String siteId;

  /// What the user calls it. Free text: this is a label for the list, not
  /// something SSI ever sees.
  final String name;

  /// Where it is. Taken from the dive it was first matched to, so it is
  /// the entry point of an actual dive rather than a map centre.
  final double latitude;
  final double longitude;

  /// How far [latitude]/[longitude] are from a position, in metres.
  ///
  /// Equirectangular approximation rather than haversine: over the few
  /// kilometres that matter here the difference is centimetres, and the
  /// simpler formula has no edge cases to get wrong.
  double distanceMetresTo(double lat, double lon) {
    const metresPerDegree = 111320.0;
    final meanLatRadians = (latitude + lat) / 2 * math.pi / 180;
    final dx = (lon - longitude) * metresPerDegree * math.cos(meanLatRadians);
    final dy = (lat - latitude) * metresPerDegree;
    return math.sqrt(dx * dx + dy * dy);
  }

  Map<String, dynamic> toJson() => {
    'siteId': siteId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory DiveSite.fromJson(Map<String, dynamic> json) => DiveSite(
    siteId: json['siteId'] as String,
    name: json['name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  /// Two entries are the same site when the number matches - the name is
  /// what the user called it, not what it is.
  @override
  bool operator ==(Object other) => other is DiveSite && other.siteId == siteId;

  @override
  int get hashCode => siteId.hashCode;

  /// Pulls an SSI site number out of whatever the user pasted or typed.
  ///
  /// Accepts a bare number, or a URL from a dive-site directory that
  /// carries the number in its path - SSI's own MyDiveGuide writes
  /// `.../divesite/divespot-portugal-283479`, others `.../location-214234`.
  /// Both end in the number, which is the only part that matters.
  ///
  /// Returns null when there is no number to be found, rather than
  /// guessing: a wrong site number files the dive at the wrong place, and
  /// SSI gives no feedback that it happened.
  static String? parseSiteId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // A plain number, as typed off a card or a screen.
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;

    // Otherwise the last run of digits in the text, which is where every
    // observed URL puts it. Anchored to the end so a country code or a
    // year earlier in the path can't win.
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(trimmed);
    return match?.group(1);
  }
}
