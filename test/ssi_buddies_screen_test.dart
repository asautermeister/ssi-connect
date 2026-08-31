import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:ssi_connect/accounts/account_repository.dart';
import 'package:ssi_connect/accounts/accounts_controller.dart';
import 'package:ssi_connect/accounts/models/garmin_account.dart';
import 'package:ssi_connect/garmin/models/garmin_session.dart';
import 'package:ssi_connect/ssi/dive_site.dart';
import 'package:ssi_connect/ssi/dive_site_repository.dart';
import 'package:ssi_connect/ssi/dive_sites_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddies_controller.dart';
import 'package:ssi_connect/ssi/ssi_sync_controller.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_repository.dart';
import 'package:ssi_connect/ssi/ssi_center_code.dart';
import 'package:ssi_connect/ssi/ssi_center_repository.dart';
import 'package:ssi_connect/ssi/ssi_centers_controller.dart';
import 'package:ssi_connect/ui/qr_display_screen.dart';
import 'package:ssi_connect/ui/ssi_buddies_screen.dart';
import 'package:ssi_connect/ui/theme/app_theme.dart';

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

GarminAccount _account(String name, {String? ssiMemberId}) => GarminAccount(
  id: name,
  email: '$name@example.com',
  displayName: name,
  session: const GarminSession(
    accessToken: 'a',
    refreshToken: 'r',
    diClientId: 'c',
  ),
  ssiMemberId: ssiMemberId,
);

class _InMemoryBuddies extends SsiBuddyRepository {
  _InMemoryBuddies(this.stored);

  List<SsiBuddyCode> stored;

  @override
  Future<List<SsiBuddyCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiBuddyCode> buddies) async => stored = buddies;
}

class _InMemoryCenters extends SsiCenterRepository {
  _InMemoryCenters(this.stored);

  List<SsiCenterCode> stored;

  @override
  Future<List<SsiCenterCode>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<SsiCenterCode> centers) async => stored = centers;
}

Future<SsiBuddiesController> _pump(
  WidgetTester tester,
  List<SsiBuddyCode> buddies, {
  List<GarminAccount> accounts = const [],
  List<SsiCenterCode> centers = const [],
  List<DiveSite> sites = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = SsiBuddiesController(
    repository: _InMemoryBuddies(buddies),
  );
  final centersController = SsiCentersController(
    repository: _InMemoryCenters(centers),
  );
  final accountsController = AccountsController(
    repository: _InMemoryAccounts(accounts),
  );
  await controller.loadFromStorage();
  await centersController.loadFromStorage();
  await accountsController.loadFromStorage();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: centersController),
        ChangeNotifierProvider.value(value: accountsController),
        // The screen now also lists the dive sites the logbooks brought,
        // and says so when a logbook could not be read.
        ChangeNotifierProvider(
          create: (_) =>
              DiveSitesController(repository: _StoredSites(sites))
                ..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => SsiSyncController()),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        theme: AppTheme.light(),
        home: const SsiBuddiesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _StoredSites extends DiveSiteRepository {
  _StoredSites(this.stored);

  final List<DiveSite> stored;

  @override
  Future<List<DiveSite>> loadAll() async => stored;

  @override
  Future<void> saveAll(List<DiveSite> sites) async {}
}

DiveSite _site(
  String name, {
  String id = '1',
  String? region,
  double latitude = 36.0,
  double longitude = 14.0,
}) => DiveSite(
  siteId: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
  region: region,
);

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

    testWidgets('a contact row is one target, its options are on the code', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(memberId: '99', firstName: 'Cem'),
      ]);

      // Nothing on the row competes with "show me the code".
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);

      await tester.tap(find.text('Cem'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(find.text('Entfernen'), findsOneWidget);
    });

    testWidgets('editing from the code page redraws the code', (tester) async {
      // The code on screen is the thing being scanned - a correction made
      // behind it must not leave the old one standing.
      await _pump(tester, [
        const SsiBuddyCode(memberId: '99', firstName: 'Cem'),
      ]);

      await tester.tap(find.text('Cem'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nachname'), 'Yil');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      expect(screen.payload, 'buddy;99;firstName:Cem;lastName:Yil');
    });

    testWidgets('removing from the code page leaves no code behind', (
      tester,
    ) async {
      await _pump(tester, [
        const SsiBuddyCode(memberId: '99', firstName: 'Cem'),
      ]);

      await tester.tap(find.text('Cem'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();

      // Back on the list, and the buddy is gone from it.
      expect(find.byType(QrDisplayScreen), findsNothing);
      expect(find.text('Cem'), findsNothing);
    });

    testWidgets('lists accounts that have an SSI number', (tester) async {
      await _pump(
        tester,
        [const SsiBuddyCode(memberId: '99', firstName: 'Cem')],
        accounts: [
          _account('Andreas', ssiMemberId: '3902893'),
          // No SSI number: nothing to show as a code, so not listed.
          _account('Jonas'),
        ],
      );

      expect(find.text('Aus den Accounts'), findsOneWidget);
      expect(find.text('Andreas'), findsOneWidget);
      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
      expect(find.text('Jonas'), findsNothing);
      // The scanned buddy keeps its own section.
      expect(find.text('Zusätzlich gespeichert'), findsOneWidget);
      expect(find.text('Cem'), findsOneWidget);
    });

    testWidgets('an account can be shown as a code too', (tester) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      await tester.tap(find.text('Andreas'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      expect(screen.payload, startsWith('buddy;3902893'));
    });

    testWidgets('an account row offers no edit or delete', (tester) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      expect(find.text('GARMIN-ACCOUNT'), findsOneWidget);

      await tester.tap(find.text('Andreas'));
      await tester.pumpAndSettle();

      // Its number belongs to the account screen; a delete here would be
      // ambiguous about what it deletes.
      expect(find.byType(QrDisplayScreen), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('someone with an account and a scan is listed once', (
      tester,
    ) async {
      await _pump(
        tester,
        [const SsiBuddyCode(memberId: '3902893', firstName: 'Andreas')],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );

      expect(find.text('SSI-Nr. 3902893'), findsOneWidget);
      expect(find.text('Zusätzlich gespeichert'), findsNothing);
    });

    testWidgets('the empty state waits until every list is empty', (
      tester,
    ) async {
      await _pump(
        tester,
        const [],
        accounts: [_account('Andreas', ssiMemberId: '3902893')],
      );
      expect(find.text('Noch keine Buddies gespeichert'), findsNothing);

      // A saved base alone is enough to have something to show.
      await _pump(
        tester,
        const [],
        centers: const [SsiCenterCode(centerId: '718019', name: 'Nero-Sport')],
      );
      expect(find.text('Noch keine Buddies gespeichert'), findsNothing);

      await _pump(tester, const [], accounts: [_account('Jonas')]);
      expect(find.text('Noch keine Buddies gespeichert'), findsOneWidget);
    });

    testWidgets('dive centres get their own section', (tester) async {
      await _pump(
        tester,
        [const SsiBuddyCode(memberId: '99', firstName: 'Cem')],
        centers: const [
          SsiCenterCode(
            centerId: '718019',
            name: 'Nero-Sport Diving Center, Zakynthos',
          ),
        ],
      );

      expect(find.text('Tauchbasen'), findsOneWidget);
      expect(find.text('Nero-Sport Diving Center, Zakynthos'), findsOneWidget);
      expect(find.text('Basis-Nr. 718019'), findsOneWidget);
      // The buddy keeps its own section rather than being folded in.
      expect(find.text('Cem'), findsOneWidget);
    });

    testWidgets('tapping a centre shows its code for someone else to scan', (
      tester,
    ) async {
      await _pump(
        tester,
        const [],
        centers: const [
          SsiCenterCode(
            centerId: '718019',
            name: 'Nero-Sport Diving Center, Zakynthos',
          ),
        ],
      );

      await tester.tap(find.text('Nero-Sport Diving Center, Zakynthos'));
      await tester.pumpAndSettle();

      final screen = tester.widget<QrDisplayScreen>(
        find.byType(QrDisplayScreen),
      );
      // Byte for byte what SSI itself shows, comma in the name included.
      expect(
        screen.payload,
        'center;718019;name:Nero-Sport Diving Center, Zakynthos',
      );
    });

    testWidgets('a centre can be removed from its code page', (tester) async {
      await _pump(
        tester,
        const [],
        centers: const [SsiCenterCode(centerId: '718019', name: 'Nero-Sport')],
      );

      await tester.tap(find.text('Nero-Sport'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();

      expect(find.text('Nero-Sport'), findsNothing);
      expect(find.text('Noch keine Buddies gespeichert'), findsOneWidget);
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

    testWidgets('lists the dive sites, ten of them to begin with', (
      tester,
    ) async {
      // A well-travelled logbook brings hundreds. Enough to see they are
      // there, the rest on request.
      await _pump(
        tester,
        const [],
        // Zero-padded: the list is sorted by name, and "Platz 10" would
        // otherwise sort before "Platz 2".
        sites: [
          for (var i = 0; i < 14; i++)
            _site('Platz ${i.toString().padLeft(2, '0')}', id: '$i'),
        ],
      );

      expect(find.text('Tauchplätze'), findsOneWidget);
      expect(find.text('Platz 00'), findsOneWidget);

      // Scrolled to the foot of the list: the tenth site is the last one
      // there, and the eleventh was never handed to the list at all. (A
      // list only builds what is near the viewport, so absence is only
      // evidence once the bottom is on screen.)
      // The search field holds a scrollable of its own, so the list has to
      // be named rather than found by type.
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Mehr anzeigen'),
        300,
        scrollable: list,
      );
      expect(find.text('Platz 09'), findsOneWidget);
      expect(find.text('Platz 10'), findsNothing);

      await tester.tap(find.text('Mehr anzeigen'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Platz 13'),
        300,
        scrollable: list,
      );

      expect(find.text('Platz 13'), findsOneWidget);
      expect(find.text('Mehr anzeigen'), findsNothing);
    });

    testWidgets('sites are grouped by the region SSI files them under', (
      tester,
    ) async {
      await _pump(
        tester,
        const [],
        sites: [
          _site('Ras il-Hobz', id: '1', region: 'Gozo'),
          _site('Blue Hole', id: '2', region: 'Gozo'),
          _site('Hausriff', id: '3'),
          _site('Cirkewwa', id: '4', region: 'Malta'),
        ],
      );

      // Regions alphabetically, and the ones SSI has no region for last -
      // folded into the group above they would look like they belonged.
      final headings = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == 'Gozo' || t == 'Malta' || t == 'Ohne Region')
          .toList();
      expect(headings, ['Gozo', 'Malta', 'Ohne Region']);
    });

    testWidgets('a site carries its position under its name', (tester) async {
      await _pump(
        tester,
        const [],
        sites: [_site('Ras il-Hobz', latitude: 36.0166, longitude: 14.2798)],
      );

      // Four places and dots, so it can be pasted into a map, with the
      // hemisphere spelling out the sign.
      expect(find.text('36.0166 N, 14.2798 E'), findsOneWidget);
    });

    testWidgets('the search reaches a region name too', (tester) async {
      // It is on screen as a heading, so typing it has to work - the same
      // rule the rest of this screen follows.
      await _pump(
        tester,
        [
          for (var i = 0; i < 8; i++)
            SsiBuddyCode(memberId: '$i', firstName: 'Marco', lastName: '$i'),
        ],
        sites: [
          _site('Ras il-Hobz', id: '1', region: 'Gozo'),
          _site('Cirkewwa', id: '2', region: 'Malta'),
        ],
      );

      await tester.enterText(find.byType(TextField), 'gozo');
      await tester.pumpAndSettle();

      expect(find.text('Ras il-Hobz'), findsOneWidget);
      expect(find.text('Cirkewwa'), findsNothing);
    });

    testWidgets('one search field narrows every section at once', (
      tester,
    ) async {
      // Typing "Ras" one does not know whether it is a place, a centre or a
      // surname - so one field, not one per section.
      await _pump(
        tester,
        [
          for (var i = 0; i < 8; i++)
            SsiBuddyCode(memberId: '$i', firstName: 'Marco', lastName: '$i'),
        ],
        sites: [
          _site('Ras il-Hobz'),
          _site('Xatt l-Ahmar', id: '2'),
        ],
      );

      await tester.enterText(find.byType(TextField), 'ras');
      await tester.pumpAndSettle();

      expect(find.text('Ras il-Hobz'), findsOneWidget);
      expect(find.text('Xatt l-Ahmar'), findsNothing);
      // The buddies section is gone rather than standing there empty.
      expect(find.text('Gespeichert'), findsNothing);
      // And the heading says how much of the section survived, so a
      // narrowed list is not mistaken for a short one.
      expect(find.text('1 von 2'), findsOneWidget);
    });

    testWidgets('a logbook that could not be read says so', (tester) async {
      // The expired-token case: the session is dropped and the logbook
      // forgotten, so green ticks disappear - now behind an ordinary
      // pull-to-refresh, where nothing else would mention it.
      await _pump(tester, const [], sites: [_site('Ras il-Hobz')]);

      expect(find.textContaining('SSI-Abgleich'), findsNothing);
      expect(find.text('Erneut anmelden'), findsNothing);
    });
  });
}
