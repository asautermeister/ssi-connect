import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/exported_dives_controller.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddies_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_sync_controller.dart';
import 'ssi_scan_screen.dart';
import 'ssi_sign_in_dialog.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/stat_tile.dart';

/// Shows and edits the SSI identity attached to one Garmin account.
///
/// Three ways in, in the order they are worth trying. Signing in to SSI is
/// first: it reports the member number as `mid`, straight from SSI, and the
/// same login then fills the dive sites out of that person's logbook.
/// Scanning the member QR code and typing the number stay, because not
/// everyone with a dive watch has an SSI login - a guest or a child may
/// have nothing but the number, and a tablet without a working camera still
/// has a keyboard.
class SsiIdentityScreen extends StatelessWidget {
  const SsiIdentityScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.ssiIdentity)),
      body: Consumer<AccountsController>(
        builder: (context, controller, _) {
          final account = controller.accounts
              .where((a) => a.id == accountId)
              .firstOrNull;
          if (account == null) {
            return Center(child: Text(s.accountNotFound));
          }
          return _Body(account: account);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.account});

  final GarminAccount account;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.displayName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              if (account.hasSsiIdentity) ...[
                StatTile(
                  label: 'SSI-Mitgliedsnummer',
                  value: account.ssiMemberId!,
                  emphasis: StatEmphasis.hero,
                ),
                if (account.ssiFullName != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    account.ssiFullName!,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
                if (account.ssiEmail != null)
                  Text(account.ssiEmail!, style: theme.textTheme.bodySmall),
              ] else
                Text(s.noSsiNumberYet, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        SectionHeader(title: s.storeIt),
        if (account.hasSsiLogin) ...[
          Text(
            s.ssiConnectedAs(account.ssiSession!.email),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: Text(s.ssiSignOut),
            onPressed: () =>
                context.read<AccountsController>().clearSsiSession(account.id),
          ),
        ] else ...[
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: Text(s.signInWithSsi),
            onPressed: context.watch<SsiSyncController>().isBusy
                ? null
                : () => _signIn(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(s.ssiAccountHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(s.scanSsiQr),
          onPressed: () => _scan(context),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          icon: const Icon(Icons.keyboard_alt_outlined),
          label: Text(s.enterNumberByHand),
          onPressed: () => _enterManually(context),
        ),
        if (account.hasSsiIdentity) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () =>
                context.read<AccountsController>().clearSsiIdentity(account.id),
            child: Text(s.removeSsiNumber),
          ),
        ],
        if (context.watch<SsiSyncController>().error case final error?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(s.ssiNumberWhereToFind, style: theme.textTheme.bodySmall),
      ],
    );
  }

  /// Signs in, then goes straight on to fetch the dive sites - the login
  /// exists for both, and stopping in between to press a second button
  /// would be a step that only the code needs.
  Future<void> _signIn(BuildContext context) async {
    final sync = context.read<SsiSyncController>();
    final accounts = context.read<AccountsController>();
    final sites = context.read<DiveSitesController>();
    final buddies = context.read<SsiBuddiesController>();
    final exported = context.read<ExportedDivesController>();

    final credentials = await showDialog<({String email, String password})>(
      context: context,
      // The Garmin address is a reasonable first guess at the SSI one, and
      // wrong often enough that it stays editable.
      builder: (_) => SsiSignInDialog(initialEmail: account.email),
    );
    if (credentials == null) return;

    final ok = await sync.signIn(
      accountId: account.id,
      email: credentials.email,
      password: credentials.password,
      accounts: accounts,
    );
    if (ok) {
      // Straight away and without the usual floor: a fresh login is the one
      // moment where there is certainly something to fetch.
      sync.forgetSyncState(account.id);
      final signedIn = accounts.accounts.where((a) => a.id == account.id);
      await sync.syncAccounts(
        scope: signedIn.toList(),
        accounts: accounts,
        sites: sites,
        buddies: buddies,
        exported: exported,
      );
    }
  }

  Future<void> _scan(BuildContext context) async {
    final controller = context.read<AccountsController>();
    final code = await Navigator.of(context).push<SsiBuddyCode>(
      MaterialPageRoute(builder: (_) => const SsiScanScreen()),
    );
    if (code == null) return;
    await controller.setSsiIdentity(account.id, code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).ssiNumberStored(code.memberId)),
      ),
    );
  }

  Future<void> _enterManually(BuildContext context) async {
    final controller = context.read<AccountsController>();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _ManualEntryDialog(initialValue: account.ssiMemberId ?? ''),
    );
    final memberId = entered?.trim();
    if (memberId == null || memberId.isEmpty) return;
    // Keep whatever name was scanned earlier; only the number changes.
    await controller.setSsiIdentity(
      account.id,
      SsiBuddyCode(
        memberId: memberId,
        firstName: account.ssiFirstName,
        lastName: account.ssiLastName,
        email: account.ssiEmail,
      ),
    );
  }
}

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
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
      title: Text(s.ssiMemberNumber),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: s.number),
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
