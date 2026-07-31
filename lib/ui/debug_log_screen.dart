import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../debug/api_log.dart';

/// Shows recent Garmin API calls so a failure can be diagnosed on the
/// device. Secrets are redacted before entries reach the log, so the text
/// here is safe to copy out and share.
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  @override
  void initState() {
    super.initState();
    ApiLog.instance.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    ApiLog.instance.removeListener(_onLogChanged);
    super.dispose();
  }

  void _onLogChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _copyAll() async {
    final text = ApiLog.instance.allAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log in die Zwischenablage kopiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = ApiLog.instance;
    final entries = log.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API-Protokoll'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Alles kopieren',
            onPressed: entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Log leeren',
            onPressed: entries.isEmpty ? null : log.clear,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Aufzeichnung aktiv'),
            subtitle: const Text(
              'Zeichnet Garmin-API-Aufrufe auf und zeigt Rohdaten bei Fehlern. '
              'Passwörter und Tokens werden dabei unkenntlich gemacht.',
            ),
            value: log.enabled,
            onChanged: log.setEnabled,
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('Noch keine Aufrufe aufgezeichnet.'))
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _LogTile(entry: entries[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final ApiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isFailure
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return ExpansionTile(
      leading: Text(
        '${entry.statusCode ?? '!'}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      title: Text(
        entry.url,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${entry.method} · ${entry.timestamp.toIso8601String().substring(11, 19)}',
        style: const TextStyle(fontSize: 11),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SelectableText(
            entry.toText(),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
