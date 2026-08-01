import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Says that what's on screen isn't current, and why.
///
/// Two different messages on purpose. "No connection" is only shown when
/// the request genuinely never reached Garmin; when it did and failed for
/// another reason, telling someone to check their internet sends them
/// looking in the wrong place.
///
/// Whenever cached dives are being shown, the time they were fetched comes
/// with them - "how old is this?" is the question that decides whether the
/// dive on screen is the one you just did.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.fetchedAt,
    this.onRetry,
  });

  final bool isOffline;
  final DateTime? fetchedAt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final fetchedAt = this.fetchedAt;

    return AppCard(
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_outlined : Icons.history,
            size: 20,
            color: palette.inkMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOffline
                      ? 'Keine Internetverbindung'
                      : 'Gespeicherte Tauchgänge',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  fetchedAt == null
                      ? 'Es werden keine aktuellen Daten geladen.'
                      : 'Stand: ${Fmt.dateTime(fetchedAt)} Uhr',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Erneut')),
        ],
      ),
    );
  }
}
