import 'package:flutter/foundation.dart';

import '../models/dive.dart';
import '../ssi/ssi_logged_dive.dart';
import 'exported_dives_repository.dart';
import 'recent_dives_controller.dart';

/// Why a dive counts as carried over into SSI - or doesn't.
enum DiveTransferState {
  /// Not in SSI as far as this device knows.
  no,

  /// Ticked by hand on the QR screen.
  byHand,

  /// Found in the SSI logbook of the account the dive belongs to.
  fromLogbook,
}

/// Which dives have already been carried over into SSI.
///
/// Two sources, answering different questions. The tick on the QR screen is
/// what the person in front of the tablet just did; the SSI logbook is what
/// actually arrived. The tick wins where both have an opinion - it is
/// newer, and it is the only one that can say "no, that one did *not* go
/// across" about a dive the logbook appears to contain.
///
/// Nothing is inferred from the export itself: showing a QR code is not
/// proof that anyone scanned it, and a tick that appears too early marks
/// exactly the dive that then gets skipped.
class ExportedDivesController extends ChangeNotifier {
  ExportedDivesController({ExportedDivesRepository? repository})
    : _repository = repository ?? ExportedDivesRepository();

  final ExportedDivesRepository _repository;

  Map<String, bool> _marks = {};
  Map<String, List<SsiLoggedDive>> _logbooks = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _marks = await _repository.loadMarks();
    _logbooks = await _repository.loadLogbooks();
    _loaded = true;
    notifyListeners();
  }

  /// What one account's SSI logbook holds. Empty for an account without an
  /// SSI login, and for a FIT import, which belongs to nobody.
  List<SsiLoggedDive> logbookOf(String? accountId) =>
      accountId == null ? const [] : (_logbooks[accountId] ?? const []);

  /// Which of [dives] are in [accountId]'s SSI logbook.
  ///
  /// Matched as a set rather than one dive at a time so a logbook entry can
  /// only account for one dive. Two dives of the same day would otherwise
  /// both be able to claim the single entry that is actually there, and one
  /// of them would be ticked wrongly.
  Set<String> matchedIn(String? accountId, List<Dive> dives) {
    final logged = logbookOf(accountId);
    return logged.isEmpty ? const {} : matchLoggedDives(dives, logged);
  }

  /// The same across a merged list, keeping each account's dives against
  /// that account's logbook.
  ///
  /// Which matters more than it looks: a family diving together produces
  /// dives at the same minute, the same site and nearly the same depth, so
  /// matching across accounts would tick everybody's dives from whichever
  /// logbook happened to be connected.
  Set<String> matchedAcross(List<RecentDive> entries) {
    final byAccount = <String, List<Dive>>{};
    for (final entry in entries) {
      (byAccount[entry.account.id] ??= []).add(entry.dive);
    }
    return {
      for (final account in byAccount.entries)
        ...matchedIn(account.key, account.value),
    };
  }

  /// Whether [dive] has reached SSI, and how that is known.
  ///
  /// [inLogbook] comes from [matchedIn] or [matchedAcross] - the caller
  /// knows which dives belong to which account, this does not.
  DiveTransferState stateOf(Dive dive, {bool inLogbook = false}) {
    final mark = _marks[dive.id];
    if (mark != null) {
      return mark ? DiveTransferState.byHand : DiveTransferState.no;
    }
    return inLogbook ? DiveTransferState.fromLogbook : DiveTransferState.no;
  }

  bool isTransferred(Dive dive, {bool inLogbook = false}) =>
      stateOf(dive, inLogbook: inLogbook) != DiveTransferState.no;

  /// Sets or clears the tick by hand.
  ///
  /// A cleared tick is stored rather than forgotten: it has to survive the
  /// next sync, or the logbook would simply put it back.
  Future<void> setTransferred(String diveId, bool transferred) async {
    if (_marks[diveId] == transferred) return;
    _marks = {..._marks, diveId: transferred};
    await _repository.saveMarks(_marks);
    notifyListeners();
  }

  /// Records what one account's SSI logbook contains.
  Future<void> setLogbook(String accountId, List<SsiLoggedDive> logged) async {
    _logbooks = {..._logbooks, accountId: logged};
    await _repository.saveLogbooks(_logbooks);
    notifyListeners();
  }

  /// Drops an account's logbook - it went with the account or the login.
  Future<void> forgetLogbook(String accountId) async {
    if (!_logbooks.containsKey(accountId)) return;
    _logbooks = {..._logbooks}..remove(accountId);
    await _repository.saveLogbooks(_logbooks);
    notifyListeners();
  }
}
