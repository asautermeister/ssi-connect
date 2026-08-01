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
