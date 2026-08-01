import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ui/qr_display_screen.dart';
import 'package:ssi_connect/ui/ssi_buddies_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

class _InMemoryBuddies extends SsiBuddyRepository {
  _InMemoryBuddies(this.stored);

  List<SsiBuddyCode> stored;

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

Future<SsiBuddiesController> _pump(
  WidgetTester tester,
  List<SsiBuddyCode> buddies,
) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = SsiBuddiesController(
    repository: _InMemoryBuddies(buddies),
  );
  await controller.loadFromStorage();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SsiBuddiesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('SsiBuddiesScreen', () {
    testWidgets('tapping a buddy shows their code for someone else to scan', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(
          memberId: '3902893',
          firstName: 'Andreas',
          lastName: 'Sautermeister',
        ),
      ]);

      await tester.tap(find.text('Andreas Sautermeister'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      // The payload has to be what SSI itself shows, or another app can't
      // read it back.
      expect(
        screen.payload,
        'buddy;3902893;firstName:Andreas;lastName:Sautermeister',
      );
      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
    });

    testWidgets('the code is also reachable from the options menu', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(memberId: '99', firstName: 'Cem'),
      ]);

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Als QR-Code zeigen'));
      await tester.pumpAndSettle();

      expect(find.byType(QrDisplayScreen), findsOneWidget);
    });

    testWidgets('a scanned code and a shown code are the same string', (
      tester,
    ) async {
      const original = 'buddy;7;firstName:Ada;lastName:L;email:ada@example.com';
      final parsed = SsiBuddyCode.tryParse(original)!;

      await _pump(tester, [parsed]);
      await tester.tap(find.text('Ada L'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      // Round trip: scanning this app's own output has to give the same
      // member back.
      expect(screen.payload, original);
      expect(SsiBuddyCode.tryParse(screen.payload)!.memberId, '7');
    });
  });
}
