import 'package:flutter/foundation.dart';

import '../models/dive.dart';
import 'dive_site.dart';
import 'dive_site_repository.dart';

/// The dive sites this device knows an SSI number for, and the matching of
/// a dive to one of them.
class DiveSitesController extends ChangeNotifier {
  DiveSitesController({DiveSiteRepository? repository})
    : _repository = repository ?? DiveSiteRepository();

  /// How close a dive has to be to count as "at this site".
  ///
  /// 800 m is wide enough for a boat that drops you at one end of a reef
  /// and picks you up at the other, and narrow enough that two sites along
  /// the same shore stay apart. When two are within reach the nearer one
  /// wins, so the radius only decides whether there is a suggestion at all.
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

  /// The nearest known site within [matchRadiusMetres] of [dive], or null.
  ///
  /// Only ever a suggestion: the caller shows it and the user confirms.
  /// A silently applied site number would be the one kind of mistake this
  /// app has avoided everywhere else - SSI gives no feedback that a dive
  /// was filed at the wrong place.
  DiveSite? suggestionFor(Dive dive) {
    if (!dive.hasPosition) return null;

    DiveSite? best;
    var bestDistance = matchRadiusMetres;
    for (final site in _sites) {
      final distance = site.distanceMetresTo(dive.latitude!, dive.longitude!);
      if (distance <= bestDistance) {
        best = site;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Alphabetical, so the list doesn't reshuffle as sites are added.
  static List<DiveSite> _sorted(List<DiveSite> sites) {
    final sorted = [...sites];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }
}
