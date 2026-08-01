import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/dive_loader.dart';
import '../dives/recent_dives_controller.dart';
import 'add_account_screen.dart';
import 'debug_log_screen.dart';
import 'dive_list_screen.dart';
import 'fit_import_flow.dart';
import 'format.dart';
import 'qr_screen.dart';
import 'ssi_buddies_screen.dart';
import 'ssi_identity_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';

/// Start screen. Leads with the dives themselves rather than with a list of
/// names: the reason to open this app is to hand a dive to SSI, and from
/// here that is one tap.
///
/// Below that the accounts, and below those the things that used to hide as
/// icons in the app bar - a list nobody finds is a list nobody uses.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final GarminDiveLoader _loader = GarminDiveLoader(
    refreshSession: (account) =>
        context.read<AccountsController>().ensureFreshSession(account),
  );

  /// Kicks off the fetch once the accounts are known. Called from build,
  /// which is safe because [RecentDivesController.load] returns immediately
  /// for a set of accounts it already has.
  void _loadAfterBuild(List<GarminAccount> accounts, {bool force = false}) {
    if (accounts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RecentDivesController>().load(
        accounts: accounts,
        fetch: _loader.load,
        force: force,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountsController>();
    final recentDives = context.watch<RecentDivesController>();
    final accounts = controller.accounts;

    if (controller.loaded) _loadAfterBuild(accounts);

    return Scaffold(
      appBar: AppBar(title: const Text('SSI Connect')),
      body: !controller.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadAfterBuild(accounts, force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  96,
                ),
                children: [
                  if (accounts.isEmpty)
                    const _EmptyAccounts()
                  else ...[
                    _RecentDives(accounts: accounts, controller: recentDives),
                    const SectionHeader(title: 'Accounts'),
                    for (final account in accounts) ...[
                      _AccountCard(
                        account: account,
                        dives: recentDives.forAccount(account.id),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  const SectionHeader(title: 'Mehr'),
                  const _QuickActions(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Account'),
      ),
    );
  }
}

/// The newest dives across every account, most recent first. Tapping one
/// goes straight to its QR code - the whole point of the app, so it should
/// not take four taps to reach.
class _RecentDives extends StatelessWidget {
  const _RecentDives({required this.accounts, required this.controller});

  final List<GarminAccount> accounts;
  final RecentDivesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = controller.recent(accounts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Zuletzt getaucht'),
        if (recent.isEmpty)
          AppCard(
            child: Row(
              children: [
                if (controller.isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Tauchgänge werden geladen …',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else
                  Expanded(
                    child: Text(
                      controller.failedCount > 0
                          ? 'Tauchgänge konnten nicht geladen werden. '
                                'Zum Erneut-Versuchen nach unten ziehen.'
                          : 'Noch keine Tauchgänge geladen.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          )
        else ...[
          for (final entry in recent) ...[
            _RecentDiveCard(entry: entry),
            const SizedBox(height: AppSpacing.md),
          ],
          // Named rather than silently missing: with several accounts on one
          // tablet, one broken login is normal, and a short list would
          // otherwise look complete.
          if (controller.failedCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                controller.failedCount == 1
                    ? 'Ein Account konnte nicht geladen werden.'
                    : '${controller.failedCount} Accounts konnten nicht '
                          'geladen werden.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _RecentDiveCard extends StatelessWidget {
  const _RecentDiveCard({required this.entry});

  final RecentDive entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final dive = entry.dive;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              QrScreen(dive: dive, diver: entry.account.ssiIdentity),
        ),
      ),
      child: Row(
        children: [
          DiveTypeIcon(type: dive.type, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.weekday(dive.dateTime)}, ${Fmt.date(dive.dateTime)}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    entry.account.displayName,
                    if (dive.duration != null)
                      '${Fmt.minutes(dive.duration)} min',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Fmt.meters(dive.maxDepthMeters),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          // Says where the tap goes, so the card isn't a guess.
          Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.scuba_diving, size: 44, color: palette.inkMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Noch kein Garmin-Account verbunden',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Verbinde einen Account, um Tauchgänge zu laden – oder importiere '
            'unten eine FIT-Datei.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _AccountAction { rename, ssiIdentity, remove }

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.dives});

  final GarminAccount account;
  final AccountDives dives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiveListScreen(account: account)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentContainer,
            child: Text(
              _initials(account.displayName),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
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
                Text(_diveSummary(dives), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                if (account.hasSsiIdentity)
                  Text(
                    'SSI-Nr. ${account.ssiMemberId}',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  // Without a number the exported dive lands under whoever
                  // is logged into SSI, so this is worth fixing - and worth
                  // being one tap away.
                  _MissingSsiNumber(accountId: account.id),
              ],
            ),
          ),
          PopupMenuButton<_AccountAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _AccountAction.rename => _rename(context),
              _AccountAction.ssiIdentity => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SsiIdentityScreen(accountId: account.id),
                ),
              ),
              _AccountAction.remove => _confirmRemove(context),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AccountAction.rename,
                child: Text('Namen ändern'),
              ),
              PopupMenuItem(
                value: _AccountAction.ssiIdentity,
                child: Text('SSI-Identität'),
              ),
              PopupMenuItem(
                value: _AccountAction.remove,
                child: Text('Account entfernen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _diveSummary(AccountDives dives) {
    if (dives.isLoading) return 'Tauchgänge werden geladen …';
    if (dives.hasError) return 'Tauchgänge nicht erreichbar';
    final latest = dives.latest;
    if (latest == null) return 'Keine Tauchgänge gefunden';
    return 'Zuletzt: ${Fmt.date(latest.dateTime)} · '
        '${Fmt.meters(latest.maxDepthMeters)} m';
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  Future<void> _rename(BuildContext context) async {
    final controller = context.read<AccountsController>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialValue: account.displayName),
    );
    if (name == null) return;
    await controller.rename(account.id, name);
  }

  /// Removing an account drops its stored tokens, which means a full
  /// re-login with a fresh MFA code - worth a confirmation step.
  Future<void> _confirmRemove(BuildContext context) async {
    final controller = context.read<AccountsController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account entfernen?'),
        content: Text(
          '${account.displayName} wird von diesem Gerät entfernt. '
          'Für einen erneuten Zugriff ist ein neuer Login nötig.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.removeAccount(account.id);
    }
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Angezeigter Name',
          helperText: 'Leer lassen für die E-Mail-Adresse',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _MissingSsiNumber extends StatelessWidget {
  const _MissingSsiNumber({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SsiIdentityScreen(accountId: accountId),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'SSI-Nummer hinterlegen',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three side entrances, as labelled cards instead of app-bar icons.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.group_outlined,
          title: 'SSI-Buddies',
          subtitle: 'Mittaucher speichern und beim Export auswählen',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SsiBuddiesScreen())),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          icon: Icons.upload_file_outlined,
          title: 'FIT-Datei importieren',
          subtitle: 'Falls der Garmin-Login gerade nicht funktioniert',
          onTap: () => pickAndImportFitFile(context),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          icon: Icons.bug_report_outlined,
          title: 'API-Protokoll',
          subtitle: 'Fehler nachsehen und SSI-Codes analysieren',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.accentContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.inkMuted),
        ],
      ),
    );
  }
}
