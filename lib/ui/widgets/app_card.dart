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
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.hairline),
          ),
          padding: padding,
          child: child,
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
