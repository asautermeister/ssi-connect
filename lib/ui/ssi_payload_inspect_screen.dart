import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
    final s = AppStrings.of(context);
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen<String>(
          // Anything scannable is interesting here - the whole point is to
          // see payloads this app cannot interpret yet.
          parse: (value) => value,
          title: s.inspectSsiCode,
          hint: s.inspectHint,
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
      SnackBar(content: Text(AppStrings.of(context).payloadCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final raw = _raw;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.inspectSsiCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: s.copyPayload,
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
          Text(s.inspectExplanation, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(raw == null ? s.scanQrCode : s.scanAnother),
            onPressed: _scan,
          ),
          if (raw != null) ...[
            SectionHeader(title: s.fields),
            _Fields(payload: SsiPayloadFields.parse(raw)),
            SectionHeader(title: s.rawData),
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
    final s = AppStrings.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            name: s.type,
            value: [payload.marker, ...payload.positional].join(' · '),
          ),
          for (final entry in payload.fields.entries)
            _Row(name: entry.key, value: entry.value),
          if (payload.fields.isEmpty)
            Text(s.noKeyValueFields, style: theme.textTheme.bodySmall),
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
              value.isEmpty ? AppStrings.of(context).emptyValue : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
