import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_center_code.dart';
import 'package:ssi_connect/ssi/ssi_center_repository.dart';
import 'package:ssi_connect/ssi/ssi_centers_controller.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
class _InMemoryRepository extends SsiCenterRepository {
  _InMemoryRepository([this.stored = const []]);

  List<SsiCenterCode> stored;

  @override
  Future<List<SsiCenterCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiCenterCode> centers) async => stored = centers;
}

void main() {
  group('SsiCentersController', () {
    test('loads saved centres, sorted by name', () async {
      final controller = SsiCentersController(
        repository: _InMemoryRepository([
          const SsiCenterCode(centerId: '2', name: 'Zakynthos Divers'),
          const SsiCenterCode(centerId: '1', name: 'Aqua Base'),
        ]),
      );

      expect(controller.loaded, isFalse);
      await controller.loadFromStorage();

      expect(controller.loaded, isTrue);
      expect(controller.centers.map((c) => c.name), [
        'Aqua Base',
        'Zakynthos Divers',
      ]);
    });

    test('saves a new centre through to storage', () async {
      final repository = _InMemoryRepository();
      final controller = SsiCentersController(repository: repository);
      await controller.loadFromStorage();

      await controller.save(
        const SsiCenterCode(centerId: '718019', name: 'Nero-Sport'),
      );

      expect(controller.centers.single.centerId, '718019');
      expect(repository.stored.single.centerId, '718019');
    });

    test('rescanning a centre updates it instead of duplicating', () async {
      final controller = SsiCentersController(
        repository: _InMemoryRepository([
          const SsiCenterCode(centerId: '718019', name: 'Nero Sport'),
        ]),
      );
      await controller.loadFromStorage();

      await controller.save(
        const SsiCenterCode(centerId: '718019', name: 'Nero-Sport Zakynthos'),
      );

      expect(controller.centers, hasLength(1));
      expect(controller.centers.single.name, 'Nero-Sport Zakynthos');
    });

    test('removes a centre by its number', () async {
      final repository = _InMemoryRepository([
        const SsiCenterCode(centerId: '1', name: 'Aqua'),
        const SsiCenterCode(centerId: '2', name: 'Blue'),
      ]);
      final controller = SsiCentersController(repository: repository);
      await controller.loadFromStorage();

      await controller.remove('1');

      expect(controller.centers.map((c) => c.centerId), ['2']);
      expect(repository.stored.map((c) => c.centerId), ['2']);
    });

    test('notifies listeners when the list changes', () async {
      final controller = SsiCentersController(
        repository: _InMemoryRepository(),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.loadFromStorage();
      await controller.save(const SsiCenterCode(centerId: '1'));
      await controller.remove('1');

      expect(notifications, 3);
    });
  });
}
