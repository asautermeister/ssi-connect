import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single measurement, presented number-first: a small muted label, then
/// the value large and light-weight with its unit trailing in small text.
///
/// This is the workhorse of the detail screen. It is deliberately *not* a
/// chart - one dive's max depth is a single magnitude, and a hero number
/// reads it faster than any plot would.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.emphasis = StatEmphasis.normal,
  });

  final String label;

  /// Already formatted; pass an em dash for "not available" so the tile
  /// keeps its place in the grid instead of collapsing.
  final String value;
  final String? unit;
  final StatEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final valueStyle = emphasis == StatEmphasis.hero
        ? theme.textTheme.displayMedium
        : theme.textTheme.displaySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: valueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                unit!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum StatEmphasis { normal, hero }

/// Horizontal magnitude bar: how deep this dive was relative to the
/// deepest one on screen. Sequential encoding, so it stays a single hue -
/// the fill is the accent, the track a near-surface neutral.
///
/// Purely supporting: the number beside it always carries the value, so
/// the bar never has to be read precisely.
class DepthMeter extends StatelessWidget {
  const DepthMeter({
    super.key,
    required this.value,
    required this.max,
    this.height = 4,
  });

  final double value;
  final double max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: height,
        backgroundColor: palette.meterTrack,
        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
      ),
    );
  }
}

/// Small uppercase chip, used for the dive-of-day marker. Carries a label,
/// never colour alone.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
