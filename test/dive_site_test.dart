import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings_de.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_qr_payload_builder.dart';

const _s = AppStringsDe();

class _InMemoryRepository extends DiveSiteRepository {
  _InMemoryRepository([this.stored = const []]);

  List<DiveSite> stored;

  @override
  Future<List<DiveSite>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<DiveSite> sites) async => stored = sites;
}

Dive _dive({double? lat, double? lon}) => Dive(
  id: 'a',
  dateTime: DateTime(2025, 11, 8, 9),
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
  latitude: lat,
  longitude: lon,
);

/// Nero-Sport, Zakynthos - one of the sites whose number was confirmed
/// against a public directory.
const _zakynthos = DiveSite(
  siteId: '214234',
  name: 'Hausriff',
  latitude: 37.7870,
  longitude: 20.8990,
);

void main() {
  group('DiveSite.parseSiteId', () {
    test('takes a number as typed', () {
      expect(DiveSite.parseSiteId('214234'), '214234');
      expect(DiveSite.parseSiteId('  303948  '), '303948');
    });

    test('reads the number out of a pasted address', () {
      // Both directories that carry SSI's numbering put it at the end.
      expect(
        DiveSite.parseSiteId(
          'https://www.scubago.com/de/explore/divesite/location-214234',
        ),
        '214234',
      );
      expect(
        DiveSite.parseSiteId(
          'https://www.divessi.com/en/mydiveguide/divesite/'
          'divespot-portugal-283479',
        ),
        '283479',
      );
    });

    test('a shorter number is just as valid', () {
      // Nothing says the id has to be six digits.
      expect(DiveSite.parseSiteId('.../location-4711'), '4711');
    });

    test('digits earlier in the address do not win', () {
      expect(DiveSite.parseSiteId('https://example.com/2024/de/site-99'), '99');
    });

    test('returns null rather than guessing', () {
      // A wrong number files the dive at the wrong place, and SSI never
      // says that it happened.
      expect(DiveSite.parseSiteId(''), isNull);
      expect(DiveSite.parseSiteId('   '), isNull);
      expect(DiveSite.parseSiteId('Blue Hole'), isNull);
    });
  });

  group('DiveSite.distanceMetresTo', () {
    test('is zero at its own position', () {
      expect(
        _zakynthos.distanceMetresTo(_zakynthos.latitude, _zakynthos.longitude),
        closeTo(0, 0.001),
      );
    });

    test('measures a known separation', () {
      // 0.001° of latitude is about 111 m anywhere on earth.
      expect(
        _zakynthos.distanceMetresTo(
          _zakynthos.latitude + 0.001,
          _zakynthos.longitude,
        ),
        closeTo(111, 2),
      );
    });
  });

  group('DiveSitesController.suggestionFor', () {
    test('offers the site a dive was next to', () async {
      final controller = DiveSitesController(
        repository: _InMemoryRepository([_zakynthos]),
      );
      await controller.loadFromStorage();

      final suggestion = controller.suggestionFor(
        _dive(lat: 37.7873, lon: 20.8994),
      );

      expect(suggestion?.siteId, '214234');
    });

    test('stays quiet for a dive somewhere else', () async {
      final controller = DiveSitesController(
        repository: _InMemoryRepository([_zakynthos]),
      );
      await controller.loadFromStorage();

      // A few kilometres away - well beyond the match radius.
      expect(controller.suggestionFor(_dive(lat: 37.85, lon: 20.95)), isNull);
    });

    test('stays quiet without a position', () async {
      final controller = DiveSitesController(
        repository: _InMemoryRepository([_zakynthos]),
      );
      await controller.loadFromStorage();

      expect(controller.suggestionFor(_dive()), isNull);
    });

    test('picks the nearer of two sites in reach', () async {
      const near = DiveSite(
        siteId: '1',
        name: 'Nah',
        latitude: 37.7871,
        longitude: 20.8991,
      );
      const far = DiveSite(
        siteId: '2',
        name: 'Weiter',
        latitude: 37.7900,
        longitude: 20.9010,
      );
      final controller = DiveSitesController(
        repository: _InMemoryRepository([far, near]),
      );
      await controller.loadFromStorage();

      final suggestion = controller.suggestionFor(
        _dive(lat: 37.7870, lon: 20.8990),
      );

      expect(suggestion?.siteId, '1');
    });

    test('offers every site in reach, nearest first', () async {
      // The case an SSI import makes normal: several sites along the same
      // stretch of coast, all within the match radius. Picking the closest
      // one silently would file the dive at the wrong place often enough
      // to matter, and SSI never says that it happened.
      const near = DiveSite(
        siteId: '1',
        name: 'Nah',
        latitude: 37.7871,
        longitude: 20.8991,
      );
      const middle = DiveSite(
        siteId: '2',
        name: 'Mitte',
        latitude: 37.7890,
        longitude: 20.9000,
      );
      const outside = DiveSite(
        siteId: '3',
        name: 'Weit weg',
        latitude: 37.8500,
        longitude: 20.9500,
      );
      final controller = DiveSitesController(
        repository: _InMemoryRepository([outside, middle, near]),
      );
      await controller.loadFromStorage();

      final matches = controller.suggestionsFor(
        _dive(lat: 37.7870, lon: 20.8990),
      );

      expect(matches.map((m) => m.site.siteId), ['1', '2']);
      expect(
        matches.first.distanceMetres,
        lessThan(matches.last.distanceMetres),
      );
    });

    test('ranks the whole list when the picker asks, radius or not', () async {
      // The picker shows everything - but ordered, so the place you were
      // is at the top and choosing it is a confirmation, not a search.
      const far = DiveSite(
        siteId: '3',
        name: 'Weit weg',
        latitude: 37.8500,
        longitude: 20.9500,
      );
      final controller = DiveSitesController(
        repository: _InMemoryRepository([far, _zakynthos]),
      );
      await controller.loadFromStorage();

      final ranked = controller.rankedByDistanceFrom(
        _dive(lat: 37.7870, lon: 20.8990),
      );

      expect(ranked.map((m) => m.site.siteId), ['214234', '3']);
    });

    test('without a position the picker still lists everything', () async {
      final controller = DiveSitesController(
        repository: _InMemoryRepository([_zakynthos]),
      );
      await controller.loadFromStorage();

      expect(controller.rankedByDistanceFrom(_dive()), hasLength(1));
      // But nothing is suggested - there is nothing to measure against.
      expect(controller.suggestionsFor(_dive()), isEmpty);
    });

    test('re-matching a site corrects it instead of duplicating', () async {
      final repository = _InMemoryRepository([_zakynthos]);
      final controller = DiveSitesController(repository: repository);
      await controller.loadFromStorage();

      await controller.save(
        const DiveSite(
          siteId: '214234',
          name: 'Hausriff Nord',
          latitude: 37.7871,
          longitude: 20.8991,
        ),
      );

      expect(controller.sites, hasLength(1));
      expect(controller.sites.single.name, 'Hausriff Nord');
      expect(repository.stored.single.name, 'Hausriff Nord');
    });
  });

  group('SsiQrPayloadBuilder site field', () {
    test('emits the site when one was matched', () {
      final payload = SsiQrPayloadBuilder.build(
        _dive(),
        strings: _s,
        site: _zakynthos,
      );

      expect(payload, contains('site:214234'));
      // Where SSI's own export puts it: after the measurements.
      expect(
        payload.indexOf('site:'),
        greaterThan(payload.indexOf('depth_m:')),
      );
    });

    test('says nothing when no site was matched', () {
      // An unmatched dive has to look exactly as it did before, not carry
      // an empty or guessed site.
      expect(
        SsiQrPayloadBuilder.build(_dive(), strings: _s),
        isNot(contains('site')),
      );
    });
  });

  group('DiveSite storage', () {
    test('survives a JSON round trip', () {
      final restored = DiveSite.fromJson(_zakynthos.toJson());

      expect(restored.siteId, '214234');
      expect(restored.name, 'Hausriff');
      expect(restored.latitude, closeTo(37.7870, 0.00001));
      expect(restored.longitude, closeTo(20.8990, 0.00001));
    });

    test('identifies a site by its number, not by its name', () {
      expect(
        const DiveSite(
          siteId: '1',
          name: 'Hausriff',
          latitude: 1,
          longitude: 1,
        ),
        const DiveSite(
          siteId: '1',
          name: 'House reef',
          latitude: 2,
          longitude: 2,
        ),
      );
    });
  });
}
