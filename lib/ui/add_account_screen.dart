import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../garmin/models/garmin_session.dart';

/// Single screen covering the whole "add a Garmin account" flow: credentials
/// first, then - only if Garmin asks for it - an MFA code field. Kept as one
/// screen rather than a separate MFA route since it's really one flow with
/// an optional extra step, not two independent destinations.
///
/// With [reconnect] set it signs an account that already exists back in.
/// Same flow, same two steps, one different ending: the session lands on
/// that account instead of creating a new one, so its colour, its SSI
/// identity and its cached dives survive. That matters because Garmin's
/// refresh token expires on a timescale nobody documents, and before this
/// the only way out was to delete the account and set it up from scratch.
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key, this.reconnect});

  /// The account to sign in again, or null to add a new one.
  final GarminAccount? reconnect;

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

enum _Step { credentials, mfa }

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _nameController = TextEditingController();
  late final _emailController = TextEditingController(
    // Signing in again is only ever this one account: a different address
    // would put a stranger's session on this person's entry.
    text: widget.reconnect?.email ?? '',
  );
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();

  bool get _isReconnect => widget.reconnect != null;

  _Step _step = _Step.credentials;
  GarminMfaContext? _mfaContext;
  bool _busy = false;
  String? _error;
  String? _errorDetails;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    setState(() {
      _busy = true;
      _error = null;
      _errorDetails = null;
    });
    final controller = context.read<AccountsController>();
    try {
      final result = await controller.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      switch (result) {
        case GarminLoginSuccess(:final session):
          await _store(session);
        case GarminLoginMfaRequired(:final mfaContext):
          setState(() {
            _mfaContext = mfaContext;
            _step = _Step.mfa;
          });
      }
    } on GarminAuthException catch (e) {
      setState(() {
        _error = e.message;
        _errorDetails = e.details;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The one place a finished login is stored, whichever step produced it.
  Future<void> _store(GarminSession session) async {
    final controller = context.read<AccountsController>();
    final existing = widget.reconnect;
    if (existing != null) {
      await controller.reconnect(accountId: existing.id, session: session);
    } else {
      await controller.addAccountFromSuccess(
        email: _emailController.text.trim(),
        session: session,
        displayName: _nameController.text,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submitMfa() async {
    final mfaContext = _mfaContext;
    if (mfaContext == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorDetails = null;
    });
    final controller = context.read<AccountsController>();
    try {
      final session = await controller.completeMfa(
        context: mfaContext,
        code: _mfaController.text.trim(),
      );
      await _store(session);
    } on GarminAuthException catch (e) {
      setState(() {
        _error = e.message;
        _errorDetails = e.details;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReconnect ? s.signInAgain : s.addGarminAccount),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step == _Step.credentials) ..._credentialsFields(s),
              if (_step == _Step.mfa) ..._mfaFields(s),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_errorDetails != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _errorDetails!,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy
                    ? null
                    : (_step == _Step.credentials
                          ? _submitCredentials
                          : _submitMfa),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_step == _Step.credentials ? s.signIn : s.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _credentialsFields(AppStrings s) => [
    // Signing in again keeps the name it already has, and the address is
    // not a choice - it is which account this is.
    if (!_isReconnect) ...[
      TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: s.name,
          helperText: s.nameOptionalHint,
        ),
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 12),
    ],
    TextField(
      controller: _emailController,
      readOnly: _isReconnect,
      decoration: InputDecoration(labelText: s.garminEmail),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _passwordController,
      decoration: InputDecoration(labelText: s.garminPassword),
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _submitCredentials(),
    ),
  ];

  List<Widget> _mfaFields(AppStrings s) => [
    Text(s.mfaRequested(_mfaContext?.mfaMethod ?? 'email')),
    const SizedBox(height: 12),
    TextField(
      controller: _mfaController,
      decoration: InputDecoration(labelText: s.code),
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _submitMfa(),
    ),
  ];
}
