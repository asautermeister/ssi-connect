import 'package:flutter/foundation.dart';

import '../models/dive.dart';
import 'dive_site.dart';
import 'dive_site_repository.dart';

/// A known site together with how far it is from the dive being looked at.
typedef DiveSiteMatch = ({DiveSite site, double distanceMetres});

/// The dive sites this device knows an SSI number for, and the matching of
/// a dive to one of them.
class DiveSitesController extends ChangeNotifier {
  DiveSitesController({DiveSiteRepository? repository})
    : _repository = repository ?? DiveSiteRepository();

  /// How close a dive has to be to count as "at this site".
  ///
  /// 800 m is wide enough for a boat that drops you at one end of a reef
  /// and picks you up at the other. It is not narrow enough to leave only
  /// one candidate: in a place like Gozo several sites sit along the same
  /// stretch of coast, and importing a whole logbook makes that the normal
  /// case rather than the exception. So the radius decides who gets
  /// *offered*, and the user decides which one it was.
  static const matchRadiusMetres = 800.0;

  final DiveSiteRepository _repository;

  List<DiveSite> _sites = [];
  List<DiveSite> get sites => List.unmodifiable(_sites);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _sites = _sorted(await _repository.loadAll());
    _loaded = true;
    notifyListeners();
  }

  /// Adds a site, or replaces the entry with the same number - re-matching
  /// a place corrects it rather than listing it twice.
  Future<void> save(DiveSite site) async {
    final index = _sites.indexWhere((s) => s.siteId == site.siteId);
    final next = [..._sites];
    if (index == -1) {
      next.add(site);
    } else {
      next[index] = site;
    }
    _sites = _sorted(next);
    await _repository.saveAll(_sites);
    notifyListeners();
  }

  /// Adds every site whose number this device does not know yet, in one
  /// write. Returns how many were actually new.
  ///
  /// Existing entries are left untouched rather than refreshed: the user
  /// may have renamed one, and a position that came from one of their own
  /// dives points at the entry they actually use, which is a better match
  /// target than a site's registered centre.
  ///
  /// With one exception: a known site that has no region yet takes the one
  /// from the import. The region is not something the user can set or
  /// correct, so there is no edit to protect - and without this, every
  /// site imported before regions were kept would stay ungrouped forever.
  Future<int> addAllNew(Iterable<DiveSite> sites) async {
    final known = {for (final site in _sites) site.siteId};
    final regions = <String, String>{};
    final added = <DiveSite>[];
    for (final site in sites) {
      // `known` also guards against duplicates inside the incoming list.
      if (known.add(site.siteId)) {
        added.add(site);
      } else if (site.region != null) {
        regions[site.siteId] = site.region!;
      }
    }

    final backfilled = [
      for (final site in _sites)
        if (regions[site.siteId] case final region? when site.region == null)
          site.withRegion(region)
        else
          site,
    ];
    if (added.isEmpty && !_anyChanged(_sites, backfilled)) return 0;

    _sites = _sorted([...backfilled, ...added]);
    await _repository.saveAll(_sites);
    notifyListeners();
    return added.length;
  }

  /// Whether the backfill actually changed anything - identity is enough,
  /// because an untouched entry is the very same object.
  static bool _anyChanged(List<DiveSite> before, List<DiveSite> after) {
    for (var i = 0; i < before.length; i++) {
      if (!identical(before[i], after[i])) return true;
    }
    return false;
  }

  Future<void> remove(String siteId) async {
    _sites = _sites.where((s) => s.siteId != siteId).toList();
    await _repository.saveAll(_sites);
    notifyListeners();
  }

  DiveSite? byId(String siteId) {
    for (final site in _sites) {
      if (site.siteId == siteId) return site;
    }
    return null;
  }

  /// Every known site within [matchRadiusMetres] of [dive], nearest first.
  ///
  /// Only ever suggestions: the caller shows them and the user confirms.
  /// A silently applied site number would be the one kind of mistake this
  /// app has avoided everywhere else - SSI gives no feedback that a dive
  /// was filed at the wrong place. That matters more since sites arrive by
  /// the hundred from an SSI import: "the closest one" stopped being a
  /// safe guess the moment two of them could be 300 m apart.
  List<DiveSiteMatch> suggestionsFor(Dive dive) {
    if (!dive.hasPosition) return const [];

    final matches = <DiveSiteMatch>[];
    for (final site in _sites) {
      final distance = site.distanceMetresTo(dive.latitude!, dive.longitude!);
      if (distance <= matchRadiusMetres) {
        matches.add((site: site, distanceMetres: distance));
      }
    }
    matches.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
    return matches;
  }

  /// The nearest known site within [matchRadiusMetres] of [dive], or null.
  DiveSite? suggestionFor(Dive dive) {
    final matches = suggestionsFor(dive);
    return matches.isEmpty ? null : matches.first.site;
  }

  /// All known sites ranked by distance from [dive] - no radius limit.
  ///
  /// What the picker shows once the list is long enough that alphabetical
  /// order stops being useful. Sites without a reachable dive position keep
  /// their alphabetical order instead.
  List<DiveSiteMatch> rankedByDistanceFrom(Dive dive) {
    if (!dive.hasPosition) {
      return [for (final site in _sites) (site: site, distanceMetres: 0)];
    }
    final ranked = [
      for (final site in _sites)
        (
          site: site,
          distanceMetres: site.distanceMetresTo(
            dive.latitude!,
            dive.longitude!,
          ),
        ),
    ];
    ranked.sort((a, b) => a.distanceMetres.compareTo(b.distanceMetres));
    return ranked;
  }

  /// Alphabetical, so the list doesn't reshuffle as sites are added.
  static List<DiveSite> _sorted(List<DiveSite> sites) {
    final sorted = [...sites];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }
}
