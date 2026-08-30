import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';

import '../dives/exported_dives_controller.dart';
import '../dives/recent_dives_controller.dart';
import 'format.dart';
import 'dive_detail_screen.dart';
import 'qr_display_screen.dart';
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
  const RecentDiveCard({
    super.key,
    required this.entry,
    this.inSsiLogbook = false,
    this.siblings = const [],
    this.siblingsInLogbook = const {},
  });

  final RecentDive entry;

  /// The dives this one is listed among, so the detail view can be swiped
  /// from one to the next. Empty means "just this one".
  final List<RecentDive> siblings;

  /// Which of [siblings] SSI's logbook already has, by dive id - worked out
  /// once for the whole list, since the match is one-to-one.
  final Set<String> siblingsInLogbook;

  /// Whether this dive was found in the SSI logbook of the account it
  /// belongs to. Worked out by the list, which can keep each account's
  /// dives against that account's logbook.
  final bool inSsiLogbook;

  /// This dive, opened among the ones it is listed with - but only this
  /// diver's.
  ///
  /// These lists are merged across accounts, and swiping through a merged
  /// list would hand somebody else's dive the SSI number of whoever was
  /// tapped, or at best jump between people mid-swipe. "Previous dive"
  /// means the diver's previous dive; the family shares a tablet, not a
  /// logbook.
  DiveDetailScreen _detailScreen() {
    final mine = [
      for (final sibling in siblings)
        if (sibling.account.id == entry.account.id) sibling,
    ];
    // Found by the dive's id, not by identity. RecentDive is built fresh
    // on every read, so the entry this card was given and the entry of the
    // same dive in `siblings` are equal in every way that matters and
    // identical in none - which quietly reduced the whole list to one dive
    // when the two came from different calls, as they do on the start
    // screen: the five on show and the full list are separate reads.
    final index = mine.indexWhere((s) => s.dive.id == entry.dive.id);
    if (index < 0) {
      return DiveDetailScreen.single(
        dive: entry.dive,
        diver: entry.account.ssiIdentity,
        inLogbook: inSsiLogbook,
      );
    }
    return DiveDetailScreen(
      dives: [
        for (final sibling in mine)
          (
            dive: sibling.dive,
            diver: sibling.account.ssiIdentity,
            inLogbook: siblingsInLogbook.contains(sibling.dive.id),
          ),
      ],
      index: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final dive = entry.dive;

    return AppCard(
      edgeColor: entry.account.color?.of(context),
      // The detail page, the same as the per-account list does. Going
      // straight to the code from here and to the dive from there was two
      // answers to one question, and the code is on the detail page now
      // anyway - so nothing got further away.
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _detailScreen())),
      child: Row(
        children: [
          DiveTypeIcon(type: dive.type, size: 34),
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
                    if (context.watch<ExportedDivesController>().isTransferred(
                      dive,
                      inLogbook: inSsiLogbook,
                    )) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const DiveTransferredMark(),
                    ],
                  ],
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
