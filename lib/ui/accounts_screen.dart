import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import 'add_account_screen.dart';
import 'dive_list_screen.dart';
import 'fit_import_flow.dart';

/// Start screen: pick which family member's Garmin account to browse dives
/// for, add a new one, or import dives from a manually exported FIT file.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSI Connect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Tauchgänge aus FIT-Datei importieren',
            onPressed: () => pickAndImportFitFile(context),
          ),
        ],
      ),
      body: Consumer<AccountsController>(
        builder: (context, controller, _) {
          if (!controller.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Noch kein Garmin-Account hinzugefügt.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alternativ oben rechts eine FIT-Datei importieren.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: controller.accounts.length,
            itemBuilder: (context, index) {
              final account = controller.accounts[index];
              return _AccountTile(account: account);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddAccountScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Account hinzufügen'),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final GarminAccount account;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(account.displayName),
      subtitle: Text(account.email),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Account entfernen',
        onPressed: () =>
            context.read<AccountsController>().removeAccount(account.id),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DiveListScreen(account: account)),
      ),
    );
  }
}
