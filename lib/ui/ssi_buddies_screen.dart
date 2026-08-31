import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../ssi/dive_site.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_center_code.dart';
import '../ssi/ssi_centers_controller.dart';
import '../ssi/ssi_sync_controller.dart';
import 'qr_display_screen.dart';
import 'ssi_identity_screen.dart';
import 'ssi_scan_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/stat_tile.dart';

/// Everything this device has an SSI code for: divers and dive centres.
///
/// Three groups, kept apart rather than merged: the accounts that have an
/// SSI identity stored, the standalone buddies scanned in here, and the
/// dive centres. Accounts look like buddies but behave differently - an
/// account's number is maintained on the account screen, so it can be shown
/// here but not edited or deleted here. Centres aren't people at all: they
/// carry a name and a base number instead of a member and a mail address.
/// One list with different menus depending on the row would be worse.
///
/// Any of them can be shown as a QR code for someone else's app to scan.
/// None of them travel with an exported dive: SSI's import format has no
/// buddy field, so the picker that used to sit under the dive QR code was
/// removed rather than left looking functional.
class SsiBuddiesScreen extends StatefulWidget {
  const SsiBuddiesScreen({super.key});

  /// Above this many entries, scrolling stops being a way to find anything
  /// and the search field earns its space. The same threshold the dive-site
  /// picker uses, so the app has one rule rather than two.
  static const searchThreshold = 8;

  /// Dive sites arrive by the hundred from a well-travelled logbook. Enough
  /// to see that they are there and to recognise the last few; the rest on
  /// request.
  static const sitesShownAtFirst = 10;

  @override
  State<SsiBuddiesScreen> createState() => _SsiBuddiesScreenState();
}

class _SsiBuddiesScreenState extends State<SsiBuddiesScreen> {
  final _query = TextEditingController();
  bool _allSites = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Whether any of [fields] contains what was typed.
  ///
  /// Only ever called with what the card actually shows. Matching a field
  /// that is not on screen produces a hit that looks like a mistake.
  bool _matches(List<String?> fields) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return fields.any((f) => f != null && f.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final buddies = context.watch<SsiBuddiesController>();
    final centers = context.watch<SsiCentersController>();
    final accounts = context.watch<AccountsController>();
    final sites = context.watch<DiveSitesController>();
    final sync = context.watch<SsiSyncController>();
    final s = AppStrings.of(context);

    final withIdentity = [
      for (final account in accounts.accounts)
        if (account.ssiIdentity != null) account,
    ];
    final accountMemberIds = {
      for (final account in withIdentity) account.ssiMemberId,
    };
    // A member who also has an account here is listed once, under the
    // account: that is the entry the user maintains, and a rescan
    // shouldn't produce a second row for the same person.
    final standalone = [
      for (final buddy in buddies.buddies)
        if (!accountMemberIds.contains(buddy.memberId)) buddy,
    ];

    final loaded = buddies.loaded && centers.loaded && accounts.loaded;
    final empty =
        withIdentity.isEmpty &&
        standalone.isEmpty &&
        centers.centers.isEmpty &&
        sites.sites.isEmpty;

    // Everything the search can narrow, so the field appears on the same
    // rule everywhere rather than per section.
    final total =
        withIdentity.length +
        standalone.length +
        centers.centers.length +
        sites.sites.length;

    final searching = _query.text.trim().isNotEmpty;
    final matchedAccounts = [
      for (final account in withIdentity)
        if (_matches([account.displayName, account.ssiMemberId])) account,
    ];
    final matchedBuddies = [
      for (final buddy in standalone)
        if (_matches([buddy.fullName, buddy.memberId])) buddy,
    ];
    final matchedCentres = [
      for (final centre in centers.centers)
        if (_matches([centre.name, centre.centerId])) centre,
    ];
    // By name and region, the two readable things on screen. Not by the
    // number: SSI's site ids are not something anybody reads or remembers,
    // and not by the coordinates either.
    final matchedSites = [
      for (final site in sites.sites)
        if (_matches([site.name, site.region])) site,
    ];
    final visibleSites = searching || _allSites
        ? matchedSites
        : matchedSites.take(SsiBuddiesScreen.sitesShownAtFirst).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.ssiBuddy)),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : empty
          ? const _EmptyBuddies()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                96,
              ),
              children: [
                // A logbook that could not be read, said where the things
                // that came out of it are listed. The expired-token case is
                // why: the session is dropped and the logbook forgotten, so
                // green ticks disappear - and that now happens behind an
                // ordinary pull-to-refresh, where nothing else would say so.
                for (final account in accounts.accounts)
                  if (sync.failures[account.id] case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: _SyncFailure(account: account, message: message),
                    ),

                if (total > SsiBuddiesScreen.searchThreshold) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      labelText: s.search,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],

                if (matchedAccounts.isNotEmpty) ...[
                  SectionHeader(
                    title: s.fromAccounts,
                    trailing: _Count(
                      shown: matchedAccounts.length,
                      total: withIdentity.length,
                    ),
                  ),
                  for (final account in matchedAccounts) ...[
                    _AccountBuddyCard(account: account),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (matchedBuddies.isNotEmpty) ...[
                  SectionHeader(
                    title: withIdentity.isEmpty ? s.stored : s.alsoStored,
                    trailing: _Count(
                      shown: matchedBuddies.length,
                      total: standalone.length,
                    ),
                  ),
                  for (final buddy in matchedBuddies) ...[
                    _BuddyCard(buddy: buddy),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (matchedCentres.isNotEmpty) ...[
                  SectionHeader(
                    title: s.diveCentres,
                    trailing: _Count(
                      shown: matchedCentres.length,
                      total: centers.centers.length,
                    ),
                  ),
                  for (final center in matchedCentres) ...[
                    _CenterCard(center: center),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (matchedSites.isNotEmpty) ...[
                  SectionHeader(
                    title: s.diveSites,
                    trailing: _Count(
                      shown: matchedSites.length,
                      total: sites.sites.length,
                    ),
                  ),
                  for (final group in _byRegion(visibleSites, s)) ...[
                    _RegionHeader(title: group.region),
                    for (final site in group.sites) ...[
                      _SiteCard(site: site),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  if (visibleSites.length < matchedSites.length)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _allSites = true),
                        child: Text(s.showMore),
                      ),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scan(context),
        // One button for both kinds: the scanner reads whichever code is
        // held up, so making the user choose first would be a question the
        // code already answers.
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(s.scanCode),
      ),
    );
  }
}

/// "3 von 41" beside a section heading.
///
/// Only while a search is narrowing it: a filtered list otherwise looks
/// like a short one, which is the same trap the dot on the dive filter
/// closes.
class _Count extends StatelessWidget {
  const _Count({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (shown == total) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      AppStrings.of(context).filteredCount(shown, total),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.extension<AppPalette>()!.inkMuted,
      ),
    );
  }
}

/// The sites grouped by the region SSI files them under, regions in
/// alphabetical order and the ungrouped ones last.
///
/// Grouping rather than sorting: a list of a hundred sites from six trips
/// reads as one undifferentiated wall, and "Gozo" is the word that says
/// which trip a name belongs to. Sites without a region go to the bottom
/// under their own heading rather than being folded into the last group,
/// where they would look like they belonged to it.
///
/// The order inside a group is whatever came in - the controller keeps its
/// sites alphabetical, so the groups are too.
List<({String region, List<DiveSite> sites})> _byRegion(
  List<DiveSite> sites,
  AppStrings s,
) {
  final groups = <String, List<DiveSite>>{};
  final ungrouped = <DiveSite>[];
  for (final site in sites) {
    if (site.region case final region?) {
      groups.putIfAbsent(region, () => []).add(site);
    } else {
      ungrouped.add(site);
    }
  }

  final regions = groups.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final region in regions) (region: region, sites: groups[region]!),
    if (ungrouped.isNotEmpty) (region: s.withoutRegion, sites: ungrouped),
  ];
}

/// A region above its sites. Deliberately quieter than [SectionHeader]:
/// this divides one section, it does not open a new one.
class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.extension<AppPalette>()!.inkMuted,
        ),
      ),
    );
  }
}

/// One dive site as this device knows it.
///
/// Name and position. SSI's site id stays off the card - it is in the QR
/// payload and in the dive's detail view, where it can be checked against
/// something; here it would be a number nobody reads. The coordinates are
/// the opposite: they say which of two similarly named places this is, and
/// they can be pasted straight into a map.
class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 18, color: palette.inkMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(site.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  site.coordinatesLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A logbook that could not be read, and the way back in.
class _SyncFailure extends StatelessWidget {
  const _SyncFailure({required this.account, required this.message});

  final GarminAccount account;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  s.syncFailedFor(account.displayName, message),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SsiIdentityScreen(accountId: account.id),
                ),
              ),
              child: Text(s.signInAgain),
            ),
          ),
        ],
      ),
    );
  }
}

/// An account that has an SSI number stored. Shown for the same reason as
/// a buddy - so their code can be handed to someone - but without the edit
/// and delete actions: those belong to the account, not to this list.
class _AccountBuddyCard extends StatelessWidget {
  const _AccountBuddyCard({required this.account});

  final GarminAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final identity = account.ssiIdentity!;
    final color = account.color?.of(context);

    return AppCard(
      edgeColor: color,
      onTap: () => _showQr(context, identity),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color ?? palette.accentContainer,
            child: Icon(
              Icons.watch_outlined,
              size: 20,
              color: account.color?.inkOn(context) ?? theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  s.ssiNumber(account.ssiMemberId!),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Says why this row has no options menu.
                AppChip(label: s.garminAccountChip),
              ],
            ),
          ),
          Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _EmptyBuddies extends StatelessWidget {
  const _EmptyBuddies();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 44, color: palette.inkMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.noBuddiesYetTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.noBuddiesYetBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: Text(s.addBuddyByHand),
              onPressed: () => enterBuddyManually(context),
            ),
            TextButton.icon(
              icon: const Icon(Icons.store_outlined),
              label: Text(s.addCentreByHand),
              onPressed: () => enterCenterManually(context),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BuddyAction { edit, remove }

class _BuddyCard extends StatelessWidget {
  const _BuddyCard({required this.buddy});

  final SsiBuddyCode buddy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    // A buddy without a name is already titled by their number, so only
    // repeat it here when the title is an actual name.
    final subtitle = [
      buddy.memberIdLine(s),
      buddy.professionalNumberLine(s),
      buddy.email,
    ].whereType<String>().join(' · ');

    return AppCard(
      // Tapping shows the code, which is the thing you do with a buddy
      // when someone else wants to save them.
      onTap: () => _showQr(context, buddy, saved: true),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentContainer,
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buddy.displayName(s),
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Says what the tap does. Editing and removing live on the code's
          // own page, so the row stays a single target.
          Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

/// A saved dive centre. Same shape as a buddy card, but a base has no
/// mail address and no leader number, so its second line is just its
/// number - and only when the name isn't already that number.
class _CenterCard extends StatelessWidget {
  const _CenterCard({required this.center});

  final SsiCenterCode center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final subtitle = center.centerIdLine(s);

    return AppCard(
      onTap: () => _showCenterQr(context, center),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentContainer,
            child: Icon(
              Icons.store_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center.displayName(s),
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

/// Shows the member as the same kind of code the SSI app shows under
/// "Dein QR-Code", so another device can scan them straight into its own
/// buddy list - including this app's scanner.
///
/// [saved] marks an entry this app owns: those get edit and remove on the
/// code's page. An account's number is not one of them - it belongs to the
/// account, and deleting it here would be ambiguous about what it deletes.
void _showQr(BuildContext context, SsiBuddyCode buddy, {bool saved = false}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => saved
          ? _SavedBuddyQr(memberId: buddy.memberId)
          : _buddyQr(context, buddy),
    ),
  );
}

QrDisplayScreen _buddyQr(
  BuildContext context,
  SsiBuddyCode buddy, {
  List<Widget>? actions,
}) {
  final s = AppStrings.of(context);
  return QrDisplayScreen(
    title: buddy.displayName(s),
    payload: buddy.toPayload(),
    caption: s.ssiNumber(buddy.memberId),
    hint: s.buddyQrHint,
    actions: actions,
  );
}

/// The code of a saved buddy, read live from the list.
///
/// Watching rather than holding a copy: an edit made from this page has to
/// change the code that is on screen, and a removal has to take the page
/// with it instead of leaving a code for someone who is gone.
class _SavedBuddyQr extends StatelessWidget {
  const _SavedBuddyQr({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final buddies = context.watch<SsiBuddiesController>().buddies;
    final index = buddies.indexWhere((b) => b.memberId == memberId);
    // Removed, or edited into a different member number: there is nothing
    // left to show under this one.
    if (index == -1) return _popBack(context);

    final buddy = buddies[index];
    return _buddyQr(
      context,
      buddy,
      actions: [
        PopupMenuButton<_BuddyAction>(
          icon: const Icon(Icons.more_horiz),
          tooltip: s.options,
          onSelected: (action) => switch (action) {
            _BuddyAction.edit => enterBuddyManually(context, existing: buddy),
            _BuddyAction.remove => context.read<SsiBuddiesController>().remove(
              memberId,
            ),
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: _BuddyAction.edit, child: Text(s.edit)),
            PopupMenuItem(value: _BuddyAction.remove, child: Text(s.remove)),
          ],
        ),
      ],
    );
  }
}

void _showCenterQr(BuildContext context, SsiCenterCode center) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _SavedCenterQr(centerId: center.centerId),
    ),
  );
}

/// Same as [_SavedBuddyQr], for a base.
class _SavedCenterQr extends StatelessWidget {
  const _SavedCenterQr({required this.centerId});

  final String centerId;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final centers = context.watch<SsiCentersController>().centers;
    final index = centers.indexWhere((c) => c.centerId == centerId);
    if (index == -1) return _popBack(context);

    final center = centers[index];
    return QrDisplayScreen(
      title: center.displayName(s),
      payload: center.toPayload(),
      caption: s.centreNumberLine(center.centerId),
      hint: s.centreQrHint,
      actions: [
        PopupMenuButton<_BuddyAction>(
          icon: const Icon(Icons.more_horiz),
          tooltip: s.options,
          onSelected: (action) => switch (action) {
            _BuddyAction.edit => enterCenterManually(context, existing: center),
            _BuddyAction.remove => context.read<SsiCentersController>().remove(
              centerId,
            ),
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: _BuddyAction.edit, child: Text(s.edit)),
            PopupMenuItem(value: _BuddyAction.remove, child: Text(s.remove)),
          ],
        ),
      ],
    );
  }
}

/// Leaves the page once what it was showing is gone. White rather than
/// empty: this is on screen for the length of the pop animation, and the
/// code's page is white.
Widget _popBack(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) Navigator.of(context).maybePop();
  });
  return const Scaffold(backgroundColor: Colors.white);
}

/// Scans either kind of code and files it where it belongs. Which list an
/// entry lands in is decided by the code itself, not by the user picking
/// beforehand.
Future<void> _scan(BuildContext context) async {
  final buddies = context.read<SsiBuddiesController>();
  final centers = context.read<SsiCentersController>();
  final s = AppStrings.of(context);
  final code = await Navigator.of(
    context,
  ).push<Object>(MaterialPageRoute(builder: (_) => const SsiCodeScanScreen()));
  if (code == null) return;

  final String name;
  switch (code) {
    case SsiBuddyCode():
      await buddies.save(code);
      name = code.displayName(s);
    case SsiCenterCode():
      await centers.save(code);
      name = code.displayName(s);
    default:
      // The scanner only ever pops one of the two; anything else means the
      // scanner grew a case this screen doesn't handle yet.
      return;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(s.savedConfirmation(name))));
}

/// Manual fallback, for a tablet without a working camera or a buddy who
/// only knows their number.
Future<void> enterBuddyManually(
  BuildContext context, {
  SsiBuddyCode? existing,
}) async {
  final controller = context.read<SsiBuddiesController>();
  final buddy = await showDialog<SsiBuddyCode>(
    context: context,
    builder: (_) => _BuddyDialog(existing: existing),
  );
  if (buddy == null) return;
  // Editing the number means a different member - drop the old entry so it
  // doesn't linger as a duplicate of the same person.
  if (existing != null && existing.memberId != buddy.memberId) {
    await controller.remove(existing.memberId);
  }
  await controller.save(buddy);
}

class _BuddyDialog extends StatefulWidget {
  const _BuddyDialog({this.existing});

  final SsiBuddyCode? existing;

  @override
  State<_BuddyDialog> createState() => _BuddyDialogState();
}

class _BuddyDialogState extends State<_BuddyDialog> {
  late final _memberId = TextEditingController(
    text: widget.existing?.memberId ?? '',
  );
  late final _firstName = TextEditingController(
    text: widget.existing?.firstName ?? '',
  );
  late final _lastName = TextEditingController(
    text: widget.existing?.lastName ?? '',
  );

  @override
  void dispose() {
    _memberId.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _submit() {
    final memberId = _memberId.text.trim();
    if (memberId.isEmpty) return;

    String? trimmed(TextEditingController c) {
      final value = c.text.trim();
      return value.isEmpty ? null : value;
    }

    Navigator.of(context).pop(
      SsiBuddyCode(
        memberId: memberId,
        firstName: trimmed(_firstName),
        lastName: trimmed(_lastName),
        // Not asked for: the mail address only arrives via a scan, and
        // typing someone else's in by hand serves no purpose here.
        email: widget.existing?.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(widget.existing == null ? s.newBuddy : s.editBuddy),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _memberId,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.ssiMemberNumber),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _firstName,
            decoration: InputDecoration(labelText: s.firstName),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lastName,
            decoration: InputDecoration(labelText: s.lastName),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}

/// Manual fallback for a dive centre, same reasoning as for a buddy: the
/// number is printed on the base's own material even when no one is around
/// to hold up a phone.
Future<void> enterCenterManually(
  BuildContext context, {
  SsiCenterCode? existing,
}) async {
  final controller = context.read<SsiCentersController>();
  final center = await showDialog<SsiCenterCode>(
    context: context,
    builder: (_) => _CenterDialog(existing: existing),
  );
  if (center == null) return;
  // Editing the number means a different base - drop the old entry so it
  // doesn't linger as a duplicate.
  if (existing != null && existing.centerId != center.centerId) {
    await controller.remove(existing.centerId);
  }
  await controller.save(center);
}

class _CenterDialog extends StatefulWidget {
  const _CenterDialog({this.existing});

  final SsiCenterCode? existing;

  @override
  State<_CenterDialog> createState() => _CenterDialogState();
}

class _CenterDialogState extends State<_CenterDialog> {
  late final _centerId = TextEditingController(
    text: widget.existing?.centerId ?? '',
  );
  late final _name = TextEditingController(text: widget.existing?.name ?? '');

  @override
  void dispose() {
    _centerId.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final centerId = _centerId.text.trim();
    if (centerId.isEmpty) return;
    final name = _name.text.trim();

    Navigator.of(
      context,
    ).pop(SsiCenterCode(centerId: centerId, name: name.isEmpty ? null : name));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(widget.existing == null ? s.newCentre : s.editCentre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _centerId,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.centreNumber),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.centreName),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
