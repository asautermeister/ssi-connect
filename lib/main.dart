import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'accounts/accounts_controller.dart';
import 'ui/accounts_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const SsiConnectApp());
}

class SsiConnectApp extends StatelessWidget {
  const SsiConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccountsController()..loadFromStorage(),
      child: MaterialApp(
        title: 'SSI Connect',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AccountsScreen(),
      ),
    );
  }
}
