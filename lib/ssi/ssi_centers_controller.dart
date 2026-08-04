import 'package:flutter/foundation.dart';

import 'ssi_center_code.dart';
import 'ssi_center_repository.dart';

/// App-wide list of saved dive centres, so a base scanned on one holiday can
/// be handed on later.
///
/// Deliberately a sibling of [SsiBuddiesController] rather than a mode of
/// it: a centre has a name and no member, a buddy has a member and no
/// centre number. One list holding both would have to keep asking which
/// kind of row it was looking at.
class SsiCentersController extends ChangeNotifier {
  SsiCentersController({SsiCenterRepository? repository})
    : _repository = repository ?? SsiCenterRepository();

  final SsiCenterRepository _repository;

  List<SsiCenterCode> _centers = [];
  List<SsiCenterCode> get centers => List.unmodifiable(_centers);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _centers = _sorted(await _repository.loadAll());
    _loaded = true;
    notifyListeners();
  }

  /// Adds a centre, or replaces the entry with the same centre number, so
  /// rescanning corrects an entry instead of duplicating it.
  Future<void> save(SsiCenterCode center) async {
    final index = _centers.indexWhere((c) => c.centerId == center.centerId);
    final next = [..._centers];
    if (index == -1) {
      next.add(center);
    } else {
      next[index] = center;
    }
    _centers = _sorted(next);
    await _repository.saveAll(_centers);
    notifyListeners();
  }

  Future<void> remove(String centerId) async {
    _centers = _centers.where((c) => c.centerId != centerId).toList();
    await _repository.saveAll(_centers);
    notifyListeners();
  }

  /// Alphabetical, so the list doesn't reshuffle as centres are added.
  static List<SsiCenterCode> _sorted(List<SsiCenterCode> centers) {
    final sorted = [...centers];
    sorted.sort(
      (a, b) => a.sortKey.toLowerCase().compareTo(b.sortKey.toLowerCase()),
    );
    return sorted;
  }
}
