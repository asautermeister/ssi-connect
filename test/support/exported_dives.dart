import 'package:provider/provider.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/dives/exported_dives_repository.dart';
import 'package:ssi_connect/ssi/ssi_logged_dive.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
///
/// Shared rather than copied into every screen test: the "carried over into
/// SSI" tick shows up in the dive list, on both QR screens and on the start
/// screen, so five test files would otherwise hold the same few lines.
class InMemoryExportedDives extends ExportedDivesRepository {
  InMemoryExportedDives([this.stored = const {}, this.logbooks = const {}]);

  Map<String, bool> stored;
  Map<String, List<SsiLoggedDive>> logbooks;

  @override
  Future<Map<String, bool>> loadMarks() async => stored;

  @override
  Future<void> saveMarks(Map<String, bool> marks) async => stored = marks;

  @override
  Future<Map<String, List<SsiLoggedDive>>> loadLogbooks() async => logbooks;

  @override
  Future<void> saveLogbooks(Map<String, List<SsiLoggedDive>> value) async =>
      logbooks = value;
}

/// A controller with nothing ticked, ready to drop into a provider tree.
ChangeNotifierProvider<ExportedDivesController> exportedDivesProvider([
  Map<String, bool> marks = const {},
]) => ChangeNotifierProvider(
  create: (_) =>
      ExportedDivesController(repository: InMemoryExportedDives(marks))
        ..loadFromStorage(),
);
