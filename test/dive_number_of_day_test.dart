import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/models/dive.dart';

Dive _dive(String id, DateTime dateTime) => Dive(
  id: id,
  dateTime: dateTime,
  maxDepthMeters: null,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: null,
  locationName: null,
);

void main() {
  group('assignDiveNumbersOfDay', () {
    test('numbers same-day dives in chronological order', () {
      final morning = _dive('a', DateTime(2024, 6, 1, 8, 0));
      final noon = _dive('b', DateTime(2024, 6, 1, 12, 0));
      final afternoon = _dive('c', DateTime(2024, 6, 1, 15, 0));

      // Deliberately passed in a different (e.g. "most recent first") order.
      final result = assignDiveNumbersOfDay([afternoon, noon, morning]);

      final byId = {for (final d in result) d.id: d.diveNumberOfDay};
      expect(byId['a'], 1);
      expect(byId['b'], 2);
      expect(byId['c'], 3);
    });

    test('restarts numbering for each calendar day', () {
      final day1 = _dive('a', DateTime(2024, 6, 1, 8, 0));
      final day2First = _dive('b', DateTime(2024, 6, 2, 8, 0));
      final day2Second = _dive('c', DateTime(2024, 6, 2, 14, 0));

      final result = assignDiveNumbersOfDay([day1, day2First, day2Second]);

      final byId = {for (final d in result) d.id: d.diveNumberOfDay};
      expect(byId['a'], 1);
      expect(byId['b'], 1);
      expect(byId['c'], 2);
    });

    test('preserves the input list order, only changing dive numbers', () {
      final first = _dive('a', DateTime(2024, 6, 1, 15, 0));
      final second = _dive('b', DateTime(2024, 6, 1, 8, 0));

      final result = assignDiveNumbersOfDay([first, second]);

      expect(result.map((d) => d.id).toList(), ['a', 'b']);
      expect(result[0].diveNumberOfDay, 2);
      expect(result[1].diveNumberOfDay, 1);
    });
  });
}
