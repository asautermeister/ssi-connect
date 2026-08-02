import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_center_code.dart';
import '../ssi/ssi_centers_controller.dart';
import 'qr_display_screen.dart';
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
class SsiBuddiesScreen extends StatelessWidget {
  const SsiBuddiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buddies = context.watch<SsiBuddiesController>();
    final centers = context.watch<SsiCentersController>();
    final accounts = context.watch<AccountsController>();

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
        withIdentity.isEmpty && standalone.isEmpty && centers.centers.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('SSI Buddy')),
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
                if (withIdentity.isNotEmpty) ...[
                  const SectionHeader(title: 'Aus den Accounts'),
                  for (final account in withIdentity) ...[
                    _AccountBuddyCard(account: account),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (standalone.isNotEmpty) ...[
                  SectionHeader(
                    title: withIdentity.isEmpty
                        ? 'Gespeichert'
                        : 'Zusätzlich gespeichert',
                  ),
                  for (final buddy in standalone) ...[
                    _BuddyCard(buddy: buddy),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
                if (centers.centers.isNotEmpty) ...[
                  const SectionHeader(title: 'Tauchbasen'),
                  for (final center in centers.centers) ...[
                    _CenterCard(center: center),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scan(context),
        // One button for both kinds: the scanner reads whichever code is
        // held up, so making the user choose first would be a question the
        // code already answers.
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Code scannen'),
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
                  'SSI-Nr. ${account.ssiMemberId}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Says why this row has no options menu.
                const AppChip(label: 'GARMIN-ACCOUNT'),
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
              'Noch keine Buddies gespeichert',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lass dir den QR-Code deines Buddys in der SSI-App unter '
              '„Dein QR-Code" zeigen und scanne ihn hier. Der Code einer '
              'Tauchbasis funktioniert genauso.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Buddy von Hand eintragen'),
              onPressed: () => enterBuddyManually(context),
            ),
            TextButton.icon(
              icon: const Icon(Icons.store_outlined),
              label: const Text('Tauchbasis von Hand eintragen'),
              onPressed: () => enterCenterManually(context),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BuddyAction { showQr, edit, remove }

class _BuddyCard extends StatelessWidget {
  const _BuddyCard({required this.buddy});

  final SsiBuddyCode buddy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    // A buddy without a name is already titled by their number, so only
    // repeat it here when the title is an actual name.
    final subtitle = [
      buddy.memberIdLine,
      buddy.leaderNumberLine,
      buddy.email,
    ].whereType<String>().join(' · ');

    return AppCard(
      // Tapping shows the code, which is the thing you do with a buddy
      // when someone else wants to save them.
      onTap: () => _showQr(context, buddy),
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
                  buddy.displayName,
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
          PopupMenuButton<_BuddyAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _BuddyAction.showQr => _showQr(context, buddy),
              _BuddyAction.edit => enterBuddyManually(context, existing: buddy),
              _BuddyAction.remove =>
                context.read<SsiBuddiesController>().remove(buddy.memberId),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _BuddyAction.showQr,
                child: Text('Als QR-Code zeigen'),
              ),
              PopupMenuItem(
                value: _BuddyAction.edit,
                child: Text('Bearbeiten'),
              ),
              PopupMenuItem(
                value: _BuddyAction.remove,
                child: Text('Entfernen'),
              ),
            ],
          ),
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
    final palette = theme.extension<AppPalette>()!;
    final subtitle = center.centerIdLine;

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
                  center.displayName,
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
          PopupMenuButton<_BuddyAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _BuddyAction.showQr => _showCenterQr(context, center),
              _BuddyAction.edit => enterCenterManually(
                context,
                existing: center,
              ),
              _BuddyAction.remove =>
                context.read<SsiCentersController>().remove(center.centerId),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _BuddyAction.showQr,
                child: Text('Als QR-Code zeigen'),
              ),
              PopupMenuItem(
                value: _BuddyAction.edit,
                child: Text('Bearbeiten'),
              ),
              PopupMenuItem(
                value: _BuddyAction.remove,
                child: Text('Entfernen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the member as the same kind of code the SSI app shows under
/// "Dein QR-Code", so another device can scan them straight into its own
/// buddy list - including this app's scanner.
void _showQr(BuildContext context, SsiBuddyCode buddy) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QrDisplayScreen(
        title: buddy.displayName,
        payload: buddy.toPayload(),
        caption: 'SSI-Nr. ${buddy.memberId}',
        hint:
            'Mit der Kamera eines anderen Geräts scannen, um diesen Buddy '
            'dort zu speichern.',
      ),
    ),
  );
}

void _showCenterQr(BuildContext context, SsiCenterCode center) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QrDisplayScreen(
        title: center.displayName,
        payload: center.toPayload(),
        caption: 'Basis-Nr. ${center.centerId}',
        hint:
            'Mit der Kamera eines anderen Geräts scannen, um diese '
            'Tauchbasis dort zu speichern.',
      ),
    ),
  );
}

/// Scans either kind of code and files it where it belongs. Which list an
/// entry lands in is decided by the code itself, not by the user picking
/// beforehand.
Future<void> _scan(BuildContext context) async {
  final buddies = context.read<SsiBuddiesController>();
  final centers = context.read<SsiCentersController>();
  final code = await Navigator.of(
    context,
  ).push<Object>(MaterialPageRoute(builder: (_) => const SsiCodeScanScreen()));
  if (code == null) return;

  final String name;
  switch (code) {
    case SsiBuddyCode():
      await buddies.save(code);
      name = code.displayName;
    case SsiCenterCode():
      await centers.save(code);
      name = code.displayName;
    default:
      // The scanner only ever pops one of the two; anything else means the
      // scanner grew a case this screen doesn't handle yet.
      return;
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$name gespeichert')));
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
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Buddy anlegen' : 'Buddy bearbeiten',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _memberId,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'SSI-Mitgliedsnummer'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _firstName,
            decoration: const InputDecoration(labelText: 'Vorname'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lastName,
            decoration: const InputDecoration(labelText: 'Nachname'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: _submit, child: const Text('Speichern')),
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
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Tauchbasis anlegen'
            : 'Tauchbasis bearbeiten',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _centerId,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Basis-Nummer'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name der Basis'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}
