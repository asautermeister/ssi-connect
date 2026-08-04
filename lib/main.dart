import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'accounts/accounts_controller.dart';
import 'dives/dive_loader.dart';
import 'l10n/app_strings.dart';
import 'dives/recent_dives_controller.dart';
import 'settings/settings_controller.dart';
import 'ssi/dive_sites_controller.dart';
import 'ssi/ssi_account_controller.dart';
import 'ssi/ssi_buddies_controller.dart';
import 'ssi/ssi_centers_controller.dart';
import 'ui/accounts_screen.dart';
import 'ui/developer_mode.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const SsiConnectApp());
}

class SsiConnectApp extends StatelessWidget {
  const SsiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccountsController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => SsiBuddiesController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => SsiCentersController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => DiveSitesController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => SsiAccountController()..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => RecentDivesController()),
        // Session-only: the diagnostic tools stay hidden until someone
        // taps the version in the info screen, and a restart hides them
        // again.
        ChangeNotifierProvider(create: (_) => DeveloperMode()),
        // The one way dives are fetched, shared by every screen that shows
        // them. Provided rather than constructed per screen so there is a
        // single place that knows how a session gets refreshed.
        Provider<DiveFetcher>(
          create: (context) => GarminDiveLoader(
            refreshSession: (account) =>
                context.read<AccountsController>().ensureFreshSession(account),
          ).load,
        ),
      ],
      // Rebuilt when the theme preference changes. Only this one is watched
      // here - the rest of the app reads its controllers where it needs
      // them, and rebuilding the whole tree for a dive list would be waste.
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'SSI Connect',
          // Flutters schräges DEBUG-Band oben rechts. Es erscheint ohnehin
          // nur in Debug-Builds, aber getestet wird hier auf echten Geräten
          // mit echten Tauchgängen - da ist es kein Hinweis mehr, sondern
          // steht dem QR-Code und der Tauchgangsliste im Weg.
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          // null lets Flutter resolve the device language against
          // supportedLocales, which is what "follow the device" means.
          locale: settings.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AccountsScreen(),
        ),
      ),
    );
  }
}
