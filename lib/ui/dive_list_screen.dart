import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_activity_client.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../models/dive.dart';
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
  final _activityClient = GarminActivityClient();

  late Future<List<Dive>> _divesFuture;

  @override
  void initState() {
    super.initState();
    _divesFuture = _loadDives();
  }

  Future<List<Dive>> _loadDives({bool forceRefreshSession = false}) async {
    final controller = context.read<AccountsController>();
    var session = widget.account.session;
    if (forceRefreshSession) {
      session = await controller.ensureFreshSession(widget.account);
    }

    try {
      final activities = await _activityClient.getDiveActivities(session);
      final dives = activities
          .map(Dive.fromGarminActivity)
          .whereType<Dive>()
          .toList();
      return assignDiveNumbersOfDay(dives);
    } on GarminAuthException catch (e) {
      if (e.type == GarminAuthErrorType.invalidCredentials &&
          !forceRefreshSession) {
        return _loadDives(forceRefreshSession: true);
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _divesFuture = _loadDives();
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
            child: DiveList(dives: dives),
          );
        },
      ),
    );
  }
}

/// Shared list body, so Garmin-loaded and FIT-imported dives render
/// identically. Computes the shared depth scale the cards' meters use.
class DiveList extends StatelessWidget {
  const DiveList({super.key, required this.dives});

  final List<Dive> dives;

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
      itemBuilder: (context, index) =>
          DiveListTile(dive: dives[index], maxDepthInList: maxDepth),
    );
  }
}
