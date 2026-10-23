/// One value, made safe to put into a payload segment.
///
/// `;` separates fields, so a value carrying one grows into extra fields on
/// whatever scans the code: a last name `Müller;leaderNr:110890` would show
/// that person as an SSI Professional on the receiving device.
///
/// **The text is not this device's own.** Names arrive with the SSI logbook
/// import, so they are whatever the other person put in their own profile -
/// and this device then hands them on as a QR code. Typed in by hand it is
/// the same story.
///
/// A comma takes the place of the semicolon rather than nothing: SSI writes
/// commas in its own centre names (`Nero-Sport Diving Center, Zakynthos`),
/// so the name stays readable, and dropping the character would alter it
/// silently. Line breaks go the same way, because a payload is one line.
///
/// Only the *building* side needs this. Parsing splits on `;` first, so a
/// semicolon can never end up inside a field when a code is scanned.
String ssiPayloadValue(String value) =>
    value.replaceAll(RegExp(r'[;\r\n]+'), ',').trim();

/// A scanned SSI payload broken into its parts, for inspecting codes the
/// app doesn't understand yet.
///
/// Every SSI code seen so far has the same shape: a leading marker (`dive`,
/// `buddy`), then some bare positional segments, then `key:value` pairs -
/// all semicolon-separated. Splitting it this way is enough to read a field
/// name off a real export instead of guessing it.
class SsiPayloadFields {
  const SsiPayloadFields({
    required this.marker,
    required this.positional,
    required this.fields,
  });

  /// First segment: `dive` for a dive export, `buddy` for a member code.
  final String marker;

  /// Bare segments after the marker, e.g. `noid` in a dive export or the
  /// member number in a buddy code.
  final List<String> positional;

  /// The `key:value` pairs, in the order they appeared.
  final Map<String, String> fields;

  static SsiPayloadFields parse(String raw) {
    final segments = raw.trim().split(';');
    final positional = <String>[];
    final fields = <String, String>{};

    for (final segment in segments.skip(1)) {
      final separator = segment.indexOf(':');
      if (separator <= 0) {
        // Bare segment. Skip empties, which a trailing ';' produces.
        final trimmed = segment.trim();
        if (trimmed.isNotEmpty) positional.add(trimmed);
        continue;
      }
      fields[segment.substring(0, separator).trim()] = segment
          .substring(separator + 1)
          .trim();
    }

    return SsiPayloadFields(
      marker: segments.first.trim(),
      positional: positional,
      fields: fields,
    );
  }
}
