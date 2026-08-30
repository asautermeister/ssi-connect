import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/dive.dart';
import '../../models/dive_type.dart';
import '../theme/app_theme.dart';
import 'error_state.dart';

/// What a dive list is narrowed to.
///
/// Two kinds of question, in the order they get asked: what still has to go
/// across to SSI, and then which sort of diving it was - narrowing from
/// left to right, everything on scuba, then the two halves of it. There is
/// no "already transferred" - that is what the green tick on the card says,
/// and a filter for it would only ever be used to admire finished work.
enum DiveFilter {
  all,
  open,
  scuba,
  rec,
  tech;

  bool accepts(Dive dive, {required bool isTransferred}) => switch (this) {
    DiveFilter.all => true,
    // Freediving is logged in SSI differently and is not what a list is
    // being worked through for, so it stays out of the working set.
    DiveFilter.open => !isTransferred && dive.type != DiveType.apnea,
    // Everything Rec and Tech together cover, without having to look at
    // both - written as "not apnea" rather than as the union of the two
    // sets, so a dive type added later lands here by default instead of
    // quietly falling out.
    DiveFilter.scuba => dive.type != DiveType.apnea,
    DiveFilter.rec => _recreational.contains(dive.type),
    DiveFilter.tech => _technical.contains(dive.type),
  };

  String label(AppStrings s) => switch (this) {
    DiveFilter.all => s.filterAll,
    DiveFilter.open => s.filterOpen,
    DiveFilter.scuba => s.filterScuba,
    DiveFilter.rec => s.filterRec,
    DiveFilter.tech => s.filterTech,
  };

  /// [DiveType.scuba] counts as recreational, and that is a decision rather
  /// than an oversight: it is the fallback for an open-circuit dive whose
  /// gas setup Garmin did not name. Leaving it out would drop exactly those
  /// dives out of *both* filters, and a dive nobody can find is worse than
  /// one filed a little generously. It can never be a rebreather or a
  /// multi-gas dive - those Garmin does name.
  static const _recreational = {DiveType.singleGas, DiveType.scuba};
  static const _technical = {DiveType.multiGas, DiveType.rebreather};
}

/// The filter, for any screen that shows a list of dives.
///
/// A mixin rather than a widget because the three parts do not sit
/// together: the button belongs in the app bar, the chips above the list,
/// the empty state inside it. What they share is the state, and that is
/// what is easy to get subtly different if each screen keeps its own -
/// which chips exist, whether hiding the row clears the filter, whether a
/// closed row over a narrowed list says so.
///
/// A screen mixes this in and calls the three build methods; narrowing the
/// list stays with the screen, since only it knows what its entries are and
/// where the transferred flag comes from.
mixin DiveFilterState<T extends StatefulWidget> on State<T> {
  /// View state, not a preference: a filter that outlived the screen would
  /// hide dives on the next visit without saying why.
  DiveFilter filter = DiveFilter.all;

  /// Whether the chips are on screen. Closed to begin with - the row costs
  /// a good deal of a phone screen, and most visits to a dive list are to
  /// look at it rather than to narrow it.
  bool showFilters = false;

  /// The funnel for the app bar. Worth hiding when there is nothing to
  /// narrow: a filter row above an empty list can only produce the same
  /// empty list.
  Widget buildFilterButton(AppStrings s) => IconButton(
    // The dot is what keeps hiding the row honest: a narrowed list
    // otherwise looks exactly like a short one, and the control that
    // explains it is off screen.
    icon: Badge(
      isLabelVisible: !showFilters && filter != DiveFilter.all,
      smallSize: 8,
      child: const Icon(Icons.filter_list),
    ),
    tooltip: s.filterDives,
    isSelected: showFilters,
    onPressed: () => setState(() => showFilters = !showFilters),
  );

  /// The chips, or nothing while the row is closed.
  Widget buildFilterBar() => showFilters
      ? _FilterBar(
          selected: filter,
          onChanged: (choice) => setState(() => filter = choice),
        )
      : const SizedBox.shrink();

  /// What to show instead of the list when the filter matches nothing.
  ///
  /// Not an error state: the list is empty because of a choice. The way
  /// back out is offered right here rather than left to the chips, because
  /// the chips may well be hidden - and then there would be nothing on
  /// screen to undo it with.
  Widget buildNoMatchState(AppStrings s) => ErrorState(
    icon: Icons.filter_alt_off_outlined,
    message: s.noDivesForFilter,
    secondaryLabel: s.showAll,
    onSecondary: () => setState(() => filter = DiveFilter.all),
  );
}

/// The choices, side by side above the list.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final DiveFilter selected;
  final ValueChanged<DiveFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final choice in DiveFilter.values)
            FilterChip(
              label: Text(choice.label(s)),
              selected: choice == selected,
              // Tapping the active chip keeps it active instead of
              // clearing to no filter at all - there is no such state.
              onSelected: (_) => onChanged(choice),
            ),
        ],
      ),
    );
  }
}
