import 'package:flutter/material.dart';

import '../debug_log_screen.dart';
import '../theme/app_theme.dart';

/// Centred empty/failure state: an icon, the explanation, optional raw API
/// details (only populated while API logging is on), and up to two actions.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.details,
    this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final IconData icon;
  final String? details;
  final VoidCallback? onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: palette.inkMuted),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (details != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: SelectableText(
                    details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Erneut versuchen'),
                ),
              ],
              if (onSecondary != null && secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('API-Protokoll öffnen'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebugLogScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
