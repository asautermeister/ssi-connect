import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'dive_qr_batch_screen.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';

/// Picks the dives to export in one run.
///
/// Grouped by day, and the day header selects the whole day at once -
/// that is the case this exists for: coming back from a boat with three
/// dives and wanting all three in SSI.
///
/// Dives the payload builder can't encode are shown but not selectable,
/// with the reason next to them. Hiding them would be worse: a dive that
/// silently isn't in the list looks like one that was already exported.
class DiveExportSelectionScreen extends StatefulWidget {
  const DiveExportSelectionScreen({super.key, required this.dives, this.diver});

  final List<Dive> dives;
  final SsiBuddyCode? diver;

  @override
  State<DiveExportSelectionScreen> createState() =>
      _DiveExportSelectionScreenState();
}

class _DiveExportSelectionScreenState extends State<DiveExportSelectionScreen> {
  final _selected = <String>{};

  /// Newest day first, dives inside a day in the order they were dived -
  /// the same order the SSI logbook will end up in.
  late final List<_DiveDay> _days = _groupByDay(widget.dives);

  bool _isExportable(Dive dive, AppStrings s) =>
      SsiQrPayloadBuilder.unexportableReason(dive, strings: s) == null;

  void _toggle(Dive dive, bool? selected) => setState(() {
    if (selected ?? false) {
      _selected.add(dive.id);
    } else {
      _selected.remove(dive.id);
    }
  });

  /// Held so the day-select helper can ask the builder without a
  /// context of its own.
  AppStrings? _strings;

  void _toggleDay(_DiveDay day, bool select) => setState(() {
    for (final dive in day.dives.where((d) => _isExportable(d, _strings!))) {
      if (select) {
        _selected.add(dive.id);
      } else {
        _selected.remove(dive.id);
      }
    }
  });

  void _start() {
    // Oldest first, so scanning them in order fills the logbook in the
    // order they were dived - the list itself is newest first, which is
    // right for picking and wrong for scanning.
    final chosen = [
      for (final day in _days)
        for (final dive in day.dives)
          if (_selected.contains(dive.id)) dive,
    ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiveQrBatchScreen(dives: chosen, diver: widget.diver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    _strings = s;
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(title: Text(s.exportSeveral)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          for (final day in _days) ...[
            _DayHeader(
              day: day,
              selectedCount: day.dives
                  .where((d) => _selected.contains(d.id))
                  .length,
              exportableCount: day.dives
                  .where((d) => _isExportable(d, _strings!))
                  .length,
              onChanged: (select) => _toggleDay(day, select),
            ),
            for (final dive in day.dives) ...[
              _SelectableDive(
                dive: dive,
                selected: _selected.contains(dive.id),
                reason: SsiQrPayloadBuilder.unexportableReason(
                  dive,
                  strings: s,
                ),
                onChanged: (value) => _toggle(dive, value),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: count == 0 ? null : _start,
            icon: const Icon(Icons.qr_code_2),
            label: Text(switch (count) {
              0 => s.selectDives,
              1 => s.oneDiveAsQr,
              _ => s.divesAsQr(count),
            }, style: theme.textTheme.titleMedium),
          ),
        ),
      ),
    );
  }
}

/// A day's worth of dives, with the day itself as the grouping key.
class _DiveDay {
  _DiveDay(this.date) : dives = [];

  final DateTime date;
  final List<Dive> dives;
}

List<_DiveDay> _groupByDay(List<Dive> dives) {
  final byDay = <DateTime, _DiveDay>{};
  for (final dive in dives) {
    final key = DateTime(
      dive.dateTime.year,
      dive.dateTime.month,
      dive.dateTime.day,
    );
    (byDay[key] ??= _DiveDay(key)).dives.add(dive);
  }

  final days = byDay.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  for (final day in days) {
    day.dives.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }
  return days;
}

/// Selects or clears a whole dive day. A tristate box would be one state
/// too many here - what the user wants is "all of them" or "none of them",
/// so a partial selection reads as unchecked and one tap completes it.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.selectedCount,
    required this.exportableCount,
    required this.onChanged,
  });

  final _DiveDay day;
  final int selectedCount;
  final int exportableCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final allSelected = exportableCount > 0 && selectedCount == exportableCount;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: SectionHeader(
              title: s.dayWithDiveCount(
                '${Fmt.weekday(day.date, s)}, ${Fmt.date(day.date)}',
                day.dives.length,
              ),
            ),
          ),
          if (exportableCount > 0)
            TextButton(
              onPressed: () => onChanged(!allSelected),
              child: Text(allSelected ? s.noneOfDay : s.wholeDiveDay),
            ),
        ],
      ),
    );
  }
}

class _SelectableDive extends StatelessWidget {
  const _SelectableDive({
    required this.dive,
    required this.selected,
    required this.reason,
    required this.onChanged,
  });

  final Dive dive;
  final bool selected;

  /// Why this dive can't be exported, or null when it can.
  final String? reason;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final blocked = reason != null;

    return AppCard(
      onTap: blocked ? null : () => onChanged(!selected),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: blocked ? null : onChanged),
          const SizedBox(width: AppSpacing.sm),
          DiveTypeBadge(type: dive.type, diveNumber: dive.diveNumber),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.diveOfDayAndType(dive.diveNumberOfDay, dive.type.label(s))} · '
                  '${Fmt.timeOfDay(dive.dateTime, s)}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  blocked
                      ? reason!
                      : '${Fmt.meters(dive.maxDepthMeters)} m · '
                            '${Fmt.minutes(dive.duration)} min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: blocked ? palette.inkMuted : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
