import 'package:flutter/foundation.dart';

import '../accounts/models/garmin_account.dart';
import '../models/dive.dart';
import 'dive_loader.dart';

/// How one account's fetch went. Kept per account rather than as one global
/// state so a single broken login doesn't blank the whole start screen -
/// with several family members on one tablet that is the normal case, not
/// an edge case.
class AccountDives {
  const AccountDives({
    this.dives = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Dive> dives;
  final bool isLoading;
  final Object? error;

  bool get hasError => error != null;
  Dive? get latest => dives.isEmpty ? null : dives.first;
}

/// One dive together with the account it belongs to, so the merged list can
/// say whose dive it is.
class RecentDive {
  const RecentDive({required this.account, required this.dive});

  final GarminAccount account;
  final Dive dive;
}

/// The dives shown on the start screen: the most recent ones across all
/// accounts, so the app opens on the thing it exists for instead of on a
/// list of names.
///
/// Held in memory only, like everywhere else - dives are never written to
/// storage. Closing the app drops them; the next start fetches again.
class RecentDivesController extends ChangeNotifier {
  final _byAccountId = <String, AccountDives>{};

  /// Which set of accounts the current data belongs to, so the screen can
  /// ask on every build without re-fetching.
  String? _loadedFor;

  bool get isLoading => _byAccountId.values.any((load) => load.isLoading);

  /// True once a load has been started, whatever came of it.
  bool get hasLoaded => _loadedFor != null && !isLoading;

  /// Accounts whose fetch failed. The screen names them rather than
  /// pretending they simply have no dives.
  int get failedCount => _byAccountId.values.where((l) => l.hasError).length;

  AccountDives forAccount(String accountId) =>
      _byAccountId[accountId] ?? const AccountDives();

  /// The newest dives across all accounts, most recent first.
  List<RecentDive> recent(List<GarminAccount> accounts, {int limit = 5}) {
    final merged = <RecentDive>[];
    for (final account in accounts) {
      for (final dive in forAccount(account.id).dives) {
        merged.add(RecentDive(account: account, dive: dive));
      }
    }
    merged.sort((a, b) => b.dive.dateTime.compareTo(a.dive.dateTime));
    return merged.take(limit).toList();
  }

  /// Loads every account's dives in parallel. Does nothing if the same set
  /// of accounts has already been loaded, unless [force] is set - the start
  /// screen calls this from build, so it has to be cheap to ask.
  Future<void> load({
    required List<GarminAccount> accounts,
    required DiveFetcher fetch,
    bool force = false,
  }) async {
    final signature = accounts.map((a) => a.id).join(',');
    if (!force && signature == _loadedFor) return;
    _loadedFor = signature;

    _byAccountId
      ..removeWhere((id, _) => !accounts.any((a) => a.id == id))
      ..addEntries(
        accounts.map(
          (a) => MapEntry(a.id, const AccountDives(isLoading: true)),
        ),
      );
    notifyListeners();

    await Future.wait([
      for (final account in accounts) _loadOne(account, fetch),
    ]);
  }

  Future<void> _loadOne(GarminAccount account, DiveFetcher fetch) async {
    try {
      final dives = await fetch(account);
      final sorted = [...dives]
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _byAccountId[account.id] = AccountDives(dives: sorted);
    } catch (e) {
      _byAccountId[account.id] = AccountDives(error: e);
    }
    notifyListeners();
  }
}
