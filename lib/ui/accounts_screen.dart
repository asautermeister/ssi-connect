import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import 'add_account_screen.dart';
import 'debug_log_screen.dart';
import 'dive_list_screen.dart';
import 'fit_import_flow.dart';
import 'ssi_buddies_screen.dart';
import 'ssi_identity_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// Start screen: pick whose dives to browse, add another Garmin account, or
/// import a FIT file when the Garmin login isn't available.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSI Connect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'SSI-Buddies',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SsiBuddiesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'FIT-Datei importieren',
            onPressed: () => pickAndImportFitFile(context),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'API-Protokoll',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
          ),
        ],
      ),
      body: Consumer<AccountsController>(
        builder: (context, controller, _) {
          if (!controller.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.accounts.isEmpty) {
            return const _EmptyAccounts();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: controller.accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _AccountCard(account: controller.accounts[index]),
          );
        },
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

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

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
            Icon(Icons.scuba_diving, size: 44, color: palette.inkMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Noch kein Garmin-Account verbunden',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Verbinde einen Account, um Tauchgänge zu laden – '
              'oder importiere oben rechts eine FIT-Datei.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { ssiIdentity, remove }

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final GarminAccount account;

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
                Text(
                  account.hasSsiIdentity
                      ? 'SSI-Nr. ${account.ssiMemberId}'
                      : 'Keine SSI-Nummer hinterlegt',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<_AccountAction>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Optionen',
            onSelected: (action) => switch (action) {
              _AccountAction.ssiIdentity => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SsiIdentityScreen(accountId: account.id),
                ),
              ),
              _AccountAction.remove => _confirmRemove(context),
            },
            itemBuilder: (context) => const [
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

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
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
