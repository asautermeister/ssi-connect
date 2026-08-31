import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_sync_controller.dart';
import 'dive_loader.dart';
import 'exported_dives_controller.dart';
import 'recent_dives_controller.dart';

/// How fresh data has to be before an attempt to fetch it is skipped.
///
/// Two numbers for the whole app, and deliberately the same two for Garmin
/// and for SSI. The app is used in the evening after a dive day, not
/// during one, so there is no case where the dives need to be newer than
/// the logbook they are checked against - and one rule is one thing to
/// reason about.
abstract final class RefreshPolicy {
  /// The floor. Holds even for a pull-to-refresh: a list that can be pulled
  /// twice a second is a list that can hammer two APIs nobody gave us
  /// permission to hammer. The number is SSI's own guidance for their app.
  static const minimumInterval = Duration(seconds: 60);

  /// When a screen opens, anything older than this is fetched again.
  /// Longer than the floor because arriving on a screen is not the same as
  /// asking for fresh data - an evening's worth of navigation should cost
  /// one round of calls, not one per screen.
  static const automaticWindow = Duration(minutes: 15);
}

/// Why data is being fetched, which is the same question as how fresh it
/// has to be to be left alone.
enum RefreshReason {
  /// A screen opened and wants something reasonably current.
  automatic(RefreshPolicy.automaticWindow),

  /// Somebody pulled the list down. Still bounded - see
  /// [RefreshPolicy.minimumInterval].
  userAsked(RefreshPolicy.minimumInterval);

  const RefreshReason(this.notWithin);

  /// How recently the data may have been fetched for this to do nothing.
  final Duration notWithin;
}

/// Fetches Garmin dives and the SSI logbooks for [scope], together.
///
/// One call for both, because they answer one question between them: what
/// has been dived, and what of it has already reached SSI. Splitting them
/// across two gestures is what let the ticks and the dive sites age
/// silently while the dives beside them were current.
///
/// [scope] is whichever accounts the screen is showing - all of them on the
/// start screen, exactly one in that account's dive list. Each account is
/// fetched independently and each source fails on its own: an SSI logbook
/// that cannot be read must not disturb a dive list that loaded fine.
Future<void> refreshAccounts({
  required List<GarminAccount> scope,
  required RefreshReason reason,
  required RecentDivesController dives,
  required DiveFetcher fetch,
  required AccountsController accounts,
  required DiveSitesController sites,
  required SsiBuddiesController buddies,
  required ExportedDivesController exported,
  required SsiSyncController sync,
}) async {
  if (scope.isEmpty) return;

  await Future.wait([
    dives.load(accounts: scope, fetch: fetch, notWithin: reason.notWithin),
    sync.syncAccounts(
      scope: scope,
      notWithin: reason.notWithin,
      accounts: accounts,
      sites: sites,
      buddies: buddies,
      exported: exported,
    ),
  ]);
}
