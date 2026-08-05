import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'theme/app_theme.dart';

/// Asks for SSI credentials, and returns them without keeping a copy.
///
/// The password goes straight to the login call and is forgotten; only the
/// token SSI answers with is ever stored. Said in the dialog itself,
/// because this is the moment someone decides whether to type it at all.
class SsiSignInDialog extends StatefulWidget {
  const SsiSignInDialog({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<SsiSignInDialog> createState() => _SsiSignInDialogState();
}

class _SsiSignInDialogState extends State<SsiSignInDialog> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
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
