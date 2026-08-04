import 'package:flutter/foundation.dart';

import 'dive_sites_controller.dart';
import 'ssi_api_client.dart';
import 'ssi_api_exceptions.dart';
import 'ssi_account_repository.dart';
import 'ssi_session.dart';

/// The connected SSI account, and the one thing it is used for: pulling the
/// dive sites out of the user's own SSI logbook.
class SsiAccountController extends ChangeNotifier {
  SsiAccountController({SsiAccountRepository? repository, SsiApiClient? client})
    : _repository = repository ?? SsiAccountRepository(),
      _client = client ?? SsiApiClient();

  final SsiAccountRepository _repository;
  final SsiApiClient _client;

  SsiSession? _session;
  SsiSession? get session => _session;
  bool get isConnected => _session != null;

  bool _busy = false;
  bool get isBusy => _busy;

  /// The last failure, kept so a screen can show it after the spinner is
  /// gone. Cleared whenever a new attempt starts.
  String? _error;
  String? get error => _error;

  /// How the last sync went: how many sites SSI knows about, and how many
  /// of them were new to this device.
  int? _lastSiteCount;
  int? get lastSiteCount => _lastSiteCount;

  int? _lastAddedCount;
  int? get lastAddedCount => _lastAddedCount;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> loadFromStorage() async {
    _session = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  /// Logs in and keeps the token. Returns whether it worked; on failure
  /// [error] says why.
  Future<bool> signIn({required String email, required String password}) async {
    _begin();
    try {
      final session = await _client.authenticate(
        email: email,
        password: password,
      );
      await _repository.save(session);
      _session = session;
      return true;
    } on SsiApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _end();
    }
  }

  /// Pulls the logbook's dive sites and hands the new ones to [sites].
  ///
  /// Additive on purpose: a site this device already knows is left exactly
  /// as it is. The user may have renamed it, and its stored position came
  /// from one of their own dives - which is a better match target than the
  /// centre SSI has on file.
  Future<bool> syncSites(DiveSitesController sites) async {
    final session = _session;
    if (session == null) return false;

    _begin();
    try {
      final imported = await _client.loadLogbookSites(session);
      _lastSiteCount = imported.length;
      _lastAddedCount = await sites.addAllNew(imported);
      return true;
    } on SsiApiException catch (e) {
      _error = e.message;
      // A rejected token is not worth keeping - it would fail the same way
      // every time and the message would never change.
      if (e.type == SsiApiErrorType.invalidCredentials) {
        await _repository.clear();
        _session = null;
      }
      return false;
    } finally {
      _end();
    }
  }

  /// Forgets the account. The imported sites stay - they are the user's
  /// dive sites, not SSI's, and re-typing them is the thing this feature
  /// exists to avoid.
  Future<void> signOut() async {
    await _repository.clear();
    _session = null;
    _error = null;
    _lastSiteCount = null;
    _lastAddedCount = null;
    notifyListeners();
  }

  void _begin() {
    _busy = true;
    _error = null;
    notifyListeners();
  }

  void _end() {
    _busy = false;
    notifyListeners();
  }
}
