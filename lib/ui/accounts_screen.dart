import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/account_color.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/dive_loader.dart';
import '../dives/refresh.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_sync_controller.dart';
import '../dives/exported_dives_controller.dart';
import '../dives/recent_dives_controller.dart';
import 'add_account_screen.dart';
import 'all_dives_screen.dart';
import 'dive_list_screen.dart';
import 'fit_import_flow.dart';
import 'format.dart';
import 'info_screen.dart';
import 'recent_dive_card.dart';
import 'settings_screen.dart';
import 'ssi_buddies_screen.dart';
import 'ssi_identity_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/offline_banner.dart';

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
  /// Kicks off the fetch once the accounts are known. Called from build,
  /// which is safe because a fetch that is not due yet does nothing.
  void _loadAfterBuild(
    List<GarminAccount> accounts, {
    RefreshReason reason = RefreshReason.automatic,
  }) {
    if (accounts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dives = context.read<RecentDivesController>();
      // The one screen that sees every account, so the one place that can
      // say which of them are gone.
      dives.retain(accounts);
      refreshAccounts(
        scope: accounts,
        reason: reason,
        dives: dives,
        fetch: context.read<DiveFetcher>(),
        accounts: context.read<AccountsController>(),
        sites: context.read<DiveSitesController>(),
        buddies: context.read<SsiBuddiesController>(),
        exported: context.read<ExportedDivesController>(),
        sync: context.read<SsiSyncController>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountsController>();
    final recentDives = context.watch<RecentDivesController>();
    final accounts = controller.accounts;
    final s = AppStrings.of(context);

    if (controller.loaded) _loadAfterBuild(accounts);

    return Scaffold(
      appBar: AppBar(title: Text(s.appName)),
      body: !controller.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  _loadAfterBuild(accounts, reason: RefreshReason.userAsked),
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
                    if (recentDives.isOffline || recentDives.isShowingCache)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: OfflineBanner(
                          isOffline: recentDives.isOffline,
                          fetchedAt: recentDives.oldestFetchedAt,
                          onRetry: () => _loadAfterBuild(
                            accounts,
                            reason: RefreshReason.userAsked,
                          ),
                        ),
                      ),
                    _RecentDives(accounts: accounts, controller: recentDives),
                    SectionHeader(title: s.accountsSection),
                    for (final account in accounts) ...[
                      _AccountCard(
                        account: account,
                        dives: recentDives.forAccount(account.id),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  SectionHeader(title: s.moreSection),
                  const _QuickActions(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        icon: const Icon(Icons.person_add_alt),
        label: Text(s.addAccount),
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
    final s = AppStrings.of(context);
    final recent = controller.recent(accounts);
    // Matched over every loaded dive, not over the five on show. Two
    // reasons, and the second is the one that bit: the match is one-to-one
    // across an account's dives, so a five-dive subset could hand an entry
    // to a different dive than the full list would - and the ticks travel
    // with the swipe, which runs through all of them. Computed over five,
    // everything older than the fifth arrived without a tick.
    final all = controller.merged(accounts);
    final inLogbook = context.watch<ExportedDivesController>().matchedAcross(
      all,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: s.recentDives)),
            // Only once there is something to look at - the full list would
            // otherwise just repeat the empty state below it.
            if (recent.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllDivesScreen()),
                ),
                child: Text(s.showAll),
              ),
          ],
        ),
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
                  Text(s.divesLoading, style: theme.textTheme.bodyMedium),
                ] else
                  Expanded(
                    child: Text(
                      controller.failedCount > 0
                          ? s.divesLoadFailedPullToRetry
                          : s.noDivesLoadedYet,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          )
        else ...[
          for (final entry in recent) ...[
            RecentDiveCard(
              entry: entry,
              inSsiLogbook: inLogbook.contains(entry.dive.id),
              // Every loaded dive, not the five on show. These five are a
              // preview of the account's dives, not a list in their own
              // right - swiping out of them after the fifth would stop for
              // no reason the screen ever gave. The card narrows this to
              // the diver whose dive was tapped.
              siblings: all,
              siblingsInLogbook: inLogbook,
            ),
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
                    ? s.oneAccountFailed
                    : s.accountsFailed(controller.failedCount),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.scuba_diving, size: 44, color: palette.inkMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            s.noAccountYetTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.noAccountYetBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _AccountAction { rename, color, ssiIdentity, clearCache, remove }

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.dives});

  final GarminAccount account;
  final AccountDives dives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;

    final color = account.color?.of(context);

    return AppCard(
      edgeColor: color,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiveListScreen(account: account)),
      ),
      child: Row(
        children: [
          // The avatar carries the colour too, so the bar on a dive card
          // can be traced back to a face on this screen.
          CircleAvatar(
            radius: 20,
            backgroundColor: color ?? palette.accentContainer,
            child: Text(
              _initials(account.displayName),
              style: theme.textTheme.titleMedium?.copyWith(
                color:
                    account.color?.inkOn(context) ?? theme.colorScheme.primary,
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
                Text(_diveSummary(dives, s), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                if (account.hasSsiIdentity)
                  Text(
                    s.ssiNumber(account.ssiMemberId!),
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
            tooltip: s.options,
            onSelected: (action) => switch (action) {
              _AccountAction.rename => _rename(context),
              _AccountAction.color => _pickColor(context),
              _AccountAction.ssiIdentity => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SsiIdentityScreen(accountId: account.id),
                ),
              ),
              _AccountAction.clearCache => _clearCache(context),
              _AccountAction.remove => _confirmRemove(context),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AccountAction.rename,
                child: Text(s.renameAccount),
              ),
              PopupMenuItem(
                value: _AccountAction.color,
                child: Text(s.chooseColour),
              ),
              PopupMenuItem(
                value: _AccountAction.ssiIdentity,
                child: Text(s.ssiIdentity),
              ),
              PopupMenuItem(
                value: _AccountAction.clearCache,
                child: Text(s.deleteStoredDives),
              ),
              PopupMenuItem(
                value: _AccountAction.remove,
                child: Text(s.removeAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _diveSummary(AccountDives dives, AppStrings s) {
    if (dives.isLoading) return s.divesLoading;
    if (dives.hasError) return s.divesUnreachable;
    final latest = dives.latest;
    if (latest == null) return s.noDivesFound;
    return s.lastDive(
      Fmt.date(latest.dateTime),
      Fmt.meters(latest.maxDepthMeters),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  /// Removes this account's dives from the device. They are health data,
  /// so getting rid of them has to be possible without deleting the whole
  /// account.
  Future<void> _clearCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Read before the await - afterwards the context may be gone.
    final message = AppStrings.of(context).storedDivesDeleted;
    await context.read<RecentDivesController>().forget(account.id);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickColor(BuildContext context) async {
    final controller = context.read<AccountsController>();
    final choice = await showDialog<_ColorChoice>(
      context: context,
      builder: (_) => _ColorDialog(selected: account.color),
    );
    if (choice == null) return;
    await controller.setColor(account.id, choice.color);
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
    final dives = context.read<RecentDivesController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final s = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(s.removeAccountQuestion),
          content: Text(s.removeAccountBody(account.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.remove),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await controller.removeAccount(account.id);
      // The cached dives have to go with the account - leaving someone's
      // dive profiles on the tablet after they were removed from it would
      // be exactly what nobody expects.
      await dives.forget(account.id);
    }
  }
}

/// Wrapper so "no colour" can be returned as a real answer rather than as
/// null, which the dialog already uses to mean "cancelled".
class _ColorChoice {
  const _ColorChoice(this.color);

  final AccountColor? color;
}

class _ColorDialog extends StatelessWidget {
  const _ColorDialog({required this.selected});

  final AccountColor? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.colour),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.colourExplanation, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final color in AccountColor.values)
                _Swatch(
                  color: color,
                  isSelected: color == selected,
                  onTap: () => Navigator.of(context).pop(_ColorChoice(color)),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _ColorChoice(null)),
          child: Text(s.noColour),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final AccountColor color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = color.of(context);
    final label = color.label(AppStrings.of(context));

    return Semantics(
      // The name, not just the patch - a colour picker that can only be
      // used by seeing the colours is the one place that really would
      // shut someone out.
      label: label,
      selected: isSelected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resolved,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, size: 20, color: color.inkOn(context))
                : null,
          ),
        ),
      ),
    );
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
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: s.displayedName,
          helperText: s.leaveEmptyForEmail,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(s.save),
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
    final s = AppStrings.of(context);

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
            s.storeSsiNumber,
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
    final s = AppStrings.of(context);

    return Column(
      children: [
        _ActionCard(
          icon: Icons.group_outlined,
          title: s.quickBuddyTitle,
          subtitle: s.quickBuddySubtitle,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SsiBuddiesScreen())),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          icon: Icons.upload_file_outlined,
          title: s.quickFitTitle,
          subtitle: s.quickFitSubtitle,
          onTap: () => pickAndImportFitFile(context),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          icon: Icons.tune,
          title: s.quickSettingsTitle,
          subtitle: s.quickSettingsSubtitle,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          icon: Icons.info_outline,
          title: s.quickInfoTitle,
          subtitle: s.quickInfoSubtitle,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
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
