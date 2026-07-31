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
      appBar: AppBar(title: Text(widget.account.displayName)),
      body: FutureBuilder<List<Dive>>(
        future: _divesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is GarminAuthException
                ? error.message
                : 'Tauchgänge konnten nicht geladen werden.';
            final details = error is GarminAuthException ? error.details : null;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    if (details != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        details,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Erneut versuchen'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => pickAndImportFitFile(context),
                      child: const Text('Stattdessen FIT-Datei importieren'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('API-Protokoll öffnen'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DebugLogScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final dives = snapshot.data ?? const [];
          if (dives.isEmpty) {
            return const Center(child: Text('Keine Tauchgänge gefunden.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView.separated(
              itemCount: dives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => DiveListTile(dive: dives[index]),
            ),
          );
        },
      ),
    );
  }
}
