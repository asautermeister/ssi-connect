import 'ssi_buddy_code.dart';

/// Everyone this device knows an SSI member number for, as one list to pick
/// buddies from.
///
/// Two sources feed it: the SSI identities stored on the Garmin accounts
/// (family members who dive together are each other's buddies), and the
/// standalone buddies scanned into [SsiBuddiesController].
///
/// [diver] is whoever the dive is being logged for - they are dropped from
/// the result, since nobody is their own buddy.
///
/// Where the same member number appears in both sources, the account
/// identity wins: it is the entry the user maintains on the account screen,
/// so a name corrected there shouldn't be shadowed by an older scan.
List<SsiBuddyCode> ssiBuddyCandidates({
  required Iterable<SsiBuddyCode> accountIdentities,
  required Iterable<SsiBuddyCode> savedBuddies,
  SsiBuddyCode? diver,
}) {
  final byMemberId = <String, SsiBuddyCode>{};
  for (final buddy in savedBuddies) {
    byMemberId[buddy.memberId] = buddy;
  }
  for (final identity in accountIdentities) {
    byMemberId[identity.memberId] = identity;
  }
  if (diver != null) {
    byMemberId.remove(diver.memberId);
  }

  final candidates = byMemberId.values.toList();
  candidates.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return candidates;
}
