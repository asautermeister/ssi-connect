import 'package:flutter/material.dart';

import '../dives/recent_dives_controller.dart';
import 'format.dart';
import 'qr_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';

/// One dive in a merged, cross-account list: whose it is, when, how deep.
/// Tapping goes straight to its QR code - the whole point of the app, so it
/// should not take four taps to reach.
///
/// Shared by the start screen's short list and the full list behind it, so
/// the same dive looks the same in both.
class RecentDiveCard extends StatelessWidget {
  const RecentDiveCard({super.key, required this.entry});

  final RecentDive entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final dive = entry.dive;

    return AppCard(
      edgeColor: entry.account.color?.of(context),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              QrScreen(dive: dive, diver: entry.account.ssiIdentity),
        ),
      ),
      child: Row(
        children: [
          DiveTypeIcon(type: dive.type, size: 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.weekday(dive.dateTime)}, ${Fmt.date(dive.dateTime)}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    entry.account.displayName,
                    if (dive.duration != null)
                      '${Fmt.minutes(dive.duration)} min',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Fmt.meters(dive.maxDepthMeters),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          // Says where the tap goes, so the card isn't a guess.
          Icon(Icons.qr_code_2, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
