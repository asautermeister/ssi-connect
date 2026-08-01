import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../ssi/ssi_buddy_code.dart';
import 'ssi_scan_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/stat_tile.dart';

/// Shows and edits the SSI identity attached to one Garmin account.
///
/// Scanning the member QR code is the intended path, but the number can
/// always be typed instead - a tablet without a working camera, or a
/// member who only knows their number, shouldn't be locked out.
class SsiIdentityScreen extends StatelessWidget {
  const SsiIdentityScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSI-Identität')),
      body: Consumer<AccountsController>(
        builder: (context, controller, _) {
          final account = controller.accounts
              .where((a) => a.id == accountId)
              .firstOrNull;
          if (account == null) {
            return const Center(child: Text('Account nicht gefunden.'));
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
                Text(
                  'Noch keine SSI-Nummer hinterlegt.',
                  style: theme.textTheme.bodyLarge,
                ),
            ],
          ),
        ),
        const SectionHeader(title: 'Hinterlegen'),
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('SSI-QR-Code scannen'),
          onPressed: () => _scan(context),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          icon: const Icon(Icons.keyboard_alt_outlined),
          label: const Text('Nummer von Hand eintragen'),
          onPressed: () => _enterManually(context),
        ),
        if (account.hasSsiIdentity) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () =>
                context.read<AccountsController>().clearSsiIdentity(account.id),
            child: const Text('SSI-Nummer entfernen'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Die Nummer steht in der SSI-App unter „Dein QR-Code". Sie wird '
          'nur auf diesem Gerät gespeichert.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
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
      SnackBar(content: Text('SSI-Nummer ${code.memberId} gespeichert')),
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
    return AlertDialog(
      title: const Text('SSI-Mitgliedsnummer'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Nummer'),
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
