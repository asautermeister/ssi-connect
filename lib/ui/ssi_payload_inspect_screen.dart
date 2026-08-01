import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ssi/ssi_payload_fields.dart';
import 'ssi_scan_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// Reads any SSI QR code and lists its raw fields.
///
/// This exists because several fields of the dive format are still unknown
/// - which key SSI uses for buddies, what the `var_*` code tables mean.
/// Rather than guessing them (a wrong value lands silently in the logbook),
/// export a dive from the SSI app that already has the thing in question
/// filled in, scan it here, and read the answer off the real payload.
class SsiPayloadInspectScreen extends StatefulWidget {
  const SsiPayloadInspectScreen({super.key});

  @override
  State<SsiPayloadInspectScreen> createState() =>
      _SsiPayloadInspectScreenState();
}

class _SsiPayloadInspectScreenState extends State<SsiPayloadInspectScreen> {
  String? _raw;

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen<String>(
          // Anything scannable is interesting here - the whole point is to
          // see payloads this app cannot interpret yet.
          parse: (value) => value,
          title: 'SSI-Code analysieren',
          hint:
              'Beliebigen SSI-QR-Code scannen – z. B. den Export eines '
              'Tauchgangs, in dem der gesuchte Wert schon eingetragen ist.',
        ),
      ),
    );
    if (raw == null) return;
    setState(() => _raw = raw);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _raw!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payload in die Zwischenablage kopiert')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = _raw;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSI-Code analysieren'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Payload kopieren',
            onPressed: raw == null ? null : _copy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          96,
        ),
        children: [
          Text(
            'Zeigt an, welche Felder ein echter SSI-Code enthält. Damit '
            'lassen sich Felder ermitteln, die SSI Connect noch nicht kennt '
            '– etwa die Buddy-Angabe: in der SSI-App einen Tauchgang mit '
            'Buddy exportieren und den QR-Code hier scannen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(raw == null ? 'QR-Code scannen' : 'Weiteren scannen'),
            onPressed: _scan,
          ),
          if (raw != null) ...[
            const SectionHeader(title: 'Felder'),
            _Fields(payload: SsiPayloadFields.parse(raw)),
            const SectionHeader(title: 'Rohdaten'),
            AppCard(
              child: SelectableText(
                raw,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields({required this.payload});

  final SsiPayloadFields payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            name: 'Typ',
            value: [payload.marker, ...payload.positional].join(' · '),
          ),
          for (final entry in payload.fields.entries)
            _Row(name: entry.key, value: entry.value),
          if (payload.fields.isEmpty)
            Text(
              'Keine key:value-Felder enthalten.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '(leer)' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
