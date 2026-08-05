import 'package:flutter/foundation.dart';

import 'exported_dives_repository.dart';

/// Which dives have been carried over into SSI.
///
/// The tick is set by hand, on the QR screen, right after the SSI app has
/// swallowed the code. Nothing infers it from the export itself: showing a
/// QR code is not proof that anyone scanned it, and a tick that appears
/// without the dive having arrived is worse than no tick at all - it is
/// exactly the dive that would then be skipped.
class ExportedDivesController extends ChangeNotifier {
  ExportedDivesController({ExportedDivesRepository? repository})
    : _repository = repository ?? ExportedDivesRepository();

  final ExportedDivesRepository _repository;

  Set<String> _diveIds = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  int get count => _diveIds.length;

  Future<void> loadFromStorage() async {
    _diveIds = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  bool isExported(String diveId) => _diveIds.contains(diveId);

  Future<void> setExported(String diveId, bool exported) async {
    if (exported == _diveIds.contains(diveId)) return;
    _diveIds = {..._diveIds};
    if (exported) {
      _diveIds.add(diveId);
    } else {
      _diveIds.remove(diveId);
    }
    await _repository.save(_diveIds);
    notifyListeners();
  }

  Future<void> toggle(String diveId) =>
      setExported(diveId, !isExported(diveId));
}
