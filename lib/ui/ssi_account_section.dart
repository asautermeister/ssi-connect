import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_account_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// Connecting an SSI account, and pulling the dive sites out of its
/// logbook.
///
/// Lives in the settings screen because it is a one-off setup step: once
/// the sites are on the device, the dive detail screen uses them without
/// anyone coming back here.
class SsiAccountSection extends StatelessWidget {
  const SsiAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final account = context.watch<SsiAccountController>();
    final session = account.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: s.ssiAccount),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session == null) ...[
                Text(s.ssiAccountHint, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(s.ssiSignIn),
                  onPressed: account.isBusy
                      ? null
                      : () => _signIn(context, account),
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 18,
                      color: palette.inkMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        s.ssiConnectedAs(session.email),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(s.ssiSyncExplanation, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(s.ssiSyncSites),
                  onPressed: account.isBusy
                      ? null
                      : () => account.syncSites(
                          context.read<DiveSitesController>(),
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: account.isBusy ? null : account.signOut,
                    child: Text(s.ssiSignOut),
                  ),
                ),
              ],

              if (account.isBusy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
              ],

              // Result and failure are mutually exclusive: a new attempt
              // clears the error, and a successful one sets a count.
              if (account.error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ] else if (!account.isBusy && account.lastSiteCount != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  (account.lastAddedCount ?? 0) == 0
                      ? s.ssiSitesUpToDate(account.lastSiteCount!)
                      : s.ssiSitesImported(
                          account.lastAddedCount!,
                          account.lastSiteCount!,
                        ),
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

Future<void> _signIn(BuildContext context, SsiAccountController account) async {
  final credentials = await showDialog<({String email, String password})>(
    context: context,
    builder: (_) => const _SsiSignInDialog(),
  );
  if (credentials == null) return;

  final ok = await account.signIn(
    email: credentials.email,
    password: credentials.password,
  );
  // Straight into the sync - signing in and then having to press a second
  // button is a step that exists only because the code has two methods.
  if (ok && context.mounted) {
    await account.syncSites(context.read<DiveSitesController>());
  }
}

class _SsiSignInDialog extends StatefulWidget {
  const _SsiSignInDialog();

  @override
  State<_SsiSignInDialog> createState() => _SsiSignInDialogState();
}

class _SsiSignInDialogState extends State<_SsiSignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) return;
    Navigator.of(context).pop((email: email, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.ssiAccount),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(labelText: s.ssiEmail),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              obscureText: _obscured,
              decoration: InputDecoration(
                labelText: s.ssiPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Said here rather than in a help screen: this is the moment
            // someone decides whether to type their password at all.
            Text(s.ssiPasswordNotStored, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.ssiSignIn)),
      ],
    );
  }
}
