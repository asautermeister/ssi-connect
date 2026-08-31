import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../l10n/app_strings.dart';
import '../dives/exported_dives_controller.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_sync_controller.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// The manual SSI sync, for when an automatic one did not do what it
/// should have.
///
/// Only shown in diagnostic mode. Every refresh pulls the logbooks now, so
/// this is no longer a way anybody needs - only a lever for taking one
/// deliberately and watching what comes back. What the sync produced -
/// the sites, the buddies, and any account it failed for - is listed under
/// "SSI Buddy", beside the things themselves.
class SsiSitesSection extends StatelessWidget {
  const SsiSitesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final sites = context.watch<DiveSitesController>();
    final buddies = context.watch<SsiBuddiesController>();
    final accounts = context.watch<AccountsController>();
    final sync = context.watch<SsiSyncController>();
    final connected = accounts.accounts.where((a) => a.hasSsiLogin).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: s.ssiLogbook),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sync.lastSyncAt case final at?)
                Text(
                  s.lastSyncedAt(Fmt.dateTime(at)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              if (connected.isEmpty)
                Text(s.noSsiAccountConnected, style: theme.textTheme.bodySmall)
              else ...[
                for (final account in connected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: palette.inkMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            s.ssiConnectedAs(
                              account.ssiSession?.email ?? account.displayName,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(s.ssiSyncExplanation, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(s.ssiSyncSites),
                    onPressed: sync.isBusy
                        ? null
                        : () => context.read<SsiSyncController>().syncAccounts(
                            scope: accounts.accounts,
                            accounts: accounts,
                            sites: sites,
                            buddies: buddies,
                            exported: context.read<ExportedDivesController>(),
                          ),
                  ),
                ],
              ],

              if (sync.isBusy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ],

              if (sync.error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ] else if (!sync.isBusy && sync.lastSiteCount != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  (sync.lastAddedCount ?? 0) == 0
                      ? s.ssiSitesUpToDate(sync.lastSiteCount!)
                      : s.ssiSitesImported(
                          sync.lastAddedCount!,
                          sync.lastSiteCount!,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
                // Only worth a line when something came of it - "0 new
                // buddies" after every sync is noise.
                if ((sync.lastBuddyAddedCount ?? 0) > 0)
                  Text(
                    s.ssiBuddiesImported(sync.lastBuddyAddedCount!),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(s.ssiUnofficialNote, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
