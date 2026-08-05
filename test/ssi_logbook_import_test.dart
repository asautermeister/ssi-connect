import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_api_client.dart';
import 'package:ssi_connect/ssi/ssi_api_exceptions.dart';
import 'package:ssi_connect/ssi/ssi_session.dart';

/// Answers whatever the test says, and records what was asked.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.reply);

  /// Called with the form-encoded request body.
  final String Function(String requestBody) reply;

  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    lastBody = utf8.decode(bytes);
    return ResponseBody.fromString(
      reply(lastBody!),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(SsiApiClient, _FakeAdapter) _clientAnswering(String Function(String) reply) {
  final adapter = _FakeAdapter(reply);
  final dio = Dio()..httpClientAdapter = adapter;
  return (SsiApiClient(dio: dio), adapter);
}

/// The `logbook_sites` entry SSI actually returned, trimmed to the fields
/// that matter plus the two that are traps.
const _rasIlHobz = {
  'odin_dive_sites_id': 2595,
  'odin_dive_sites_name': 'Ras il-Hobz',
  'odin_dive_sites_lat': 36.0166,
  'odin_dive_sites_lon': 14.2798,
  'country_lalo': '35.946153,14.384604',
  'odin_dive_sites_address': 'Horgenweg, 8037 Zurich Zurich, Switzerland',
  'odin_dive_sites_regions_name': 'Gozo',
  'bow': 'salt',
  'myloggedDives': 1,
};

const _session = SsiSession(email: 'a@b.c', token: 'tok', memberId: 3837926);

class _InMemoryRepository extends DiveSiteRepository {
  _InMemoryRepository([this.stored = const []]);

  List<DiveSite> stored;

  @override
  Future<List<DiveSite>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<DiveSite> sites) async => stored = sites;
}

Future<DiveSitesController> _controllerWith(List<DiveSite> sites) async {
  final controller = DiveSitesController(
    repository: _InMemoryRepository(sites),
  );
  await controller.loadFromStorage();
  return controller;
}

void main() {
  group('SsiApiClient.authenticate', () {
    test('takes the token and the member number from the answer', () async {
      final (client, adapter) = _clientAnswering(
        (_) => jsonEncode({
          'authenticated': true,
          'token': '2dcb3e0679d949634615fa0cdaf069fa',
          'mid': 3837926,
          'imperial': false,
          'authenticated_email': 'diver@example.com',
        }),
      );

      final session = await client.authenticate(
        email: 'typed@example.com',
        password: 'secret',
      );

      expect(session.token, '2dcb3e0679d949634615fa0cdaf069fa');
      expect(session.memberId, 3837926);
      // SSI's spelling of the address wins over what was typed.
      expect(session.email, 'diver@example.com');
      expect(adapter.lastBody, contains('what=authenticate'));
    });

    test('sends the password in the body, never in the URL', () async {
      // A GET would put it in the query string, where it lands in server
      // logs and in this app's own diagnostic log as part of the request
      // line - somewhere redaction cannot reach.
      final (client, adapter) = _clientAnswering(
        (_) => jsonEncode({'authenticated': true, 'token': 't'}),
      );

      await client.authenticate(email: 'a@b.c', password: 'secret');

      expect(adapter.lastBody, contains('p=secret'));
    });

    test('a refused login is not a connection problem', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({'authenticated': false}),
      );

      await expectLater(
        client.authenticate(email: 'a@b.c', password: 'wrong'),
        throwsA(
          isA<SsiApiException>().having(
            (e) => e.type,
            'type',
            SsiApiErrorType.invalidCredentials,
          ),
        ),
      );
    });

    test('an answer that is not JSON is reported, not parsed halfway', () {
      // A WAF block page or a maintenance notice arrives as HTML.
      final (client, _) = _clientAnswering((_) => '<html>go away</html>');

      expect(
        client.authenticate(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<SsiApiException>().having(
            (e) => e.type,
            'type',
            SsiApiErrorType.connectionError,
          ),
        ),
      );
    });
  });

  group('SsiApiClient.loadLogbook', () {
    test('reads number, name and position of a real entry', () async {
      final (client, adapter) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [_rasIlHobz],
        }),
      );

      final sites = (await client.loadLogbook(_session)).sites;

      expect(sites, hasLength(1));
      expect(sites.single.siteId, '2595');
      expect(sites.single.name, 'Ras il-Hobz');
      expect(sites.single.latitude, closeTo(36.0166, 0.00001));
      expect(sites.single.longitude, closeTo(14.2798, 0.00001));
      expect(adapter.lastBody, contains('what=get_divelog'));
    });

    test('a four-digit number is a real number', () {
      // SSI's own page for this site ends in 2595. Nothing says a site id
      // has six digits, and truncating or padding it would file the dive
      // at a different place entirely.
      expect(DiveSite.parseSiteId('2595'), '2595');
    });

    test('ignores the country centre, which is 10 km off', () async {
      // `country_lalo` looks exactly like coordinates and is the centre of
      // Malta, not of this site.
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [_rasIlHobz],
        }),
      );

      final site = (await client.loadLogbook(_session)).sites.single;

      expect(site.latitude, isNot(closeTo(35.946153, 0.001)));
      expect(site.longitude, isNot(closeTo(14.384604, 0.001)));
    });

    test('drops entries that have no usable position', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [
            {'odin_dive_sites_id': 1, 'odin_dive_sites_name': 'Ohne'},
            {
              'odin_dive_sites_id': 2,
              'odin_dive_sites_name': 'Nullinsel',
              'odin_dive_sites_lat': 0,
              'odin_dive_sites_lon': 0,
            },
            {
              'odin_dive_sites_id': 3,
              'odin_dive_sites_name': 'Unmöglich',
              'odin_dive_sites_lat': 999,
              'odin_dive_sites_lon': 14,
            },
            _rasIlHobz,
          ],
        }),
      );

      final sites = (await client.loadLogbook(_session)).sites;

      // A site without a position can never be suggested, and a wrong one
      // would be suggested at the wrong place.
      expect(sites.map((s) => s.siteId), ['2595']);
    });

    test('a site without a name is called by its number', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [
            {
              'odin_dive_sites_id': 4711,
              'odin_dive_sites_name': '  ',
              'odin_dive_sites_lat': 36.0,
              'odin_dive_sites_lon': 14.0,
            },
          ],
        }),
      );

      expect(
        (await client.loadLogbook(_session)).sites.single.name,
        'site:4711',
      );
    });

    test('a missing logbook reads as an expired session', () async {
      // SSI answers a stale token with a body, not an HTTP status, so
      // "no sites" has to be told apart from "no dives yet".
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({'error': 'nope'}),
      );

      await expectLater(
        client.loadLogbook(_session),
        throwsA(
          isA<SsiApiException>().having(
            (e) => e.type,
            'type',
            SsiApiErrorType.invalidCredentials,
          ),
        ),
      );
    });

    test('an empty logbook is not an error', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({'logbook_sites': []}),
      );

      expect((await client.loadLogbook(_session)).sites, isEmpty);
    });
  });

  group('SsiApiClient buddies', () {
    /// The `logbook_buddies` entry SSI actually returned.
    const andreas = {
      'id': 1966429,
      'master_id': 3902893,
      'buddy_master_id': 3902893,
      'firstname': 'Andreas',
      'lastname': 'Sautermeister',
      'dob': '1984-04-10',
      'email': 'someone@example.com',
      'phone': '    ',
      'city': 'Oberhaching',
      'country': 'DEU',
      'leader_nr': '',
      'image': 'https://my.divessi.com/data/user_files/pic/3902893.png',
      'deleted': 0,
    };

    test('reads the fields a scanned buddy code also carries', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [],
          'logbook_buddies': [andreas],
        }),
      );

      final buddy = (await client.loadLogbook(_session)).buddies.single;

      expect(buddy.memberId, '3902893');
      expect(buddy.fullName, 'Andreas Sautermeister');
      expect(buddy.email, 'someone@example.com');
    });

    test('leaves the personal data of third parties behind', () async {
      // Date of birth, home town, telephone number and photo are in the
      // answer and have no use here. A family tablet is no place to
      // accumulate them, so they never reach storage.
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [],
          'logbook_buddies': [andreas],
        }),
      );

      final stored = jsonEncode(
        (await client.loadLogbook(_session)).buddies.single.toJson(),
      );

      expect(stored, isNot(contains('1984-04-10')));
      expect(stored, isNot(contains('Oberhaching')));
      expect(stored, isNot(contains('divessi.com')));
      expect(stored, isNot(contains('DEU')));
    });

    test('an empty professional number is absent, not blank', () async {
      // `leader_nr` is "" for ordinary members, and SSI writes some blank
      // fields as spaces. Either would otherwise become an empty value in
      // the QR payload.
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [],
          'logbook_buddies': [
            {...andreas, 'leader_nr': '   ', 'email': ''},
          ],
        }),
      );

      final buddy = (await client.loadLogbook(_session)).buddies.single;

      expect(buddy.leaderNumber, isNull);
      expect(buddy.email, isNull);
      expect(buddy.isProfessional, isFalse);
      expect(
        buddy.toPayload(),
        'buddy;3902893;firstName:Andreas;'
        'lastName:Sautermeister',
      );
    });

    test('keeps the professional number when there is one', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [],
          'logbook_buddies': [
            {...andreas, 'leader_nr': '110890'},
          ],
        }),
      );

      final buddy = (await client.loadLogbook(_session)).buddies.single;

      expect(buddy.leaderNumber, '110890');
      expect(buddy.isProfessional, isTrue);
    });

    test('skips deleted buddies and entries without a number', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [],
          'logbook_buddies': [
            {...andreas, 'deleted': 1},
            {'firstname': 'Niemand'},
            andreas,
          ],
        }),
      );

      expect(
        (await client.loadLogbook(_session)).buddies.map((b) => b.memberId),
        ['3902893'],
      );
    });

    test('a logbook without buddies is not an error', () async {
      final (client, _) = _clientAnswering(
        (_) => jsonEncode({
          'logbook_sites': [_rasIlHobz],
        }),
      );

      final logbook = await client.loadLogbook(_session);

      expect(logbook.buddies, isEmpty);
      expect(logbook.sites, hasLength(1));
    });
  });

  group('DiveSitesController.addAllNew', () {
    test('adds what is new and reports how much', () async {
      final controller = await _controllerWith([]);

      final added = await controller.addAllNew(const [
        DiveSite(
          siteId: '2595',
          name: 'Ras il-Hobz',
          latitude: 36.0166,
          longitude: 14.2798,
        ),
        DiveSite(
          siteId: '2596',
          name: 'Xatt l-Ahmar',
          latitude: 36.0200,
          longitude: 14.2830,
        ),
      ]);

      expect(added, 2);
      expect(controller.sites, hasLength(2));
    });

    test('leaves a site the user already has exactly as it was', () async {
      // The stored name may have been typed by the user, and the stored
      // position came from one of their own dives - which points at the
      // entry they actually use.
      final controller = await _controllerWith(const [
        DiveSite(
          siteId: '2595',
          name: 'Hausriff',
          latitude: 36.0000,
          longitude: 14.2000,
        ),
      ]);

      final added = await controller.addAllNew(const [
        DiveSite(
          siteId: '2595',
          name: 'Ras il-Hobz',
          latitude: 36.0166,
          longitude: 14.2798,
        ),
      ]);

      expect(added, 0);
      expect(controller.sites.single.name, 'Hausriff');
      expect(controller.sites.single.latitude, closeTo(36.0, 0.00001));
    });

    test('the same site twice in one import counts once', () async {
      final controller = await _controllerWith([]);

      final added = await controller.addAllNew(const [
        DiveSite(siteId: '1', name: 'A', latitude: 36, longitude: 14),
        DiveSite(siteId: '1', name: 'A nochmal', latitude: 36, longitude: 14),
      ]);

      expect(added, 1);
      expect(controller.sites, hasLength(1));
    });

    test('writes through to storage once', () async {
      final repository = _InMemoryRepository();
      final controller = DiveSitesController(repository: repository);
      await controller.loadFromStorage();

      await controller.addAllNew(const [
        DiveSite(siteId: '1', name: 'A', latitude: 36, longitude: 14),
      ]);

      expect(repository.stored, hasLength(1));
    });
  });
}
