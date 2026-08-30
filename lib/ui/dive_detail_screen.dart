import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';

import '../models/dive.dart';
import '../ssi/dive_site.dart';
import '../ssi/dive_sites_controller.dart';
import '../ssi/ssi_buddy_code.dart';
import 'dive_site_section.dart';
import 'format.dart';
import 'qr_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';
import 'widgets/stat_tile.dart';

/// One dive in full. Max depth leads as the hero number, the remaining
/// measurements sit in a two-column grid of stat tiles below it, and the
/// QR export is the single primary action.
class DiveDetailScreen extends StatefulWidget {
  const DiveDetailScreen({super.key, required this.dive, this.diver});

  final Dive dive;
  final SsiBuddyCode? diver;

  @override
  State<DiveDetailScreen> createState() => _DiveDetailScreenState();
}

class _DiveDetailScreenState extends State<DiveDetailScreen> {
  /// Chosen for this dive only, and only for this visit. The pairing of
  /// position to site number is what persists; which dive got which site
  /// is not stored, because the dives themselves are only a cache.
  DiveSite? _chosen;

  /// Whether [_chosen] is the user's own answer rather than the absence of
  /// one. Needed because null means two different things: "not decided,
  /// take the nearest known site" and "decided: no site" - and without the
  /// difference, removing an automatically matched site would put it
  /// straight back on the next build.
  bool _decided = false;

  /// The site this dive goes to SSI with.
  ///
  /// Undecided means the nearest known site within the match radius, taken
  /// rather than offered: in practice the nearest one has been right every
  /// time, and confirming a suggestion that is always accepted is a tap
  /// that asks a question with only one answer. It stays visible, named,
  /// and one tap from being changed or removed - which is what makes taking
  /// it acceptable rather than presumptuous.
  DiveSite? _siteFor(DiveSitesController sites) =>
      _decided ? _chosen : sites.suggestionFor(widget.dive);

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final diver = widget.diver;
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final siteController = context.watch<DiveSitesController>();
    final site = _siteFor(siteController);

    return Scaffold(
      appBar: AppBar(title: Text(s.diveOfDayTitle(dive.diveNumberOfDay))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          // Room for the floating action button.
          96,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DiveTypeBadge(
                      type: dive.type,
                      diveNumber: dive.diveNumber,
                      size: 34,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dive.type.label(s),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${Fmt.weekday(dive.dateTime, s)}, ${Fmt.timeOfDay(dive.dateTime, s)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                StatTile(
                  label: s.maxDepthLabel,
                  value: Fmt.meters(dive.maxDepthMeters),
                  unit: 'm',
                  emphasis: StatEmphasis.hero,
                ),
                if (dive.locationName != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          dive.locationName!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(title: s.diveSite),
          DiveSiteSection(
            dive: dive,
            selected: site,
            // Automatic exactly while the user has not answered - the label
            // has to say which of the two it is, or a site nobody picked
            // looks like one somebody did.
            isAutomatic: !_decided && site != null,
            onChanged: (chosen) => setState(() {
              _chosen = chosen;
              _decided = true;
            }),
          ),

          SectionHeader(title: s.values),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatTile(
                        label: s.duration,
                        value: Fmt.minutes(dive.duration),
                        unit: 'min',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: s.avgDepth,
                        value: Fmt.meters(dive.avgDepthMeters),
                        unit: 'm',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatTile(
                        label: s.waterTemperature,
                        value: Fmt.celsius(dive.waterTemperatureCelsius),
                        unit: '°C',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: s.diveOfDayTitleShort,
                        value: '${dive.diveNumberOfDay}',
                        unit: s.diveOfDay,
                      ),
                    ),
                  ],
                ),
                // The running dive number is not repeated here - it sits
                // beside the badge at the top of the screen. Only the
                // descent count needs a tile, and only for the freediving
                // sessions that have more than one.
                //
                // The water type is shown because it travels into the SSI
                // logbook as var_watertype_id: a value that ends up in the
                // export should be readable before it is scanned.
                if (dive.descentCount != null ||
                    dive.waterType != null ||
                    dive.isDecoDive != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: dive.waterType != null
                            ? StatTile(
                                label: s.water,
                                value: dive.waterType!.label(s),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: dive.isDecoDive != null
                            ? StatTile(
                                label: s.deco,
                                value: dive.isDecoDive! ? s.yes : s.no,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  if (dive.descentCount != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: StatTile(
                            label: s.descents,
                            value: '${dive.descentCount}',
                          ),
                        ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QrScreen(dive: dive, diver: diver, site: site),
          ),
        ),
        icon: const Icon(Icons.qr_code_2),
        label: Text(s.qrForSsi),
      ),
    );
  }
}
