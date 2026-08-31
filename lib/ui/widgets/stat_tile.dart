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

/// How deep this dive was, on a fixed scale from the surface to 45 m.
///
/// Fixed, and that is the whole point of it. The bar used to be drawn
/// against the deepest dive currently in the list, so the same dive came
/// out a different length depending on what else was loaded, what the
/// filter hid, and whether one arrived from the start screen or from the
/// full list. A chart whose axis moves silently is decoration - one reads
/// "long means deep" and the length disagrees with itself between two
/// screens.
///
/// 45 m because that is past where recreational diving goes and short of
/// where the bar would waste most of its width on water nobody visits.
/// Deeper than that the bar fills completely and an arrow says so: the
/// alternative, stretching the scale to fit the deepest dive, would take
/// the meaning back out of every other bar on the screen.
///
/// The ticks are the scale, drawn rather than labelled: taller every ten
/// metres, shorter every five. Only the two ends carry a number, and small
/// - the bar is read at a glance, and the exact value is already printed
/// beside it in full size.
class DepthMeter extends StatelessWidget {
  const DepthMeter({super.key, required this.value});

  final double value;

  /// The end of the scale, in metres.
  static const scaleMetres = 45.0;

  /// Bar and axis, one above the other.
  static const _barHeight = 8.0;
  static const _gap = 4.0;
  static const _tickHeight = 6.0;

  /// Kept clear at the right end for the over-scale arrow, so a bar that
  /// runs off the scale and one that does not are still the same length -
  /// which is what makes them comparable at all.
  static const _arrowGutter = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final small = theme.textTheme.labelSmall?.copyWith(
      color: palette.inkMuted,
      fontSize: 10,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _barHeight + _gap + _tickHeight,
          child: CustomPaint(
            painter: _DepthMeterPainter(
              value: value,
              track: palette.meterTrack,
              fill: theme.colorScheme.primary,
              ticks: palette.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: small),
            Text('${scaleMetres.round()} m', style: small),
          ],
        ),
      ],
    );
  }
}

class _DepthMeterPainter extends CustomPainter {
  const _DepthMeterPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.ticks,
  });

  final double value;
  final Color track;
  final Color fill;
  final Color ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - DepthMeter._arrowGutter;
    if (width <= 0) return;
    const barHeight = DepthMeter._barHeight;
    final radius = Radius.circular(barHeight / 2);

    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, width, barHeight, radius),
      Paint()..color = track,
    );

    final over = value > DepthMeter.scaleMetres;
    final fraction = (value / DepthMeter.scaleMetres).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, width * fraction, barHeight, radius),
        Paint()..color = fill,
      );
    }

    // Past the end of the scale. A filled bar alone would read as "exactly
    // 45", which is the one thing it is not.
    if (over) {
      final middle = barHeight / 2;
      final left = width + 3;
      canvas.drawPath(
        Path()
          ..moveTo(left, middle - 4)
          ..lineTo(left + 6, middle)
          ..lineTo(left, middle + 4)
          ..close(),
        Paint()..color = fill,
      );
    }

    // The scale itself: every five metres, taller on the tens.
    final tickPaint = Paint()
      ..color = ticks.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final top = barHeight + DepthMeter._gap;
    for (var metres = 5; metres < DepthMeter.scaleMetres; metres += 5) {
      final x = width * (metres / DepthMeter.scaleMetres);
      final height = metres % 10 == 0
          ? DepthMeter._tickHeight
          : DepthMeter._tickHeight / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_DepthMeterPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.ticks != ticks;
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
