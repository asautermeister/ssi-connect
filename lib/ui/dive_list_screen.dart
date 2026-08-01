import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../dives/dive_loader.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import 'debug_log_screen.dart';
import 'dive_list_tile.dart';
import 'fit_import_flow.dart';
import 'theme/app_theme.dart';
import 'widgets/error_state.dart';

class DiveListScreen extends StatefulWidget {
  const DiveListScreen({super.key, required this.account});

  final GarminAccount account;

  @override
  State<DiveListScreen> createState() => _DiveListScreenState();
}

class _DiveListScreenState extends State<DiveListScreen> {
  late final GarminDiveLoader _loader = GarminDiveLoader(
    refreshSession: (account) =>
        context.read<AccountsController>().ensureFreshSession(account),
  );

  late Future<List<Dive>> _divesFuture = _loader.load(widget.account);

  void _retry() {
    setState(() {
      _divesFuture = _loader.load(widget.account);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'API-Protokoll',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebugLogScreen())),
          ),
        ],
      ),
      body: FutureBuilder<List<Dive>>(
        future: _divesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is GarminAuthException
                  ? error.message
                  : 'Tauchgänge konnten nicht geladen werden.',
              details: error is GarminAuthException ? error.details : null,
              onRetry: _retry,
              secondaryLabel: 'Stattdessen FIT-Datei importieren',
              onSecondary: () => pickAndImportFitFile(context),
            );
          }
          final dives = snapshot.data ?? const <Dive>[];
          if (dives.isEmpty) {
            return const ErrorState(
              icon: Icons.scuba_diving_outlined,
              message: 'Keine Tauchgänge gefunden.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: DiveList(dives: dives, diver: widget.account.ssiIdentity),
          );
        },
      ),
    );
  }
}

/// Shared list body, so Garmin-loaded and FIT-imported dives render
/// identically. Computes the shared depth scale the cards' meters use.
class DiveList extends StatelessWidget {
  const DiveList({super.key, required this.dives, this.diver});

  final List<Dive> dives;

  /// SSI member these dives belong to, passed down so the generated QR
  /// code can name them. Null for FIT imports, which carry no account.
  final SsiBuddyCode? diver;

  @override
  Widget build(BuildContext context) {
    final maxDepth = dives
        .map((d) => d.maxDepthMeters ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: dives.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => DiveListTile(
        dive: dives[index],
        maxDepthInList: maxDepth,
        diver: diver,
      ),
    );
  }
}
