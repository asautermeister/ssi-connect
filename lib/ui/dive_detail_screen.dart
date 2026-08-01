import 'package:flutter/material.dart';

import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import 'format.dart';
import 'qr_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dive_type_icon.dart';
import 'widgets/stat_tile.dart';

/// One dive in full. Max depth leads as the hero number, the remaining
/// measurements sit in a two-column grid of stat tiles below it, and the
/// QR export is the single primary action.
class DiveDetailScreen extends StatelessWidget {
  const DiveDetailScreen({super.key, required this.dive, this.diver});

  final Dive dive;
  final SsiBuddyCode? diver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Scaffold(
      appBar: AppBar(title: Text('${dive.diveNumberOfDay}. Tauchgang')),
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
                            dive.type.label,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${Fmt.weekday(dive.dateTime)}, ${Fmt.dateTime(dive.dateTime)} Uhr',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                StatTile(
                  label: 'Max. Tiefe',
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
          const SectionHeader(title: 'Werte'),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Dauer',
                        value: Fmt.minutes(dive.duration),
                        unit: 'min',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Ø Tiefe',
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
                        label: 'Wassertemp.',
                        value: Fmt.celsius(dive.waterTemperatureCelsius),
                        unit: '°C',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Tauchgang',
                        value: '${dive.diveNumberOfDay}',
                        unit: 'des Tages',
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
                                label: 'Wasser',
                                value: dive.waterType!.label,
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: dive.isDecoDive != null
                            ? StatTile(
                                label: 'Deko',
                                value: dive.isDecoDive! ? 'Ja' : 'Nein',
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
                            label: 'Abtauchvorgänge',
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
            builder: (_) => QrScreen(dive: dive, diver: diver),
          ),
        ),
        icon: const Icon(Icons.qr_code_2),
        label: const Text('QR-Code für SSI'),
      ),
    );
  }
}
