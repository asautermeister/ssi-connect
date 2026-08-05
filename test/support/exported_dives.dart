import 'package:provider/provider.dart';
import 'package:ssi_connect/dives/exported_dives_controller.dart';
import 'package:ssi_connect/dives/exported_dives_repository.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
///
/// Shared rather than copied into every screen test: the "carried over into
/// SSI" tick shows up in the dive list, on both QR screens and on the start
/// screen, so five test files would otherwise hold the same five lines.
class InMemoryExportedDives extends ExportedDivesRepository {
  InMemoryExportedDives([this.stored = const {}]);

  Set<String> stored;

  @override
  Future<Set<String>> load() async => stored;

  @override
  Future<void> save(Set<String> diveIds) async => stored = diveIds;
}

/// A controller with nothing ticked, ready to drop into a provider tree.
ChangeNotifierProvider<ExportedDivesController> exportedDivesProvider([
  Set<String> exported = const {},
]) => ChangeNotifierProvider(
  create: (_) =>
      ExportedDivesController(repository: InMemoryExportedDives(exported))
        ..loadFromStorage(),
);
