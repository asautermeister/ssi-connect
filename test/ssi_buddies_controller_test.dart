import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';

/// Stands in for the keystore-backed repository, which needs a platform.
class _InMemoryRepository extends SsiBuddyRepository {
  _InMemoryRepository([this.stored = const []]);

  List<SsiBuddyCode> stored;

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

void main() {
  group('SsiBuddiesController', () {
    test('loads saved buddies, sorted by name', () async {
      final controller = SsiBuddiesController(
        repository: _InMemoryRepository([
          const SsiBuddyCode(memberId: '2', firstName: 'Zoe'),
          const SsiBuddyCode(memberId: '1', firstName: 'Ada'),
        ]),
      );

      expect(controller.loaded, isFalse);
      await controller.loadFromStorage();

      expect(controller.loaded, isTrue);
      expect(controller.buddies.map((b) => b.firstName), ['Ada', 'Zoe']);
    });

    test('saves a new buddy through to storage', () async {
      final repository = _InMemoryRepository();
      final controller = SsiBuddiesController(repository: repository);
      await controller.loadFromStorage();

      await controller.save(
        const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas'),
      );

      expect(controller.buddies.single.memberId, '3902893');
      expect(repository.stored.single.memberId, '3902893');
    });

    test('rescanning a member updates them instead of duplicating', () async {
      final controller = SsiBuddiesController(
        repository: _InMemoryRepository([
          const SsiBuddyCode(memberId: '7', firstName: 'Ada'),
        ]),
      );
      await controller.loadFromStorage();

      await controller.save(
        const SsiBuddyCode(memberId: '7', firstName: 'Ada', lastName: 'L.'),
      );

      expect(controller.buddies, hasLength(1));
      expect(controller.buddies.single.lastName, 'L.');
    });

    test('removes a buddy by member number', () async {
      final repository = _InMemoryRepository([
        const SsiBuddyCode(memberId: '1', firstName: 'Ada'),
        const SsiBuddyCode(memberId: '2', firstName: 'Bo'),
      ]);
      final controller = SsiBuddiesController(repository: repository);
      await controller.loadFromStorage();

      await controller.remove('1');

      expect(controller.buddies.map((b) => b.memberId), ['2']);
      expect(repository.stored.map((b) => b.memberId), ['2']);
    });

    test('notifies listeners when the list changes', () async {
      final controller = SsiBuddiesController(
        repository: _InMemoryRepository(),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.loadFromStorage();
      await controller.save(const SsiBuddyCode(memberId: '1'));
      await controller.remove('1');

      expect(notifications, 3);
    });
  });
}
