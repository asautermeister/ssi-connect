import 'package:flutter/material.dart';

import '../models/dive.dart';
import 'dive_detail_screen.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';
import 'widgets/stat_tile.dart';

/// One dive in a list, as a card: date and dive-of-day on the left, max
/// depth as the hero number on the right, and a magnitude bar underneath
/// putting this dive against the deepest one on screen.
class DiveListTile extends StatelessWidget {
  const DiveListTile({
    super.key,
    required this.dive,
    required this.maxDepthInList,
  });

  final Dive dive;

  /// Deepest dive currently listed, so the bars share one scale. Pass 0 to
  /// hide the bar entirely.
  final double maxDepthInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final depth = dive.maxDepthMeters;
    final showMeter = maxDepthInList > 0 && depth != null;

    return AppCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DiveDetailScreen(dive: dive))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiveTypeBadge(type: dive.type, diveNumber: dive.diveNumber),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.weekday(dive.dateTime)}, ${Fmt.date(dive.dateTime)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        '${Fmt.time(dive.dateTime)} Uhr',
                        if (dive.duration != null)
                          '${Fmt.minutes(dive.duration)} min',
                        if (dive.descentCount != null)
                          '${dive.descentCount}× abgetaucht',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // The dive type is spelled out here as well, so the
                    // badge never has to be decoded from its shape.
                    AppChip(
                      label: '${dive.diveNumberOfDay}. TG · ${dive.type.label}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Fmt.meters(depth),
                        style: theme.textTheme.displayMedium,
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
                  Text('MAX. TIEFE', style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
          if (showMeter) ...[
            const SizedBox(height: AppSpacing.lg),
            DepthMeter(value: depth, max: maxDepthInList),
          ],
        ],
      ),
    );
  }
}
