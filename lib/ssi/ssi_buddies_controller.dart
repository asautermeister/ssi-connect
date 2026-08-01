import 'package:flutter/foundation.dart';

import 'ssi_buddy_code.dart';
import 'ssi_buddy_repository.dart';

/// App-wide list of saved SSI buddies - divers without a Garmin account
/// here, kept so they can be picked when exporting a dive.
///
/// Separate from [AccountsController] on purpose: an account is a Garmin
/// login that fetches dives, a buddy is only an SSI member number. Mixing
/// them would mean either fake accounts without a session or buddies that
/// look like they could be logged into.
class SsiBuddiesController extends ChangeNotifier {
  SsiBuddiesController({SsiBuddyRepository? repository})
    : _repository = repository ?? SsiBuddyRepository();

  final SsiBuddyRepository _repository;

  List<SsiBuddyCode> _buddies = [];
  List<SsiBuddyCode> get buddies => List.unmodifiable(_buddies);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _buddies = _sorted(await _repository.loadAll());
    _loaded = true;
    notifyListeners();
  }

  /// Adds a buddy, or replaces the entry with the same member number.
  ///
  /// Rescanning someone is the normal way to correct a typo'd or renamed
  /// entry, so the newer scan wins rather than creating a duplicate.
  Future<void> save(SsiBuddyCode buddy) async {
    final index = _buddies.indexWhere((b) => b.memberId == buddy.memberId);
    final next = [..._buddies];
    if (index == -1) {
      next.add(buddy);
    } else {
      next[index] = buddy;
    }
    _buddies = _sorted(next);
    await _repository.saveAll(_buddies);
    notifyListeners();
  }

  Future<void> remove(String memberId) async {
    _buddies = _buddies.where((b) => b.memberId != memberId).toList();
    await _repository.saveAll(_buddies);
    notifyListeners();
  }

  /// Alphabetical, so the picker doesn't reshuffle as buddies are added.
  static List<SsiBuddyCode> _sorted(List<SsiBuddyCode> buddies) {
    final sorted = [...buddies];
    sorted.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return sorted;
  }
}
