/// Shared value formatting, so the same dive reads identically in the list,
/// the detail view and the QR screen.
///
/// German conventions throughout (the app's only language): dd.MM.yyyy and
/// a comma decimal separator for displayed values. Note this is display
/// only - [SsiQrPayloadBuilder] formats independently, because the SSI
/// payload requires a dot.
class Fmt {
  const Fmt._();

  /// Placeholder for a value Garmin didn't provide. An en dash rather than
  /// "-" so it reads as "no value" instead of a minus sign.
  static const none = '–';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  static String weekday(DateTime d) =>
      const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][d.weekday - 1];

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
