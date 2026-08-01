import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'accounts/accounts_controller.dart';
import 'dives/dive_loader.dart';
import 'dives/recent_dives_controller.dart';
import 'ssi/ssi_buddies_controller.dart';
import 'ui/accounts_screen.dart';
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
        ChangeNotifierProvider(create: (_) => RecentDivesController()),
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
      child: MaterialApp(
        title: 'SSI Connect',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AccountsScreen(),
      ),
    );
  }
}
