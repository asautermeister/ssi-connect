import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../garmin/garmin_personal_api_client.dart';
import '../l10n/app_strings.dart';
import 'theme/app_theme.dart';

/// Takes a Garmin Personal API key and makes an account out of it, or puts
/// a fresh one on an account that already exists.
///
/// The key is ~130 characters, so nobody types it: the screen leads with
/// what is already in the clipboard, which is where a key lands the moment
/// it is created. The field stays, because a key can also arrive by other
/// means.
///
/// It is never stored on trust. The key is exchanged for a token and the
/// profile behind it is read first, which does two things at once: the
/// account gets its owner's real name, and a key pasted into the wrong
/// person's entry is caught before it starts loading a stranger's dives.
class GarminKeyScreen extends StatefulWidget {
  const GarminKeyScreen({super.key, this.account});

  /// The account to put the key on, or null to make a new one.
  final GarminAccount? account;

  @override
  State<GarminKeyScreen> createState() => _GarminKeyScreenState();
}

class _GarminKeyScreenState extends State<GarminKeyScreen> {
  final _key = TextEditingController();
  final _api = GarminPersonalApiClient();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final key = GarminPersonalKey.tryParse(data?.text ?? '');
    if (!mounted) return;
    setState(() {
      if (key == null) {
        _error = AppStrings.of(context).personalKeyClipboardEmpty;
      } else {
        _key.text = key;
        _error = null;
      }
    });
  }

  Future<void> _submit() async {
    final s = AppStrings.of(context);
    final key = GarminPersonalKey.tryParse(_key.text);
    if (key == null) {
      setState(() => _error = s.personalKeyMalformed);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final accounts = context.read<AccountsController>();
    try {
      final session = await _api.exchange(key);
      final profile = await _api.profile(session);

      final existing = widget.account;
      if (existing != null) {
        // Putting a stranger's key on an existing entry would quietly fill
        // it with their dives. The mail address is the one thing both
        // sides name, so it is what gets compared.
        final theirs = profile.email?.toLowerCase();
        if (theirs != null && theirs != existing.email.toLowerCase()) {
          setState(() {
            _busy = false;
            _error = s.personalKeyWrongAccount;
          });
          return;
        }
        await accounts.reconnect(accountId: existing.id, session: session);
      } else {
        await accounts.addAccountFromSuccess(
          email: profile.email ?? '',
          session: session,
          displayName: profile.displayName,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on GarminAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Scaffold(
      appBar: AppBar(title: Text(s.personalKeyTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.personalKeyIntro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  s.personalKeyHowTo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // The address rather than a link: opening a browser would
                // mean another platform plugin, and this project has been
                // bitten by those twice.
                SelectableText(
                  s.personalKeyUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _key,
                  maxLines: 2,
                  minLines: 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(labelText: s.personalKeyLabel),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text(s.personalKeyPasteFromClipboard),
                    onPressed: _busy ? null : _pasteFromClipboard,
                  ),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.personalKeyCheck),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
