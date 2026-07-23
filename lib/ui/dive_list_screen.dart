import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accounts/accounts_controller.dart';
import '../accounts/models/garmin_account.dart';
import '../garmin/garmin_activity_client.dart';
import '../garmin/garmin_auth_exceptions.dart';
import '../models/dive.dart';
import 'dive_detail_screen.dart';

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
            final message = snapshot.error is GarminAuthException
                ? (snapshot.error as GarminAuthException).message
                : 'Tauchgänge konnten nicht geladen werden.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Erneut versuchen'),
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
              itemBuilder: (context, index) {
                final dive = dives[index];
                return ListTile(
                  title: Text(_formatDate(dive.dateTime)),
                  subtitle: Text('Tauchgang ${dive.diveNumberOfDay} des Tages'),
                  trailing: Text(
                    dive.maxDepthMeters != null
                        ? '${dive.maxDepthMeters!.toStringAsFixed(1)} m'
                        : '–',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiveDetailScreen(dive: dive),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final d = dateTime;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
