import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../dives/dive_loader.dart';
import '../dives/recent_dives_controller.dart';
import '../garmin/garmin_auth_exceptions.dart';
import 'recent_dive_card.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// Every loaded dive across all accounts, newest first, with a button to
/// fetch the next page from Garmin.
///
/// The start screen shows the newest five, which is the right length for a
/// screen you open to hand today's dive to SSI. This is the other case:
/// looking for a dive from last summer. It opens on what is already loaded
/// - so instantly, and offline too - and only goes to the network when
/// asked.
class AllDivesScreen extends StatelessWidget {
  const AllDivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountsController>().accounts;
    final controller = context.watch<RecentDivesController>();
    final dives = controller.merged(accounts);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.allDives)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          for (final entry in dives) ...[
            RecentDiveCard(entry: entry),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          _LoadMore(
            controller: controller,
            onPressed: () => controller.loadMore(
              accounts: accounts,
              fetch: context.read<DiveFetcher>(),
            ),
            loadedCount: dives.length,
          ),
        ],
      ),
    );
  }
}

/// The foot of the list: how many dives are loaded, and either a way to get
/// more or the plain statement that there are none.
class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.controller,
    required this.onPressed,
    required this.loadedCount,
  });

  final RecentDivesController controller;
  final VoidCallback onPressed;
  final int loadedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final error = controller.loadMoreError;

    return Column(
      children: [
        Text(
          s.divesLoadedCount(loadedCount),
          style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        if (error != null) ...[
          AppCard(
            child: Text(
              error is GarminAuthException ? error.message : s.loadMoreFailed,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (controller.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(),
          )
        else if (controller.hasMore)
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.history),
            label: Text(error == null ? s.loadOlderDives : s.retry),
          )
        else
          Text(
            // Said outright, so a list that stops isn't mistaken for one
            // that failed.
            s.noOlderDives,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
