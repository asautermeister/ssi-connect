import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../garmin/garmin_auth_client.dart';
import '../garmin/models/garmin_session.dart';
import '../ssi/ssi_buddy_code.dart';
import 'account_repository.dart';
import 'models/account_color.dart';
import 'models/garmin_account.dart';

/// App-wide state for the logged-in Garmin accounts: loads them from secure
/// storage on startup, drives the add-account (login + MFA) flow, and hands
/// out a valid session (refreshing it first if needed) to callers that want
/// to fetch dives for a given account.
class AccountsController extends ChangeNotifier {
  AccountsController({
    AccountRepository? repository,
    GarminAuthClient? authClient,
  }) : _repository = repository ?? AccountRepository(),
       _authClient = authClient ?? GarminAuthClient();

  final AccountRepository _repository;
  final GarminAuthClient _authClient;
  final _uuid = const Uuid();

  List<GarminAccount> _accounts = [];
  List<GarminAccount> get accounts => List.unmodifiable(_accounts);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _accounts = await _repository.loadAll();
    _loaded = true;
    notifyListeners();
  }

  /// Starts a login. Returns a [GarminLoginMfaRequired] if the account needs
  /// an MFA code - the caller should show a code field and call
  /// [completeMfaAndAddAccount] with the result.
  Future<GarminLoginResult> login({
    required String email,
    required String password,
  }) {
    return _authClient.login(email: email, password: password);
  }

  Future<GarminAccount> completeMfaAndAddAccount({
    required String email,
    required GarminMfaContext context,
    required String code,
    String? displayName,
  }) async {
    final session = await _authClient.completeMfa(context: context, code: code);
    return _addAccount(
      email: email,
      session: session,
      displayName: displayName,
    );
  }

  Future<GarminAccount> addAccountFromSuccess({
    required String email,
    required GarminSession session,
    String? displayName,
  }) {
    return _addAccount(
      email: email,
      session: session,
      displayName: displayName,
    );
  }

  /// [displayName] is what the family calls this person. Falls back to the
  /// mail address, which is at least unique - but "Marie" reads better on a
  /// shared tablet than "marie.mustermann.1987@example.com".
  Future<GarminAccount> _addAccount({
    required String email,
    required GarminSession session,
    String? displayName,
  }) async {
    final name = displayName?.trim();
    final account = GarminAccount(
      id: _uuid.v4(),
      email: email,
      displayName: (name == null || name.isEmpty) ? email : name,
      session: session,
    );
    _accounts = [..._accounts, account];
    await _repository.save(account);
    notifyListeners();
    return account;
  }

  Future<void> removeAccount(String accountId) async {
    _accounts = _accounts.where((a) => a.id != accountId).toList();
    await _repository.remove(accountId);
    notifyListeners();
  }

  /// Returns a session that should still be valid, refreshing and
  /// persisting a new access token first if [GarminAuthClient.refresh]
  /// succeeds. Throws [GarminAuthException] if refreshing fails - callers
  /// should send the user back through [login] in that case.
  Future<GarminSession> ensureFreshSession(GarminAccount account) async {
    final refreshed = await _authClient.refresh(account.session);
    final updated = account.copyWith(session: refreshed);
    _accounts = [
      for (final a in _accounts)
        if (a.id == account.id) updated else a,
    ];
    await _repository.save(updated);
    notifyListeners();
    return refreshed;
  }

  /// Renames an account. An empty name falls back to the mail address
  /// rather than leaving a nameless card on the start screen.
  Future<void> rename(String accountId, String displayName) async {
    final name = displayName.trim();
    await _updateAccount(
      accountId,
      (account) =>
          account.copyWith(displayName: name.isEmpty ? account.email : name),
    );
  }

  /// Sets or clears the colour marking this person's dives.
  Future<void> setColor(String accountId, AccountColor? color) =>
      _updateAccount(accountId, (account) => account.withColor(color));

  /// Stores the SSI identity read from a scanned member QR code.
  Future<void> setSsiIdentity(String accountId, SsiBuddyCode code) async {
    await _updateAccount(
      accountId,
      (account) => account.copyWith(
        ssiMemberId: code.memberId,
        ssiFirstName: code.firstName,
        ssiLastName: code.lastName,
        ssiEmail: code.email,
      ),
    );
  }

  Future<void> clearSsiIdentity(String accountId) async {
    await _updateAccount(accountId, (account) => account.withoutSsiIdentity());
  }

  Future<void> _updateAccount(
    String accountId,
    GarminAccount Function(GarminAccount) change,
  ) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    final updated = change(_accounts[index]);
    _accounts = [..._accounts]..[index] = updated;
    await _repository.save(updated);
    notifyListeners();
  }
}
