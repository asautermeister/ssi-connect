import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'accounts/accounts_controller.dart';
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
        // Session-only: dives are never written to storage, so this starts
        // empty on every launch and the start screen fetches again.
        ChangeNotifierProvider(create: (_) => RecentDivesController()),
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
