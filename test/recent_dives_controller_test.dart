import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/dives/dive_cache_repository.dart';
import 'package:ssi_connect/dives/recent_dives_controller.dart';
import 'package:ssi_connect/garmin/garmin_auth_exceptions.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';

/// Stands in for the keystore-backed cache, which needs a platform.
class _InMemoryCache extends DiveCacheRepository {
  final stored = <String, CachedDives>{};

  @override
  Future<CachedDives?> load(String accountId) async => stored[accountId];

  @override
  Future<void> save(String accountId, List<Dive> dives) async {
    stored[accountId] = CachedDives(dives: dives, fetchedAt: DateTime.now());
  }

  @override
  Future<void> clear(String accountId) async => stored.remove(accountId);
}

RecentDivesController _controller([_InMemoryCache? cache]) =>
    RecentDivesController(cache: cache ?? _InMemoryCache());

GarminAccount _account(String id) => GarminAccount(
  id: id,
  email: '$id@example.com',
  displayName: id,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
);

Dive _dive(String id, DateTime at) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: 20,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 40),
  locationName: null,
);

void main() {
  group('RecentDivesController', () {
    test('merges accounts and sorts newest first', () async {
      final andreas = _account('andreas');
      final marie = _account('marie');
      final controller = _controller();

      await controller.load(
        accounts: [andreas, marie],
        fetch: (account) async => account.id == 'andreas'
            ? [
                _dive('a1', DateTime(2025, 11, 8, 8)),
                _dive('a2', DateTime(2025, 11, 1, 8)),
              ]
            : [_dive('m1', DateTime(2025, 11, 5, 8))],
      );

      final recent = controller.recent([andreas, marie]);
      expect(recent.map((r) => r.dive.id), ['a1', 'm1', 'a2']);
      // Each dive knows whose it is, so the card can name the diver.
      expect(recent.first.account.id, 'andreas');
      expect(recent[1].account.id, 'marie');
    });

    test('caps the merged list', () async {
      final account = _account('a');
      final controller = _controller();

      await controller.load(
        accounts: [account],
        fetch: (_) async => [
          for (var day = 1; day <= 9; day++)
            _dive('d$day', DateTime(2025, 11, day)),
        ],
      );

      expect(controller.recent([account], limit: 5), hasLength(5));
    });

    test('one failing account does not take the others down', () async {
      final broken = _account('broken');
      final working = _account('working');
      final controller = _controller();

      await controller.load(
        accounts: [broken, working],
        fetch: (account) async {
          if (account.id == 'broken') throw StateError('login abgelaufen');
          return [_dive('w1', DateTime(2025, 11, 8))];
        },
      );

      expect(controller.recent([broken, working]).map((r) => r.dive.id), [
        'w1',
      ]);
      expect(controller.failedCount, 1);
      expect(controller.forAccount('broken').hasError, isTrue);
      expect(controller.forAccount('working').hasError, isFalse);
    });

    test('exposes the newest dive per account for its card', () async {
      final account = _account('a');
      final controller = _controller();

      await controller.load(
        accounts: [account],
        // Deliberately out of order: the source is not sorted for us.
        fetch: (_) async => [
          _dive('old', DateTime(2025, 10, 1)),
          _dive('new', DateTime(2025, 11, 8)),
        ],
      );

      expect(controller.forAccount('a').latest?.id, 'new');
    });

    test('asking again for the same accounts does not re-fetch', () async {
      final account = _account('a');
      final controller = _controller();
      var fetches = 0;

      Future<List<Dive>> fetch(GarminAccount _) async {
        fetches++;
        return [_dive('d', DateTime(2025, 11, 8))];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.load(accounts: [account], fetch: fetch);

      // The start screen asks on every build, so this has to be free.
      expect(fetches, 1);
    });

    test('force re-fetches, which is what pull-to-refresh needs', () async {
      final account = _account('a');
      final controller = _controller();
      var fetches = 0;

      Future<List<Dive>> fetch(GarminAccount _) async {
        fetches++;
        return [_dive('d', DateTime(2025, 11, 8))];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.load(accounts: [account], fetch: fetch, force: true);

      expect(fetches, 2);
    });

    test('a new account triggers a fetch without forcing', () async {
      final first = _account('a');
      final second = _account('b');
      final controller = _controller();
      final asked = <String>[];

      Future<List<Dive>> fetch(GarminAccount account) async {
        asked.add(account.id);
        return const [];
      }

      await controller.load(accounts: [first], fetch: fetch);
      await controller.load(accounts: [first, second], fetch: fetch);

      expect(asked, ['a', 'a', 'b']);
    });

    test('a removed account leaves no dives behind', () async {
      final first = _account('a');
      final second = _account('b');
      final controller = _controller();

      await controller.load(
        accounts: [first, second],
        fetch: (_) async => [_dive('d', DateTime(2025, 11, 8))],
      );
      await controller.load(
        accounts: [first],
        fetch: (_) async => [_dive('d', DateTime(2025, 11, 8))],
      );

      expect(controller.forAccount('b').dives, isEmpty);
      expect(controller.recent([first]), hasLength(1));
    });

    test('starts out empty until a load runs', () {
      final controller = _controller();

      expect(controller.recent([_account('a')]), isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.hasLoaded, isFalse);
    });
  });

  group('RecentDivesController caching', () {
    test('writes fetched dives to the cache', () async {
      final cache = _InMemoryCache();
      final account = _account('a');

      await _controller(cache).load(
        accounts: [account],
        fetch: (_) async => [_dive('d1', DateTime(2025, 11, 8))],
      );

      expect(cache.stored['a']?.dives.single.id, 'd1');
    });

    test('keeps the cached dives when the fetch fails', () async {
      final cache = _InMemoryCache()
        ..stored['a'] = CachedDives(
          dives: [_dive('cached', DateTime(2025, 11, 1))],
          fetchedAt: DateTime(2025, 11, 1, 18),
        );
      final controller = _controller(cache);

      await controller.load(
        accounts: [_account('a')],
        fetch: (_) async => throw GarminAuthException(
          GarminAuthErrorType.offline,
          'Keine Internetverbindung.',
        ),
      );

      final load = controller.forAccount('a');
      // A dive from this morning is still worth a QR code at a dive site
      // with no reception.
      expect(load.dives.single.id, 'cached');
      expect(load.isFromCache, isTrue);
      expect(load.fetchedAt, DateTime(2025, 11, 1, 18));
      expect(load.isOffline, isTrue);
    });

    test('a successful fetch replaces the cached dives and the note', () async {
      final cache = _InMemoryCache()
        ..stored['a'] = CachedDives(
          dives: [_dive('cached', DateTime(2025, 11, 1))],
          fetchedAt: DateTime(2025, 11, 1),
        );
      final controller = _controller(cache);

      await controller.load(
        accounts: [_account('a')],
        fetch: (_) async => [_dive('fresh', DateTime(2025, 11, 8))],
      );

      final load = controller.forAccount('a');
      expect(load.dives.single.id, 'fresh');
      expect(load.isFromCache, isFalse);
      expect(controller.isShowingCache, isFalse);
    });

    test('offline is only reported when nothing reached Garmin', () async {
      final controller = _controller();

      await controller.load(
        accounts: [_account('a'), _account('b')],
        fetch: (account) async {
          throw GarminAuthException(
            account.id == 'a'
                ? GarminAuthErrorType.offline
                // Reached Garmin, so "check your connection" would send the
                // user looking in the wrong place.
                : GarminAuthErrorType.rateLimited,
            'x',
          );
        },
      );

      expect(controller.forAccount('a').isOffline, isTrue);
      expect(controller.forAccount('b').isOffline, isFalse);
      expect(controller.isOffline, isFalse);
    });

    test('offline is reported when every account failed that way', () async {
      final controller = _controller();

      await controller.load(
        accounts: [_account('a'), _account('b')],
        fetch: (_) async =>
            throw GarminAuthException(GarminAuthErrorType.offline, 'x'),
      );

      expect(controller.isOffline, isTrue);
    });

    test('forgetting an account wipes it from memory and the device', () async {
      final cache = _InMemoryCache();
      final account = _account('a');
      final controller = _controller(cache);
      await controller.load(
        accounts: [account],
        fetch: (_) async => [_dive('d1', DateTime(2025, 11, 8))],
      );

      await controller.forget('a');

      expect(controller.forAccount('a').dives, isEmpty);
      expect(cache.stored.containsKey('a'), isFalse);
    });

    test('after forgetting, the next load actually fetches again', () async {
      final account = _account('a');
      final controller = _controller();
      var fetches = 0;

      Future<List<Dive>> fetch(GarminAccount _) async {
        fetches++;
        return [_dive('d', DateTime(2025, 11, 8))];
      }

      await controller.load(accounts: [account], fetch: fetch);
      await controller.forget('a');
      await controller.load(accounts: [account], fetch: fetch);

      // Without resetting the "already loaded" marker this would
      // short-circuit and leave the screen empty.
      expect(fetches, 2);
    });
  });
}
