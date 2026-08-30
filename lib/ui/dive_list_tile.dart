import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';

import '../accounts/models/account_color.dart';
import '../dives/exported_dives_controller.dart';
import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import 'dive_detail_screen.dart';
import 'format.dart';
import 'qr_display_screen.dart';
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
    this.diver,
    this.accountColor,
    this.inSsiLogbook = false,
    this.siblings = const [],
  });

  final Dive dive;
  final SsiBuddyCode? diver;

  /// The dives this one is listed among, so the detail view can be swiped
  /// from one to the next. Empty means "just this one".
  final List<Dive> siblings;

  /// Colour of the account these dives belong to, drawn as a bar on the
  /// left edge. Null for FIT imports, which have no account.
  final AccountColor? accountColor;

  /// Deepest dive currently listed, so the bars share one scale. Pass 0 to
  /// hide the bar entirely.
  final double maxDepthInList;

  /// Whether this dive was found in the SSI logbook of the account it
  /// belongs to. Worked out by the list, which knows whose dives these are
  /// - a logbook may only be matched against its own person's dives.
  final bool inSsiLogbook;

  /// This dive, opened among the ones it is listed with. Falls back to the
  /// dive on its own when the caller did not say what it is listed among.
  DiveDetailScreen _detailScreen() {
    final index = siblings.indexOf(dive);
    if (index < 0) return DiveDetailScreen.single(dive: dive, diver: diver);
    return DiveDetailScreen(
      dives: [for (final sibling in siblings) (dive: sibling, diver: diver)],
      index: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final depth = dive.maxDepthMeters;
    final showMeter = maxDepthInList > 0 && depth != null;

    return AppCard(
      edgeColor: accountColor?.of(context),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _detailScreen())),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${Fmt.weekday(dive.dateTime, s)}, '
                            '${Fmt.date(dive.dateTime)}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        // Beside the date rather than off in a corner: the
                        // question this answers is "did this one already go
                        // across?", asked while reading down the list.
                        if (context
                            .watch<ExportedDivesController>()
                            .isTransferred(dive, inLogbook: inSsiLogbook)) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const DiveTransferredMark(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        Fmt.timeOfDay(dive.dateTime, s),
                        if (dive.duration != null)
                          '${Fmt.minutes(dive.duration)} min',
                        if (dive.descentCount != null)
                          s.descentCount(dive.descentCount!),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // The dive type is spelled out here as well, so the
                    // badge never has to be decoded from its shape.
                    AppChip(
                      label: s.diveOfDayAndType(
                        dive.diveNumberOfDay,
                        dive.type.label(s),
                      ),
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
                  Text(s.maxDepthLabel, style: theme.textTheme.labelSmall),
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
