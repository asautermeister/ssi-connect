import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings_de.dart';
import 'package:ssi_connect/ui/format.dart';

const _s = AppStringsDe();

void main() {
  group('Fmt', () {
    test('formats dates in German day-first order with padding', () {
      expect(Fmt.date(DateTime(2025, 1, 5)), '05.01.2025');
      expect(Fmt.date(DateTime(2025, 11, 8)), '08.11.2025');
    });

    test('formats times with padded hours and minutes', () {
      expect(Fmt.time(DateTime(2025, 11, 8, 8, 6)), '08:06');
    });

    test('names weekdays', () {
      // 8 Nov 2025 was a Saturday.
      expect(Fmt.weekday(DateTime(2025, 11, 8), _s), 'Sa');
    });

    test('uses a comma as the decimal separator for display', () {
      expect(Fmt.decimal(12.8), '12,8');
      expect(Fmt.meters(44), '44,0');
      expect(Fmt.celsius(26.05), '26,1');
    });

    test('renders missing values as an en dash rather than blank', () {
      expect(Fmt.decimal(null), Fmt.none);
      expect(Fmt.meters(null), Fmt.none);
      expect(Fmt.celsius(null), Fmt.none);
      expect(Fmt.minutes(null), Fmt.none);
    });

    test('renders duration as whole minutes', () {
      expect(Fmt.minutes(const Duration(minutes: 92, seconds: 40)), '92');
    });
  });
}
