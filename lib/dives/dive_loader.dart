import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_activity_client.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../garmin/models/garmin_session.dart';
import '../models/dive.dart';

/// Fetches the dives of one account. The single seam both the start screen
/// and the dive list load through, so they can't drift apart in how they
/// handle an expired session.
typedef DiveFetcher = Future<List<Dive>> Function(GarminAccount account);

/// Loads dives from Garmin, refreshing the stored session once if the
/// access token has expired.
///
/// The refresh is a callback rather than an [AccountsController] reference:
/// this way the loader stays testable without a keystore, and the one place
/// that persists a refreshed token remains the accounts controller.
class GarminDiveLoader {
  GarminDiveLoader({required this.refreshSession, GarminActivityClient? client})
    : _client = client ?? GarminActivityClient();

  final GarminActivityClient _client;

  /// Obtains a fresh session for the account and persists it.
  final Future<GarminSession> Function(GarminAccount account) refreshSession;

  Future<List<Dive>> load(
    GarminAccount account, {
    bool forceRefreshSession = false,
  }) async {
    var session = account.session;
    if (forceRefreshSession) {
      session = await refreshSession(account);
    }

    try {
      final activities = await _client.getDiveActivities(session);
      final dives = activities
          .map(Dive.fromGarminActivity)
          .whereType<Dive>()
          .toList();
      return assignDiveNumbersOfDay(dives);
    } on GarminAuthException catch (e) {
      // A rejected token is the one failure worth a second attempt, and
      // only once - retrying a wrong password would just lock the account.
      if (e.type == GarminAuthErrorType.invalidCredentials &&
          !forceRefreshSession) {
        return load(account, forceRefreshSession: true);
      }
      rethrow;
    }
  }
}
