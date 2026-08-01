import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/models/dive.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ui/qr_screen.dart';

class _InMemoryBuddies extends SsiBuddyRepository {
  _InMemoryBuddies(this.stored);

  List<SsiBuddyCode> stored;

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

class _InMemoryAccounts extends AccountRepository {
  _InMemoryAccounts(this.stored);

  List<GarminAccount> stored;

  @override
  Future<List<GarminAccount>> loadAll() async => stored;

  @override
  Future<void> save(GarminAccount account) async {}

  @override
  Future<void> remove(String accountId) async {}
}

GarminAccount _account({
  required String email,
  String? ssiMemberId,
  String? ssiFirstName,
}) {
  return GarminAccount(
    id: email,
    email: email,
    displayName: email,
    session: const GarminSession(
      accessToken: 'a',
      refreshToken: 'r',
      diClientId: 'c',
    ),
    ssiMemberId: ssiMemberId,
    ssiFirstName: ssiFirstName,
  );
}

final _dive = Dive(
  id: 'a',
  dateTime: DateTime(2025, 11, 7, 10, 50),
  maxDepthMeters: 28,
  avgDepthMeters: null,
  waterTemperatureCelsius: null,
  duration: const Duration(minutes: 54),
  locationName: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<GarminAccount> accounts,
  required List<SsiBuddyCode> buddies,
  SsiBuddyCode? diver,
}) async {
  // Roomy viewport: the QR code alone is 380 logical pixels.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final accountsController = AccountsController(
    repository: _InMemoryAccounts(accounts),
  );
  final buddiesController = SsiBuddiesController(
    repository: _InMemoryBuddies(buddies),
  );
  await accountsController.loadFromStorage();
  await buddiesController.loadFromStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountsController),
        ChangeNotifierProvider.value(value: buddiesController),
      ],
      child: MaterialApp(
        home: QrScreen(dive: _dive, diver: diver),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QrScreen buddy picker', () {
    testWidgets('offers accounts and saved buddies, minus the diver', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: [
          _account(email: 'a@x.de', ssiMemberId: '1', ssiFirstName: 'Andreas'),
          _account(email: 'b@x.de', ssiMemberId: '2', ssiFirstName: 'Bea'),
          // No SSI number: nothing to put in a QR code, so not offered.
          _account(email: 'c@x.de'),
        ],
        buddies: [const SsiBuddyCode(memberId: '3', firstName: 'Cem')],
        diver: const SsiBuddyCode(memberId: '1', firstName: 'Andreas'),
      );

      expect(find.widgetWithText(FilterChip, 'Bea'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Cem'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Andreas'), findsNothing);
      expect(find.text('c@x.de'), findsNothing);
    });

    testWidgets('ticking a buddy lists them for manual entry in SSI', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: const [],
        buddies: [const SsiBuddyCode(memberId: '4711', firstName: 'Bea')],
      );

      expect(find.textContaining('SSI-Nr. 4711'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Bea'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SSI-Nr. 4711'), findsOneWidget);
    });

    testWidgets('unticking a buddy drops them from the list again', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: const [],
        buddies: [const SsiBuddyCode(memberId: '4711', firstName: 'Bea')],
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Bea'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bea'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SSI-Nr. 4711'), findsNothing);
    });

    testWidgets('says so plainly when nobody has an SSI number', (
      tester,
    ) async {
      await _pump(tester, accounts: const [], buddies: const []);

      expect(find.byType(FilterChip), findsNothing);
      expect(find.textContaining('Niemand mit SSI-Nummer'), findsOneWidget);
    });

    testWidgets('says that the selection is not in the QR code yet', (
      tester,
    ) async {
      await _pump(
        tester,
        accounts: const [],
        buddies: [const SsiBuddyCode(memberId: '4711', firstName: 'Bea')],
      );

      // The picker must not imply the buddies travel with the code: until a
      // real SSI export shows how they are encoded, they do not.
      expect(find.textContaining('noch nicht im QR-Code'), findsOneWidget);
    });
  });
}
