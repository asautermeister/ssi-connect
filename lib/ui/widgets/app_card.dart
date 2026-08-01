import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one surface everything sits on: a white (or dark) panel with a
/// hairline border and no shadow, matching the flat card style dive data
/// arrives in from Garmin Connect.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.edgeColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Draws a coloured bar down the left edge - used to mark whose dive this
  /// is on a shared tablet. Null leaves the card unmarked.
  ///
  /// Never the only thing carrying that information: the cards that use it
  /// also name the diver in text.
  final Color? edgeColor;

  /// Width of that bar. Wide enough to see from arm's length on a tablet,
  /// narrow enough not to eat into the card's own padding.
  static const edgeWidth = 5.0;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final radius = BorderRadius.circular(AppRadius.card);
    final edgeColor = this.edgeColor;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: radius,
      // So the bar follows the card's rounded corners instead of sticking
      // out square at the top and bottom.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: palette.hairline),
              ),
              padding: padding,
              child: child,
            ),
            if (edgeColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: edgeWidth,
                child: ColoredBox(color: edgeColor),
              ),
          ],
        ),
      ),
    );
  }
}

/// A section heading with generous space above it - the rhythm that
/// separates groups of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
