import 'package:flutter/foundation.dart';

/// Whether the diagnostic tools are on screen.
///
/// The API log and the SSI-code inspector exist for working out why
/// something broke; they are not part of using the app. So they sit behind
/// three taps on the version number in the info screen - the same gesture
/// Android itself uses, findable when someone tells you how, invisible
/// otherwise.
///
/// Session-only on purpose: nothing to switch back off, and a fresh start
/// puts the app back in its ordinary state.
class DeveloperMode extends ChangeNotifier {
  /// Taps needed on the version. Three is enough to be deliberate and few
  /// enough to describe over the phone.
  static const tapsToUnlock = 3;

  int _taps = 0;
  bool _enabled = false;

  bool get enabled => _enabled;

  /// How many more taps are needed, once counting has visibly started.
  /// Zero while nothing has been tapped yet, so no hint is shown to
  /// someone who just poked the version once.
  int get tapsRemaining => _taps == 0 || _enabled ? 0 : tapsToUnlock - _taps;

  /// Returns true if this tap was the one that unlocked it.
  bool registerVersionTap() {
    if (_enabled) return false;
    _taps++;
    if (_taps >= tapsToUnlock) {
      _enabled = true;
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }
}
