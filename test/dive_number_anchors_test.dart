import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_cache_repository.dart';
import 'package:ssi_connect/dives/dive_number_anchors.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/models/dive_type.dart';

class _NoCache extends DiveCacheRepository {
  @override
  Future<CachedDives?> load(String accountId) async => null;

  @override
  Future<void> save(String accountId, List<Dive> dives) async {}

  @override
  Future<void> clear(String accountId) async {}
}

class _InMemoryAnchors extends DiveNumberAnchorRepository {
  Map<String, List<DiveNumberAnchor>> stored = {};

  @override
  Future<Map<String, List<DiveNumberAnchor>>> load() async => stored;

  @override
  Future<void> save(Map<String, List<DiveNumberAnchor>> anchors) async =>
      stored = anchors;
}

/// Dive [day] of November, so the ids sort the way the dates do.
Dive _dive(int day, {DiveType type = DiveType.scuba, int? number}) => Dive(
  id: 'd$day',
  dateTime: DateTime(2026, 11, day, 10),
  maxDepthMeters: 20,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 40),
  locationName: null,
  type: type,
  diveNumber: number,
);

/// Newest first, the way every list holds them.
List<Dive> _days(Iterable<int> days) =>
    [for (final day in days) _dive(day)]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

Map<String, int?> _numbers(List<Dive> dives) => {
  for (final dive in dives) dive.id: dive.diveNumber,
};

final _account = GarminAccount(
  id: 'a',
  email: 'a@example.com',
  displayName: 'Andreas',
  session: const GarminSession.personal(accessToken: 'x', key: 'k'),
);

void main() {
  group('applyDiveNumberAnchors', () {
    test('counts both ways from one anchor', () {
      final dives = _days([1, 2, 3, 4, 5]);

      final numbered = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'd3', number: 100),
      ]);

      expect(_numbers(numbered), {
        'd5': 102,
        'd4': 101,
        'd3': 100,
        'd2': 99,
        'd1': 98,
      });
      expect(numbered.every((d) => d.diveNumberIsCounted), isTrue);
      // The list keeps its order.
      expect(numbered.map((d) => d.id), dives.map((d) => d.id));
    });

    test('freedives are skipped and keep no number', () {
      final dives = [_dive(3), _dive(2, type: DiveType.apnea), _dive(1)];

      final numbered = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'd3', number: 279),
      ]);

      expect(_numbers(numbered), {'d3': 279, 'd2': null, 'd1': 278});
    });

    test('a second anchor takes over the stretch nearer to it', () {
      // Garmin is missing two dives between d2 and d3: the person knows
      // d5 is 50 and d1 is 44.
      final dives = _days([1, 2, 3, 4, 5]);

      final numbered = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'd5', number: 50),
        DiveNumberAnchor(diveId: 'd1', number: 44),
      ]);

      expect(_numbers(numbered), {
        'd5': 50,
        'd4': 49,
        'd3': 48,
        'd2': 45,
        'd1': 44,
      });
    });

    test('a number the source sent is left alone', () {
      final dives = [_dive(2, number: 7), _dive(1)];

      final numbered = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'd1', number: 100),
      ]);

      expect(numbered.first.diveNumber, 7);
      expect(numbered.first.diveNumberIsCounted, isFalse);
    });

    test('an anchor that is not loaded numbers nothing', () {
      final dives = _days([1, 2]);

      final numbered = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'elsewhere', number: 100),
      ]);

      expect(_numbers(numbered), {'d2': null, 'd1': null});
    });

    test('no number below 1', () {
      final numbered = applyDiveNumberAnchors(_days([1, 2]), const [
        DiveNumberAnchor(diveId: 'd2', number: 1),
      ]);

      expect(_numbers(numbered), {'d2': 1, 'd1': null});
    });

    test('a carried anchor counts only when no own anchor is loaded', () {
      final dives = _days([1, 2, 3]);

      final own = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'd1', number: 10),
        DiveNumberAnchor(diveId: 'd3', number: 99, carried: true),
      ]);
      expect(own.first.diveNumber, 12);

      final carried = applyDiveNumberAnchors(dives, const [
        DiveNumberAnchor(diveId: 'paged-out', number: 10),
        DiveNumberAnchor(diveId: 'd3', number: 99, carried: true),
      ]);
      expect(carried.first.diveNumber, 99);
    });
  });

  group('RecentDivesController dive numbers', () {
    Future<(RecentDivesController, _InMemoryAnchors)> loaded(
      List<Dive> dives,
    ) async {
      final anchors = _InMemoryAnchors();
      final controller = RecentDivesController(
        cache: _NoCache(),
        anchors: anchors,
      );
      await controller.loadNumberAnchors();
      await controller.load(
        accounts: [_account],
        fetch: (_, {start = 0}) async => dives,
        notWithin: Duration.zero,
      );
      return (controller, anchors);
    }

    test('a number set on one dive numbers the account', () async {
      final (controller, anchors) = await loaded(_days([1, 2, 3]));

      await controller.setDiveNumber('a', 'd3', 279);

      expect(_numbers(controller.forAccount('a').dives), {
        'd3': 279,
        'd2': 278,
        'd1': 277,
      });
      expect(controller.findDive('d1')?.diveNumber, 277);
      expect(controller.anchoredNumber('a', 'd3'), 279);
      expect(controller.anchoredNumber('a', 'd2'), isNull);
      expect(anchors.stored['a'], isNotEmpty);
    });

    test('the count survives its anchor sliding off the first page', () async {
      // Set on the newest dive; later the first page no longer reaches it.
      final (controller, anchors) = await loaded(_days([1, 2, 3]));
      await controller.setDiveNumber('a', 'd3', 279);

      final restarted = RecentDivesController(
        cache: _NoCache(),
        anchors: anchors,
      );
      await restarted.loadNumberAnchors();
      await restarted.load(
        accounts: [_account],
        fetch: (_, {start = 0}) async => _days([3, 4, 5]),
        notWithin: Duration.zero,
      );
      await restarted.load(
        accounts: [_account],
        fetch: (_, {start = 0}) async => _days([5, 6, 7]),
        notWithin: Duration.zero,
      );

      expect(restarted.forAccount('a').dives.first.diveNumber, 283);
    });

    test('changing the number is not outvoted by the carried one', () async {
      final (controller, _) = await loaded(_days([1, 2, 3]));
      await controller.setDiveNumber('a', 'd3', 279);

      await controller.setDiveNumber('a', 'd3', 300);

      expect(controller.findDive('d3')?.diveNumber, 300);
    });

    test('clearing the only anchor takes the numbers away', () async {
      final (controller, anchors) = await loaded(_days([1, 2, 3]));
      await controller.setDiveNumber('a', 'd3', 279);

      await controller.setDiveNumber('a', 'd3', null);

      expect(_numbers(controller.forAccount('a').dives).values, [
        null,
        null,
        null,
      ]);
      expect(anchors.stored['a'], isEmpty);
    });

    test('a removed account takes its numbers along', () async {
      final (controller, anchors) = await loaded(_days([1]));
      await controller.setDiveNumber('a', 'd1', 5);

      await controller.forgetDiveNumbers('a');

      expect(anchors.stored.containsKey('a'), isFalse);
    });

    test('counted numbers stay out of the cache', () {
      final counted = _dive(
        1,
      ).copyWith(diveNumber: 5, diveNumberIsCounted: true);

      expect(counted.toJson()['diveNumber'], isNull);
      expect(_dive(1, number: 5).toJson()['diveNumber'], 5);
    });
  });
}
