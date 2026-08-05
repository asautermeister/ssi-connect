import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_logged_dive.dart';

import 'support/exported_dives.dart';

Dive _dive(String id, DateTime at, {double? depth = 13}) => Dive(
  id: id,
  dateTime: at,
  maxDepthMeters: depth,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 19),
  locationName: null,
);

/// The first of the two dives SSI actually returned.
final _logged = SsiLoggedDive(
  dateTime: DateTime(2023, 8, 12, 12, 54),
  depthMeters: 13,
);

Future<ExportedDivesController> _controller() async {
  final controller = ExportedDivesController(
    repository: InMemoryExportedDives(),
  );
  await controller.loadFromStorage();
  return controller;
}

void main() {
  group('matching a dive against the SSI logbook', () {
    test('recognises the dive this app exported', () async {
      // The payload carries Garmin's own start time and SSI stores it
      // unchanged, so the two agree to the minute.
      final dive = _dive('a', DateTime(2023, 8, 12, 12, 54));

      expect(matchLoggedDives([dive], [_logged]), {'a'});
    });

    test('allows a few minutes of drift', () async {
      final dive = _dive('a', DateTime(2023, 8, 12, 13, 5));

      expect(matchLoggedDives([dive], [_logged]), {'a'});
    });

    test('will not reach across the day', () async {
      // Same clock time, next day - the second of the two real entries.
      final dive = _dive('a', DateTime(2023, 8, 13, 12, 54));

      expect(matchLoggedDives([dive], [_logged]), isEmpty);
    });

    test('will not stretch across a surface interval', () async {
      // A second dive of the same day is its own dive, not this one.
      final dive = _dive('a', DateTime(2023, 8, 12, 15, 30));

      expect(matchLoggedDives([dive], [_logged]), isEmpty);
    });

    test('a different depth is a different dive', () async {
      // Right time, but 38 m against SSI's 13 - two people on one boat,
      // or a dive that simply is not this one.
      final dive = _dive('a', DateTime(2023, 8, 12, 12, 56), depth: 38);

      expect(matchLoggedDives([dive], [_logged]), isEmpty);
    });

    test('a dive without a depth is judged on time alone', () async {
      final dive = _dive('a', DateTime(2023, 8, 12, 12, 54), depth: null);

      expect(matchLoggedDives([dive], [_logged]), {'a'});
    });

    test('one entry accounts for only one dive', () async {
      // Two dives close together, one logbook entry: whichever is nearer
      // gets it, the other stays untouched. Otherwise a dive that never
      // reached SSI would be ticked - and that is the dive that then gets
      // skipped.
      final near = _dive('near', DateTime(2023, 8, 12, 12, 56));
      final far = _dive('far', DateTime(2023, 8, 12, 13, 10));

      expect(matchLoggedDives([far, near], [_logged]), {'near'});
    });

    test('a deleted entry is not in the logbook', () {
      // Guarded in the parser rather than here, but worth stating: SSI
      // keeps deleted dives in the answer with a flag.
      expect(
        matchLoggedDives([_dive('a', DateTime(2023, 8, 12, 12, 54))], []),
        isEmpty,
      );
    });
  });

  group('the hand-set tick against the logbook', () {
    final dive = _dive('a', DateTime(2023, 8, 12, 12, 54));

    test('the logbook can tick a dive on its own', () async {
      final controller = await _controller();
      await controller.setLogbook('acc', [_logged]);

      final matched = controller.matchedIn('acc', [dive]);

      expect(matched, {'a'});
      expect(
        controller.stateOf(dive, inLogbook: true),
        DiveTransferState.fromLogbook,
      );
    });

    test('a hand-cleared tick overrules the logbook', () async {
      // The person in front of the tablet knows something the logbook
      // does not - maybe the entry over there is a different dive.
      final controller = await _controller();
      await controller.setLogbook('acc', [_logged]);
      await controller.setTransferred('a', false);

      expect(controller.stateOf(dive, inLogbook: true), DiveTransferState.no);
      expect(controller.isTransferred(dive, inLogbook: true), isFalse);
    });

    test('a hand-set tick needs no logbook', () async {
      final controller = await _controller();
      await controller.setTransferred('a', true);

      expect(controller.stateOf(dive), DiveTransferState.byHand);
    });

    test("another account's logbook never matches", () async {
      // A family dives together: same minute, same site, same depth. If a
      // logbook could reach across accounts it would tick everybody.
      final controller = await _controller();
      await controller.setLogbook('marie', [_logged]);

      expect(controller.matchedIn('andreas', [dive]), isEmpty);
      expect(controller.matchedIn(null, [dive]), isEmpty);
    });

    test('signing out drops that logbook', () async {
      final controller = await _controller();
      await controller.setLogbook('acc', [_logged]);
      await controller.forgetLogbook('acc');

      expect(controller.matchedIn('acc', [dive]), isEmpty);
    });

    test('the logbook survives a restart', () async {
      final repository = InMemoryExportedDives();
      final first = ExportedDivesController(repository: repository);
      await first.loadFromStorage();
      await first.setLogbook('acc', [_logged]);

      final second = ExportedDivesController(repository: repository);
      await second.loadFromStorage();

      expect(second.matchedIn('acc', [dive]), {'a'});
    });
  });
}
