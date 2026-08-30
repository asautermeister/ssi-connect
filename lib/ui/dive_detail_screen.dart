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

/// A dive together with the SSI member whose it is, so a page knows who to
/// attribute the export to. The diver is null for a FIT import, which
/// belongs to no account.
typedef DetailDive = ({Dive dive, SsiBuddyCode? diver});

/// One dive in full, with the neighbours a swipe away.
///
/// Takes the whole list the caller was showing rather than a single dive:
/// working through a dive day means looking at one dive after another, and
/// going back to the list between each is a step that answers nothing.
/// Each dive is its own page with its own state - which site it is filed
/// at is a decision about that dive, not about this screen.
class DiveDetailScreen extends StatefulWidget {
  const DiveDetailScreen({super.key, required this.dives, this.index = 0});

  /// One dive on its own, with nothing to swipe to.
  DiveDetailScreen.single({Key? key, required Dive dive, SsiBuddyCode? diver})
    : this(key: key, dives: [(dive: dive, diver: diver)]);

  /// The dives to page through, in the order the list showed them.
  final List<DetailDive> dives;

  /// Which of them to open on.
  final int index;

  @override
  State<DiveDetailScreen> createState() => _DiveDetailScreenState();
}

class _DiveDetailScreenState extends State<DiveDetailScreen> {
  late final _pages = PageController(initialPage: widget.index);
  late int _current = widget.index;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final dives = widget.dives;
    // Garmin's running number for the diver, which is what a diver calls a
    // dive. Null when Garmin did not send one - the number of the day then
    // has to do, as before.
    final diveNumber = dives[_current].dive.diveNumber;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          diveNumber == null
              ? s.diveOfDayTitle(dives[_current].dive.diveNumberOfDay)
              : s.diveNumberTitle(diveNumber),
        ),
        actions: [
          // Only while the title cannot tell the pages apart. Garmin's
          // running number is unique, so it says on its own that the swipe
          // arrived somewhere; the dive of the day does not - two dives on
          // the same day are both "1. Tauchgang", and a swipe landing on an
          // identical heading looks like nothing happened.
          if (dives.length > 1 && diveNumber == null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: Text(
                  s.pageOf(_current + 1, dives.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      // A page each, rather than one screen rebuilt: the site a dive is
      // filed at is that dive's business, and pages that carry their own
      // state cannot hand one dive's answer to the next.
      body: PageView.builder(
        controller: _pages,
        // The lists run newest first, so without this the newer dive would
        // sit to the left. Reversed, the pages lie the way the numbers do:
        // the earlier dive to the left, the later one to the right.
        reverse: true,
        itemCount: dives.length,
        onPageChanged: (index) => setState(() => _current = index),
        itemBuilder: (_, index) => _DiveDetailPage(entry: dives[index]),
      ),
    );
  }
}

class _DiveDetailPage extends StatefulWidget {
  const _DiveDetailPage({required this.entry});

  final DetailDive entry;

  @override
  State<_DiveDetailPage> createState() => _DiveDetailPageState();
}

class _DiveDetailPageState extends State<_DiveDetailPage> {
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
      _decided ? _chosen : sites.suggestionFor(widget.entry.dive);

  @override
  Widget build(BuildContext context) {
    final dive = widget.entry.dive;
    final diver = widget.entry.diver;
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final siteController = context.watch<DiveSitesController>();
    final site = _siteFor(siteController);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
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
                          // The full date, not just the weekday: this line
                          // answers "which dive is this", and a weekday
                          // alone only picks it out of the seven around it.
                          '${Fmt.weekday(dive.dateTime, s)} '
                          '${Fmt.shortDate(dive.dateTime)}, '
                          '${Fmt.timeOfDay(dive.dateTime, s)}',
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

        SectionHeader(title: s.qrForSsi),
        // Last on the page, after the values: the code is what one leaves
        // with, and everything above it is what one checks first - the
        // site it is filed at included, which is part of the payload.
        // Rebuilt on every build, so assigning a site further up changes
        // the code immediately; scanning a code that predates the decision
        // is the failure worth designing against.
        DiveQrCard(dive: dive, diver: diver, site: site),
      ],
    );
  }
}
