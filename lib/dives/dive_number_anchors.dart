import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/dive.dart';
import '../models/dive_type.dart';

/// "This dive is number [number]" - set by hand, for an account whose
/// source sends no dive numbers (the Personal API does not).
///
/// Counting the account's dives alone does not get there: a logbook holds
/// dives that never reached Garmin, so the count runs short by however
/// many those were. The person knows the number of one dive; everything
/// else is counted from it, in both directions. Where dives are missing
/// further back, a second anchor there puts that stretch right.
class DiveNumberAnchor {
  const DiveNumberAnchor({
    required this.diveId,
    required this.number,
    this.carried = false,
  });

  final String diveId;
  final int number;

  /// Not set by anyone: the newest numbered dive, kept so the count still
  /// has a starting point once the anchor the person set has slid off the
  /// first page. Only used while none of the person's own anchors is
  /// among the loaded dives.
  final bool carried;

  Map<String, dynamic> toJson() => {
    'diveId': diveId,
    'number': number,
    if (carried) 'carried': true,
  };

  factory DiveNumberAnchor.fromJson(Map<String, dynamic> json) =>
      DiveNumberAnchor(
        diveId: json['diveId'] as String,
        number: json['number'] as int,
        carried: json['carried'] == true,
      );
}

/// Whether a dive takes part in the count. Freedives do not: a logbook
/// numbers dives on a cylinder, and a freediving session is one activity
/// with dozens of descents in it.
bool countsAsNumberedDive(Dive dive) => dive.type != DiveType.apnea;

/// Fills in [Dive.diveNumber] from [anchors] where the source left it
/// empty. A number the source sent is never overwritten.
///
/// Each dive is counted from the nearest anchor among [dives] - nearest in
/// dives, not in time - so the error of a gap further back stays behind
/// the next anchor instead of running through the whole list. Order of
/// [dives] is kept.
///
/// Works on what is loaded: the list is paged newest first without holes,
/// so every dive between a loaded dive and a loaded anchor is loaded too,
/// and the count between them is exact.
List<Dive> applyDiveNumberAnchors(
  List<Dive> dives,
  List<DiveNumberAnchor> anchors,
) {
  if (anchors.isEmpty || dives.isEmpty) return dives;

  final sequence = [
    for (final dive in dives)
      if (countsAsNumberedDive(dive)) dive,
  ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final position = {
    for (var i = 0; i < sequence.length; i++) sequence[i].id: i,
  };

  List<(int, int)> present(bool carried) => [
    for (final anchor in anchors)
      if (anchor.carried == carried && position.containsKey(anchor.diveId))
        (position[anchor.diveId]!, anchor.number),
  ];
  var points = present(false);
  if (points.isEmpty) points = present(true);
  if (points.isEmpty) return dives;

  int? numberAt(int index) {
    var best = points.first;
    for (final point in points.skip(1)) {
      if ((point.$1 - index).abs() < (best.$1 - index).abs()) best = point;
    }
    final number = best.$2 + (index - best.$1);
    return number > 0 ? number : null;
  }

  return [
    for (final dive in dives)
      if (dive.diveNumber != null || !position.containsKey(dive.id))
        dive
      else if (numberAt(position[dive.id]!) case final number?)
        dive.copyWith(diveNumber: number, diveNumberIsCounted: true)
      else
        dive,
  ];
}

/// Keeps the anchors per account in the encrypted store. Dive ids and
/// numbers only, but together they still describe someone's diving, so
/// they sit next to everything else rather than in a plain file.
class DiveNumberAnchorRepository {
  DiveNumberAnchorRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ssi_connect.dive_number_anchors';

  final FlutterSecureStorage _storage;

  Future<Map<String, List<DiveNumberAnchor>>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    try {
      return {
        for (final entry in (jsonDecode(raw) as Map).entries)
          entry.key as String: [
            for (final anchor in entry.value as List)
              DiveNumberAnchor.fromJson(
                (anchor as Map).cast<String, dynamic>(),
              ),
          ],
      };
    } catch (_) {
      // Half-written, or from a newer version. Setting a number again
      // costs a tap; crashing on startup costs more.
      await _storage.delete(key: _key);
      return {};
    }
  }

  Future<void> save(Map<String, List<DiveNumberAnchor>> anchors) =>
      _storage.write(
        key: _key,
        value: jsonEncode({
          for (final entry in anchors.entries)
            if (entry.value.isNotEmpty)
              entry.key: [for (final anchor in entry.value) anchor.toJson()],
        }),
      );
}
