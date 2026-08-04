import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/settings_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// App-wide preferences.
///
/// Deliberately its own screen rather than a switch tucked into the info
/// screen: the language selection is going to land here too, and a screen
/// that already has a shape is easier to add to than one that has to be
/// invented later.
///
/// Only settings that actually do something appear here. A language row
/// that offers one language would be a control the user can operate
/// without anything happening.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const SectionHeader(title: 'Darstellung'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final option in _ThemeOption.values)
                  _ThemeRow(
                    option: option,
                    selected: settings.themeMode == option.mode,
                    onTap: () => settings.setThemeMode(option.mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              'Der QR-Code bleibt immer hell – ein dunkler Code lässt sich '
              'von manchen Kameras nicht zuverlässig scannen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three choices, in the order they belong: the default first, then the
/// two ways to override it.
enum _ThemeOption {
  system(
    ThemeMode.system,
    'Wie das Gerät',
    'Folgt der Systemeinstellung',
    Icons.brightness_auto_outlined,
  ),
  light(
    ThemeMode.light,
    'Hell',
    'Gut bei Sonnenlicht an Deck',
    Icons.light_mode_outlined,
  ),
  dark(
    ThemeMode.dark,
    'Dunkel',
    'Schont die Augen am Abend',
    Icons.dark_mode_outlined,
  );

  const _ThemeOption(this.mode, this.label, this.description, this.icon);

  final ThemeMode mode;
  final String label;
  final String description;
  final IconData icon;
}

/// One choice. Built by hand rather than from [RadioListTile] so the whole
/// row is the tap target and the styling matches the rest of the app.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 22,
              color: selected ? theme.colorScheme.primary : palette.inkMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(option.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            // The tick alone carries the selection, so it needs to be
            // unmistakable rather than a shade of the same colour.
            if (selected)
              Icon(
                Icons.check_circle,
                size: 22,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
