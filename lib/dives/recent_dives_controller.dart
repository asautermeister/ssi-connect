import 'package:flutter/foundation.dart';

import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../models/dive.dart';
import 'dive_cache_repository.dart';
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
    this.fetchedAt,
    this.isFromCache = false,
  });

  final List<Dive> dives;
  final bool isLoading;
  final Object? error;

  /// When these dives were fetched from Garmin - for cached ones, when the
  /// fetch that produced the cache happened.
  final DateTime? fetchedAt;

  /// True while what's on screen came off the device rather than the wire.
  /// The UI says so instead of passing stale data off as current.
  final bool isFromCache;

  bool get hasError => error != null;

  /// The request never reached Garmin. Distinct from any other failure,
  /// because it is the only one where "check your connection" is the right
  /// thing to tell someone.
  bool get isOffline =>
      error is GarminAuthException &&
      (error! as GarminAuthException).type == GarminAuthErrorType.offline;

  Dive? get latest => dives.isEmpty ? null : dives.first;
}

/// One dive together with the account it belongs to, so the merged list can
/// say whose dive it is.
class RecentDive {
  const RecentDive({required this.account, required this.dive});

  final GarminAccount account;
  final Dive dive;
}

/// The dives shown across the app: the most recent ones per account, merged
/// for the start screen so it opens on the thing the app exists for.
///
/// Each account is served from its cache first and refreshed from Garmin
/// afterwards. If the refresh fails, the cached dives stay on screen with a
/// note saying when they were fetched - a dive from this morning is still
/// worth a QR code at a dive site with no reception.
class RecentDivesController extends ChangeNotifier {
  RecentDivesController({DiveCacheRepository? cache})
    : _cache = cache ?? DiveCacheRepository();

  final DiveCacheRepository _cache;
  final _byAccountId = <String, AccountDives>{};

  /// How many pages have been fetched per account, so the next "load more"
  /// knows where to continue.
  final _pagesLoaded = <String, int>{};

  /// Accounts whose last page came back short - there is nothing older to
  /// ask for, and asking again would just be an empty round trip.
  final _exhausted = <String>{};

  bool _isLoadingMore = false;
  Object? _loadMoreError;

  /// When each account was last *asked*, successfully or not.
  ///
  /// Per account rather than one signature over all of them, and that is
  /// what makes the rest work: a scope smaller than "everyone" becomes
  /// possible, "how old is this" becomes answerable, and a refresh of one
  /// account stops invalidating the others.
  ///
  /// The attempt counts, not the success. A screen asks on every build, so
  /// an account that only ever fails would otherwise be asked again on
  /// every frame - which is a loop, not a retry.
  final _lastAttemptAt = <String, DateTime>{};

  /// True once a load has been started for anybody.
  bool _started = false;

  bool get isLoadingMore => _isLoadingMore;

  /// Why the last "load more" failed, or null. Kept separate from the
  /// per-account errors: those mean "nothing on screen", this one means
  /// "what is on screen is fine, there just isn't more of it yet".
  Object? get loadMoreError => _loadMoreError;

  /// True while at least one account might still have older dives. False
  /// once every account has answered with a short page.
  bool get hasMore =>
      _byAccountId.keys.any((id) => !_exhausted.contains(id)) &&
      _byAccountId.isNotEmpty;

  bool get isLoading => _byAccountId.values.any((load) => load.isLoading);

  /// True once a load has been started, whatever came of it.
  bool get hasLoaded => _started && !isLoading;

  /// When [accountId] was last asked, or null if never.
  DateTime? lastAttemptAt(String accountId) => _lastAttemptAt[accountId];

  /// Accounts whose fetch failed. The screen names them rather than
  /// pretending they simply have no dives.
  int get failedCount => _byAccountId.values.where((l) => l.hasError).length;

  /// Every account that could be reached failed at the network level - so
  /// this really is "no internet" and not one broken login.
  bool get isOffline =>
      _byAccountId.isNotEmpty &&
      _byAccountId.values.every((load) => load.isOffline);

  /// True when anything on screen is being served from the cache.
  bool get isShowingCache => _byAccountId.values.any(
    (load) => load.isFromCache && load.dives.isNotEmpty,
  );

  /// Oldest fetch time among what is currently shown - the honest answer to
  /// "how current is this?" when several accounts were fetched at once.
  DateTime? get oldestFetchedAt {
    DateTime? oldest;
    for (final load in _byAccountId.values) {
      final fetchedAt = load.fetchedAt;
      if (fetchedAt == null || load.dives.isEmpty) continue;
      if (oldest == null || fetchedAt.isBefore(oldest)) oldest = fetchedAt;
    }
    return oldest;
  }

  AccountDives forAccount(String accountId) =>
      _byAccountId[accountId] ?? const AccountDives();

  /// Every loaded dive across all accounts, most recent first.
  List<RecentDive> merged(List<GarminAccount> accounts) {
    final merged = <RecentDive>[];
    for (final account in accounts) {
      for (final dive in forAccount(account.id).dives) {
        merged.add(RecentDive(account: account, dive: dive));
      }
    }
    merged.sort((a, b) => b.dive.dateTime.compareTo(a.dive.dateTime));
    return merged;
  }

  /// The newest [limit] dives across all accounts, for the start screen.
  List<RecentDive> recent(List<GarminAccount> accounts, {int limit = 5}) =>
      merged(accounts).take(limit).toList();

  /// Forgets accounts that are no longer there.
  ///
  /// Split off from [load] because it is a different question: a refresh
  /// scoped to one account used to drop every other account's dives from
  /// memory on its way through, which only went unnoticed because the
  /// screen behind it re-fetched everything anyway.
  void retain(List<GarminAccount> accounts) {
    final keep = {for (final account in accounts) account.id};
    final dropped = _byAccountId.keys.where((id) => !keep.contains(id));
    if (dropped.isEmpty) return;
    for (final id in dropped.toList()) {
      _byAccountId.remove(id);
      _lastAttemptAt.remove(id);
      _pagesLoaded.remove(id);
      _exhausted.remove(id);
    }
    notifyListeners();
  }

  /// Loads the dives of [accounts] in parallel, skipping any that were
  /// fetched more recently than [notWithin].
  ///
  /// The caller says how fresh is fresh enough: a screen opening asks for
  /// [RefreshPolicy.automaticWindow], a pull-to-refresh for
  /// [RefreshPolicy.minimumInterval]. Nothing here refetches unconditionally
  /// - the floor holds even for a deliberate gesture, because a list that
  /// can be pulled twice a second is a list that can hammer an API nobody
  /// gave us permission to hammer.
  Future<void> load({
    required List<GarminAccount> accounts,
    required DiveFetcher fetch,
    required Duration notWithin,
  }) async {
    final now = DateTime.now();
    final due = [
      for (final account in accounts)
        if (_isDue(account.id, now, notWithin)) account,
    ];
    if (due.isEmpty) return;
    _started = true;

    // Re-fetching the first page throws away anything paged in beyond it,
    // so the paging state starts over - but only for the accounts actually
    // being refetched.
    for (final account in due) {
      _pagesLoaded.remove(account.id);
      _exhausted.remove(account.id);
    }
    _loadMoreError = null;

    for (final account in due) {
      final known = _byAccountId[account.id];
      // Keep whatever is already on screen while refreshing - blanking it
      // would make a pull-to-refresh flash empty for no reason.
      _byAccountId[account.id] = AccountDives(
        dives: known?.dives ?? const [],
        fetchedAt: known?.fetchedAt,
        isFromCache: known?.isFromCache ?? false,
        isLoading: true,
      );
    }
    notifyListeners();

    await Future.wait([for (final account in due) _loadOne(account, fetch)]);
  }

  bool _isDue(String accountId, DateTime now, Duration notWithin) {
    final last = _lastAttemptAt[accountId];
    return last == null || now.difference(last) >= notWithin;
  }

  Future<void> _loadOne(GarminAccount account, DiveFetcher fetch) async {
    await _seedFromCache(account.id);
    _lastAttemptAt[account.id] = DateTime.now();

    try {
      final dives = await fetch(account, start: 0);
      final sorted = [...dives]
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _byAccountId[account.id] = AccountDives(
        dives: sorted,
        fetchedAt: DateTime.now(),
      );
      _pagesLoaded[account.id] = 1;
      if (dives.length < divePageSize) _exhausted.add(account.id);
      await _cache.save(account.id, sorted);
    } catch (e) {
      // Failing does not throw away what we have. Cached dives with a
      // "fetched at" note beat an empty screen with an error on it.
      final known = _byAccountId[account.id];
      _byAccountId[account.id] = AccountDives(
        dives: known?.dives ?? const [],
        fetchedAt: known?.fetchedAt,
        isFromCache: known?.dives.isNotEmpty ?? false,
        error: e,
      );
    }
    notifyListeners();
  }

  /// Fetches one more page per account and appends it to what is already
  /// loaded. Accounts that have already run out are skipped.
  ///
  /// Does not touch the cache: it keeps the newest
  /// [DiveCacheRepository.maxDivesPerAccount] dives, which is exactly what
  /// the first page already produced, so writing paged-in dives there would
  /// only rewrite the same entries. Older dives stay for this session.
  Future<void> loadMore({
    required List<GarminAccount> accounts,
    required DiveFetcher fetch,
  }) async {
    if (_isLoadingMore) return;
    final pending = [
      for (final account in accounts)
        if (!_exhausted.contains(account.id) &&
            _byAccountId.containsKey(account.id))
          account,
    ];
    if (pending.isEmpty) return;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    await Future.wait([
      for (final account in pending) _loadNextPage(account, fetch),
    ]);

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _loadNextPage(GarminAccount account, DiveFetcher fetch) async {
    final pagesLoaded = _pagesLoaded[account.id] ?? 1;
    try {
      final fetched = await fetch(account, start: pagesLoaded * divePageSize);
      _pagesLoaded[account.id] = pagesLoaded + 1;
      // Short page means the end. Checked before merging, since a page full
      // of dives we already had is still a full page.
      if (fetched.length < divePageSize) _exhausted.add(account.id);
      if (fetched.isEmpty) return;

      final known = forAccount(account.id);
      // By id, so a dive that appears in two pages - the list shifts if
      // something is logged while paging - lands once.
      final byId = {
        for (final dive in known.dives) dive.id: dive,
        for (final dive in fetched) dive.id: dive,
      };
      final all = byId.values.toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      _byAccountId[account.id] = AccountDives(
        // Re-numbered across the whole set: a dive day split across a page
        // boundary would otherwise be numbered from 1 twice.
        dives: assignDiveNumbersOfDay(all),
        fetchedAt: known.fetchedAt,
        isFromCache: known.isFromCache,
      );
    } catch (e) {
      // What is on screen stays; only the attempt to extend it failed.
      _loadMoreError = e;
    }
  }

  /// Publishes the cached dives right away, so something is on screen while
  /// the network call is still in flight. Skipped once real dives are in
  /// memory - those are never older than the cache.
  Future<void> _seedFromCache(String accountId) async {
    final known = _byAccountId[accountId];
    if (known != null && known.dives.isNotEmpty) return;

    final cached = await _cache.load(accountId);
    if (cached == null || cached.dives.isEmpty) return;

    _byAccountId[accountId] = AccountDives(
      dives: cached.dives,
      fetchedAt: cached.fetchedAt,
      isFromCache: true,
      isLoading: true,
    );
    notifyListeners();
  }

  /// Drops an account's dives from memory and from the device. Called when
  /// the account is removed, and from the "clear cache" action.
  Future<void> forget(String accountId) async {
    _byAccountId.remove(accountId);
    _pagesLoaded.remove(accountId);
    _exhausted.remove(accountId);
    // Nothing is known about this account any more, so the next load has
    // to run - and only for this one.
    _lastAttemptAt.remove(accountId);
    await _cache.clear(accountId);
    notifyListeners();
  }
}
