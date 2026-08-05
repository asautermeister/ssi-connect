import '../models/dive.dart';

/// One dive as it stands in an SSI logbook - only the few fields needed to
/// recognise it again.
///
/// From `logbook_details`, of which a real entry carries some 200 fields.
/// Kept to three: the rest is either empty for a QR-imported dive or says
/// nothing about identity.
///
/// ```json
/// {
///   "odin_user_log_datetime": "2023-08-12 12:54",
///   "odin_user_log_date": "2023-08-12",
///   "odin_user_log_entry_time": "12:54",
///   "odin_user_log_depth_m": 13,
///   "odin_user_log_dive_sites_id": 332911,
///   "odin_user_log_deleted": 0
/// }
/// ```
///
/// There is no timezone anywhere in the entry: this is the entry time as
/// the diver recorded it, local to the dive. That is exactly what Garmin's
/// `startTimeLocal` gives, so the two are directly comparable - the one
/// thing that had to be checked before any of this could work.
class SsiLoggedDive {
  const SsiLoggedDive({required this.dateTime, this.depthMeters});

  /// Entry time, local to the dive.
  final DateTime dateTime;

  /// Max depth as SSI has it, when the entry carries one. SSI stores whole
  /// metres here where Garmin has decimals.
  final double? depthMeters;

  /// How far apart in time this entry and [dive] are.
  Duration distanceTo(Dive dive) => dateTime.difference(dive.dateTime).abs();

  /// Whether this entry could be [dive] at all.
  ///
  /// Deliberately strict, because the cost is asymmetric: a missed match
  /// means the tick has to be set by hand, while a wrong match hides a dive
  /// that never reached SSI - and that is the one dive that then gets
  /// skipped. So a candidate has to agree on the day, land within
  /// [maxTimeDistance], and not contradict on depth.
  bool couldBe(Dive dive) {
    final mine = dateTime;
    final theirs = dive.dateTime;
    if (mine.year != theirs.year ||
        mine.month != theirs.month ||
        mine.day != theirs.day) {
      return false;
    }
    if (distanceTo(dive) > maxTimeDistance) return false;

    final depth = depthMeters;
    final diveDepth = dive.maxDepthMeters;
    if (depth != null && diveDepth != null) {
      if ((depth - diveDepth).abs() > maxDepthDifferenceMetres) return false;
    }
    return true;
  }

  /// A dive this app exported matches to the minute - the payload carries
  /// Garmin's own start time, and SSI stores it unchanged. Twenty minutes
  /// of slack covers a dive that was edited in SSI afterwards, and stays
  /// well inside any real surface interval, so two dives of one day cannot
  /// be confused for each other.
  ///
  /// Kept deliberately tight rather than generous: a dive typed into SSI by
  /// hand hours off will simply not be found, which costs one tap. A wrong
  /// match costs a dive that never arrives.
  static const maxTimeDistance = Duration(minutes: 20);

  /// SSI rounds to whole metres, and a hand-entered dive is a guess. Wide
  /// enough not to reject a real match, narrow enough to tell a 12 m
  /// check-out dive from a 38 m wreck.
  static const maxDepthDifferenceMetres = 5.0;

  Map<String, dynamic> toJson() => {
    'dateTime': dateTime.toIso8601String(),
    'depthMeters': depthMeters,
  };

  factory SsiLoggedDive.fromJson(Map<String, dynamic> json) => SsiLoggedDive(
    dateTime: DateTime.parse(json['dateTime'] as String),
    depthMeters: (json['depthMeters'] as num?)?.toDouble(),
  );
}

/// Which of [dives] are already in the SSI logbook described by [logged].
///
/// Matched one-to-one and nearest first: two dives of one day must not both
/// claim the same logbook entry, and the entry belongs to whichever dive it
/// is closest in time to.
///
/// Both sides must belong to the *same person*. A family that dives
/// together produces dives at the same minute, the same site and nearly the
/// same depth, so matching across accounts would tick everybody's dives
/// from one logbook. The caller keeps them apart.
Set<String> matchLoggedDives(List<Dive> dives, List<SsiLoggedDive> logged) {
  final pairs = <({String diveId, int entry, Duration distance})>[];
  for (final dive in dives) {
    for (var i = 0; i < logged.length; i++) {
      if (logged[i].couldBe(dive)) {
        pairs.add((
          diveId: dive.id,
          entry: i,
          distance: logged[i].distanceTo(dive),
        ));
      }
    }
  }
  pairs.sort((a, b) => a.distance.compareTo(b.distance));

  final matched = <String>{};
  final usedEntries = <int>{};
  for (final pair in pairs) {
    if (matched.contains(pair.diveId)) continue;
    if (usedEntries.contains(pair.entry)) continue;
    matched.add(pair.diveId);
    usedEntries.add(pair.entry);
  }
  return matched;
}
