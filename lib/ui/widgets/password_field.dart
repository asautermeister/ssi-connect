import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// A password field with an eye to check what was typed.
///
/// One widget rather than the same `obscureText` plus `suffixIcon` in every
/// login: there are two of them, the Garmin account and the SSI account,
/// and a third would have copied it again.
///
/// Hidden to begin with, and never remembers being shown - revealing is a
/// deliberate act each time. On a tablet handed around a dive boat that
/// matters more than the convenience of staying open.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          // Says what the button does, not what the state is: a screen
          // reader announcing "hidden" would leave it open what pressing
          // it changes.
          tooltip: _obscured ? s.showPassword : s.hidePassword,
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      onSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!(),
    );
  }
}
