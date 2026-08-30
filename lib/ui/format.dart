import '../l10n/app_strings.dart';

/// Shared value formatting, so the same dive reads identically in the list,
/// the detail view and the QR screen.
///
/// Numbers stay German-style (comma decimal separator, dd.MM.yyyy) in both
/// languages: the app is used next to a Garmin watch and an SSI logbook set
/// to the same conventions, and a depth that reads `28.0` here and `28,0`
/// there invites a misread. Only the words - weekday names, "at" - follow
/// the chosen language.
///
/// Note this is display only - [SsiQrPayloadBuilder] formats independently,
/// because the SSI payload requires a dot.
class Fmt {
  const Fmt._();

  /// Placeholder for a value Garmin didn't provide. An en dash rather than
  /// "-" so it reads as "no value" instead of a minus sign.
  static const none = '–';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

  /// The same date with a two-digit year, for lines that already carry a
  /// weekday and a clock time. A dive is dated by when it was, not by which
  /// century - and next to "Fr" and "07:50 Uhr" the full year is the part
  /// nobody reads.
  static String shortDate(DateTime d) =>
      '${_two(d.day)}.${_two(d.month)}.${_two(d.year % 100)}';

  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  /// The clock time as a phrase - German puts "Uhr" after it, English puts
  /// nothing at all.
  static String timeOfDay(DateTime d, AppStrings s) => s.atTime(time(d));

  static String weekday(DateTime d, AppStrings s) =>
      s.weekdaysShort[d.weekday - 1];

  /// One decimal, comma separator. Returns null-safe placeholder.
  static String decimal(double? value) {
    if (value == null) return none;
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String meters(double? value) => value == null ? none : decimal(value);

  static String celsius(double? value) => value == null ? none : decimal(value);

  static String minutes(Duration? duration) =>
      duration == null ? none : '${duration.inMinutes}';
}
